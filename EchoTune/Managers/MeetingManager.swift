//
//  MeetingManager.swift
//  EchoTune
//
//  Orchestrates meeting recording: system audio capture, chunked transcription,
//  live transcript assembly, and AI summary generation.
//

import Foundation
import AVFoundation
import AppKit
import Combine
import Accelerate

@available(macOS 13.0, *)
class MeetingManager: ObservableObject {

    static let shared = MeetingManager()

    // MARK: - Published State
    @Published var isRecording = false
    @Published var currentSession: MeetingSession?
    @Published var liveTranscript: String = ""
    @Published var recordingDuration: TimeInterval = 0
    @Published var systemAudioLevel: Float = 0.0
    @Published var isGeneratingSummary = false
    @Published var pastMeetings: [MeetingSession] = []
    /// User-typed notes for the meeting currently being recorded (Granola-style).
    @Published var userNotes: String = ""
    /// Non-fatal live-transcription problem (model loading/failing) — shown as a banner.
    @Published var transcriptionWarning: String?
    /// Summary problem or degraded-summary notice — shown in the detail panel next to Regenerate.
    @Published var summaryIssue: String?
    /// True when recording mic-only because Screen Recording permission is missing/failed.
    @Published var systemAudioUnavailable = false

    private enum AudioCaptureSource {
        case mic
        case system
    }

    // MARK: - Private
    private let systemAudioCapture = SystemAudioCapture()
    private let summaryEngine = MeetingSummaryEngine.shared
    private var audioBuffer = Data()
    private var durationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Mic capture for meeting mode
    private var micEngine: AVAudioEngine?
    private var micBuffers: [AVAudioPCMBuffer] = []
    private var systemBuffers: [AVAudioPCMBuffer] = []
    private var micBuffersSinceLastTranscribe: [AVAudioPCMBuffer] = []
    private var systemBuffersSinceLastTranscribe: [AVAudioPCMBuffer] = []
    private var isMicCapturing = false
    private var activeDetectionContext: MeetingDetectionContext?
    private var inactiveDetectionPassCount = 0
    private var pendingMeetingFinalisation: Bool?

    // Configuration
    private let maxChunkSeconds: TimeInterval = 15       // Force transcribe after 15s even if still talking
    private let minChunkSeconds: TimeInterval = 2.0     // Don't transcribe chunks shorter than 2s
    private let silenceThreshold: Float = 0.003         // Audio level below this = silence
    private let silenceTriggerSeconds: TimeInterval = 2.0 // Silence this long → trigger transcription (was 0.6s)
    private let meetingsDirectory: URL

    // Adaptive chunking state
    private var lastSpeechTime: Date = Date()
    private var chunkStartTime: Date = Date()
    private var isSpeaking: Bool = false

    // Meeting transcription state
    private var lastTranscribedBufferCount: Int = 0
    private var isWhisperTranscribing: Bool = false
    private var whisperTranscriptionTimer: Timer?

    // Crash-safe incremental persistence
    private var incrementalSaveTimer: Timer?
    private let incrementalSaveInterval: TimeInterval = 10

    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        meetingsDirectory = appSupport.appendingPathComponent("EchoTune").appendingPathComponent("Meetings")

        // Create meetings directory
        try? FileManager.default.createDirectory(at: meetingsDirectory, withIntermediateDirectories: true)

        // Load past meetings
        loadPastMeetings()

        // Observe system audio level
        systemAudioCapture.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$systemAudioLevel)

        // Wire up audio buffer callback
        systemAudioCapture.onAudioBuffer = { [weak self] buffer in
            self?.appendAudioData(from: buffer, source: .system)
        }

        debugLog("✅ MeetingManager initialised (storage: \(meetingsDirectory.path))")
    }

    // MARK: - Start Meeting

    func startMeeting(title: String = "", template: MeetingTemplate = .general, detectedApp: String? = nil, isAutoDetected: Bool = false) {
        guard !isRecording else {
            debugLog("⚠️ MeetingManager: Already recording a meeting")
            return
        }

        guard prepareMeetingStart(isAutoDetected: isAutoDetected) else { return }

        let session = MeetingSession(
            title: title.isEmpty ? "Meeting \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))" : title,
            detectedApp: detectedApp,
            template: template
        )

        currentSession = session
        // Only auto-detected sessions carry a detection context — a manually
        // started meeting must never be auto-stopped by app-focus heuristics.
        activeDetectionContext = isAutoDetected ? MeetingManager.detectMeetingContext() : nil
        inactiveDetectionPassCount = 0
        pendingMeetingFinalisation = nil
        liveTranscript = ""
        userNotes = ""
        audioBuffer = Data()
        micBuffers.removeAll()
        systemBuffers.removeAll()
        micBuffersSinceLastTranscribe.removeAll()
        systemBuffersSinceLastTranscribe.removeAll()
        lastTranscriptLength = 0
        lastTranscribedBufferCount = 0
        lastSpeechTime = Date()

        debugLog("🎙️ MeetingManager: Starting meeting '\(session.title)'")

        let includeMicAudio = AppSettings.shared.meetingIncludeMicAudio
        if includeMicAudio {
            startMicCapture()
        }

        let captureSystemAudio = SystemAudioCapture.hasPermission()
        if captureSystemAudio {
            Task {
                do {
                    try await systemAudioCapture.startCapture()
                    debugLog("✅ MeetingManager: System audio capture also started")
                } catch {
                    debugLog("⚠️ MeetingManager: System audio capture failed (mic still active): \(error)")
                    await MainActor.run { self.systemAudioUnavailable = true }
                }
            }
        }

        self.isRecording = true
        self.startTimers()
        debugLog("✅ MeetingManager: Meeting recording started (mic: \(includeMicAudio ? "✅" : "❌"), system audio: \(captureSystemAudio ? "✅" : "❌"))")
    }

    func startScheduledMeeting(_ session: MeetingSession) {
        guard !isRecording else {
            debugLog("⚠️ MeetingManager: Already recording a meeting")
            return
        }

        guard prepareMeetingStart(isAutoDetected: false) else { return }

        var activeSession = session
        activeSession.startTime = Date() // Reset start time to now
        currentSession = activeSession

        // Scheduled meetings are user-intended: no auto-stop detection context.
        activeDetectionContext = nil
        inactiveDetectionPassCount = 0
        pendingMeetingFinalisation = nil
        liveTranscript = ""
        userNotes = ""
        audioBuffer = Data()
        micBuffers.removeAll()
        systemBuffers.removeAll()
        micBuffersSinceLastTranscribe.removeAll()
        systemBuffersSinceLastTranscribe.removeAll()
        lastTranscriptLength = 0
        lastTranscribedBufferCount = 0
        lastSpeechTime = Date()

        debugLog("🎙️ MeetingManager: Starting scheduled meeting '\(activeSession.title)'")

        let includeMicAudio = AppSettings.shared.meetingIncludeMicAudio
        if includeMicAudio {
            startMicCapture()
        }

        let captureSystemAudio = SystemAudioCapture.hasPermission()
        if captureSystemAudio {
            Task {
                do {
                    try await systemAudioCapture.startCapture()
                    debugLog("✅ MeetingManager: System audio capture also started")
                } catch {
                    debugLog("⚠️ MeetingManager: System audio capture failed (mic still active): \(error)")
                    await MainActor.run { self.systemAudioUnavailable = true }
                }
            }
        }

        self.isRecording = true
        self.startTimers()
        debugLog("✅ MeetingManager: Scheduled meeting recording started")
    }

    // MARK: - Start Preflight

    /// Common gate for every meeting start. Returns false when the meeting must
    /// not start (no audio source, or no way to transcribe). Never blocks on a
    /// missing Screen Recording permission alone — mic-only is fully supported.
    private func prepareMeetingStart(isAutoDetected: Bool) -> Bool {
        transcriptionWarning = nil
        summaryIssue = nil

        // Meetings transcribe locally with WhisperKit only. A meeting that can
        // never transcribe must not start silently (it would record a red badge
        // for an hour and produce an empty transcript).
        if WhisperEngine.shared.whisperKitRef == nil {
            let localModel: AIModel?
            if let current = ModelManager.shared.currentModel, current.category == .local, current.isInstalled {
                localModel = current
            } else {
                localModel = ModelManager.shared.installedModels.first(where: { $0.category == .local })
            }

            guard let model = localModel else {
                let message = "No local transcription model is installed. Download a model in Settings → AI Models, then start the meeting again."
                debugLog("❌ MeetingManager: Start blocked — no local model for transcription")
                if isAutoDetected {
                    NotificationManager.shared.showNotification(title: "Meeting Not Started", body: message, sound: true)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Can't Start Meeting Recording"
                    alert.informativeText = message
                    alert.runModal()
                }
                return false
            }

            // Model installed but not loaded yet — load it now. Audio buffers
            // accumulate (and failed chunks are re-queued) until it's ready.
            transcriptionWarning = "Preparing the transcription model — the transcript will begin once it's ready."
            WhisperEngine.shared.loadModel(model) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.transcriptionWarning = nil
                    case .failure(let error):
                        self?.transcriptionWarning = "Transcription model failed to load: \(error.localizedDescription)"
                    }
                }
            }
        }

        // Screen Recording permission: missing ≠ can't record. Proceed mic-only,
        // tell the user, and deep-link to the settings pane. Only block when
        // there is literally no audio source (mic disabled AND no system audio).
        let hasScreenPermission = SystemAudioCapture.hasPermission()
        systemAudioUnavailable = !hasScreenPermission

        if !hasScreenPermission {
            SystemAudioCapture.requestPermission() // shows the system prompt at most once per app lifetime

            guard AppSettings.shared.meetingIncludeMicAudio else {
                let message = "Microphone capture is off in Meeting settings and Screen Recording permission is missing — there is no audio source to record."
                debugLog("❌ MeetingManager: Start blocked — no capturable audio source")
                if isAutoDetected {
                    NotificationManager.shared.showNotification(title: "Meeting Not Started", body: message, sound: true)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Can't Start Meeting Recording"
                    alert.informativeText = message + " Enable the microphone in Settings → Meetings, or grant Screen Recording permission."
                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "Open System Settings")
                    if alert.runModal() == .alertSecondButtonReturn,
                       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                return false
            }

            if !isAutoDetected {
                let alert = NSAlert()
                alert.messageText = "System Audio Unavailable"
                alert.informativeText = "Recording will continue with your microphone only. To also capture the other participants, grant Screen Recording permission in System Settings and restart the meeting."
                alert.addButton(withTitle: "Continue Mic-Only")
                alert.addButton(withTitle: "Open System Settings")
                if alert.runModal() == .alertSecondButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        return true
    }

    // MARK: - Stop Meeting

    func stopMeeting(autoSummarise: Bool = true) {
        guard isRecording else { return }

        debugLog("⏹ MeetingManager: Stopping meeting recording...")

        durationTimer?.invalidate()
        durationTimer = nil
        stopMeetingTranscriptionTimer()
        stopIncrementalSaveTimer()

        Task {
            await systemAudioCapture.stopCapture()
        }
        stopMicCapture()

        isRecording = false
        inactiveDetectionPassCount = 0

        if isWhisperTranscribing {
            pendingMeetingFinalisation = autoSummarise
            return
        }

        transcribeAccumulatedAudio(force: true) { [weak self] in
            self?.finaliseMeeting(autoSummarise: autoSummarise)
        }
    }

    private func finaliseMeeting(autoSummarise: Bool) {
        pendingMeetingFinalisation = nil
        activeDetectionContext = nil
        micBuffers.removeAll()
        systemBuffers.removeAll()
        transcriptionWarning = nil
        systemAudioUnavailable = false

        guard var session = currentSession else { return }
        session.endTime = Date()
        session.transcript = liveTranscript
        session.userNotes = userNotes

        debugLog("📝 MeetingManager: Meeting ended. Duration: \(session.formattedDuration), Transcript: \(session.transcript.count) chars")

        saveMeeting(session)

        if autoSummarise && AppSettings.shared.meetingAutoSummarise {
            generateSummary(for: session)
        } else {
            currentSession = session
        }
    }

    // MARK: - Summary Generation

    private func generateSummary(for session: MeetingSession) {
        isGeneratingSummary = true

        summaryEngine.generateSummary(
            transcript: session.transcript,
            template: session.templateUsed,
            userNotes: session.userNotes
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isGeneratingSummary = false

                switch result {
                case .success(let summary):
                    var updatedSession = session
                    if updatedSession.title == "Meeting \(DateFormatter.localizedString(from: session.startTime, dateStyle: .short, timeStyle: .short))" {
                        updatedSession.title = summary.title
                    }
                    updatedSession.summary = summary.summary
                    updatedSession.actionItems = summary.actionItems
                    updatedSession.decisions = summary.decisions
                    updatedSession.keyPoints = summary.keyPoints
                    updatedSession.participants = summary.participants
                    // Only touch the live session if it IS this session —
                    // regenerating an old meeting must never clobber a new
                    // recording in progress (its transcript would be saved
                    // into the old meeting's file).
                    if self.currentSession?.id == session.id {
                        self.currentSession = updatedSession
                    }
                    self.saveMeeting(updatedSession)
                    self.summaryIssue = summary.isDegraded
                        ? "No AI API key configured — this is a basic text extract, not an AI summary. Add a key in Settings → AI Enhancement, then use Regenerate Summary."
                        : nil
                    debugLog("✅ MeetingManager: Summary generated for '\(updatedSession.title)'")

                case .failure(let error):
                    debugLog("❌ MeetingManager: Summary failed: \(error)")
                    self.summaryIssue = "Summary generation failed: \(error.localizedDescription) Use Regenerate Summary to retry."
                    if self.currentSession?.id == session.id {
                        self.currentSession = session
                    }
                }
            }
        }
    }

    /// Regenerate summary for an existing meeting
    func regenerateSummary(for meetingID: UUID, template: MeetingTemplate? = nil) {
        guard let index = pastMeetings.firstIndex(where: { $0.id == meetingID }) else { return }
        var meeting = pastMeetings[index]
        if let template = template {
            meeting.templateUsed = template
        }
        summaryIssue = nil
        isGeneratingSummary = true
        generateSummary(for: meeting)
    }

    // MARK: - Audio Processing (WhisperEngine-based, same as voice dictation)

    private func detectSpeech(in buffer: AVAudioPCMBuffer) -> Bool {
        if SileroVADEngine.shared.isReady() {
            let probability = SileroVADEngine.shared.detectSpeech(in: buffer)
            return probability > 0.5
        } else {
            guard let channelData = buffer.floatChannelData?[0] else { return false }
            let frameCount = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameCount {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(max(frameCount, 1)))
            return rms > silenceThreshold
        }
    }

    private func appendAudioData(from buffer: AVAudioPCMBuffer, source: AudioCaptureSource) {
        let hasSpeech = detectSpeech(in: buffer)
        
        objc_sync_enter(self)
        if hasSpeech {
            if micBuffers.isEmpty && systemBuffers.isEmpty {
                chunkStartTime = Date()
            }
            isSpeaking = true
            lastSpeechTime = Date()
        }
        
        // Accumulate buffers if speech is active or we are already in an active segment
        let isAccumulating = !micBuffers.isEmpty || !systemBuffers.isEmpty
        if hasSpeech || isAccumulating {
            switch source {
            case .mic:
                micBuffers.append(buffer)
                micBuffersSinceLastTranscribe.append(buffer)
            case .system:
                systemBuffers.append(buffer)
                systemBuffersSinceLastTranscribe.append(buffer)
            }
        }
        objc_sync_exit(self)

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(max(frameCount, 1)))
        
        DispatchQueue.main.async {
            self.systemAudioLevel = rms
        }
    }

    private func preferredTranscriptionSource() -> AudioCaptureSource {
        let detectedAppName = currentSession?.detectedApp?.lowercased() ?? ""
        let isCallStyleApp = detectedAppName.contains("whatsapp") ||
            detectedAppName.contains("signal") ||
            detectedAppName.contains("telegram") ||
            detectedAppName.contains("discord") ||
            detectedAppName.contains("facetime")

        if isCallStyleApp, !systemBuffers.isEmpty || systemAudioCapture.isCapturing {
            return .system
        }

        if !micBuffers.isEmpty || isMicCapturing {
            return .mic
        }

        if !systemBuffers.isEmpty || systemAudioCapture.isCapturing {
            return .system
        }

        return .mic
    }

    private func transcriptionBufferSnapshot() -> [AVAudioPCMBuffer] {
        switch preferredTranscriptionSource() {
        case .mic:
            return !micBuffers.isEmpty ? micBuffers : systemBuffers
        case .system:
            return !systemBuffers.isEmpty ? systemBuffers : micBuffers
        }
    }

    private func currentSnapshotBufferCount() -> Int {
        if AppSettings.shared.meetingIncludeMicAudio {
            return max(micBuffers.count, systemBuffers.count)
        }
        return transcriptionBufferSnapshot().count
    }

    private func meetingAudioSamplesSnapshot() throws -> [Float] {
        let shouldMixMicAndSystem = AppSettings.shared.meetingIncludeMicAudio && !micBuffers.isEmpty && !systemBuffers.isEmpty

        if shouldMixMicAndSystem {
            let micAudio = try WhisperEngine.shared.convertBuffersToFloatArray(micBuffers)
            let systemAudio = try WhisperEngine.shared.convertBuffersToFloatArray(systemBuffers)
            return mixAudioSamples(micAudio: micAudio, systemAudio: systemAudio)
        }

        return try WhisperEngine.shared.convertBuffersToFloatArray(transcriptionBufferSnapshot())
    }

    private func apply80HzHighPassFilter(to samples: [Float]) -> [Float] {
        let sampleRate: Double = 16000
        let cutoff: Double = 80.0
        let q: Double = 0.707

        let omega = 2.0 * .pi * cutoff / sampleRate
        let alpha = sin(omega) / (2.0 * q)
        let cosOmega = cos(omega)

        let b0 = (1.0 + cosOmega) / 2.0
        let b1 = -(1.0 + cosOmega)
        let b2 = (1.0 + cosOmega) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha

        // Normalize coefficients by a0
        let nb0 = Float(b0 / a0)
        let nb1 = Float(b1 / a0)
        let nb2 = Float(b2 / a0)
        let na1 = Float(a1 / a0)
        let na2 = Float(a2 / a0)

        var filtered = Array(repeating: Float(0), count: samples.count)
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0

        for i in 0..<samples.count {
            let x0 = samples[i]
            let y0 = nb0 * x0 + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2
            filtered[i] = y0

            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }
        return filtered
    }

    private func normalizeLoudness(samples: [Float], targetRMS: Float = 0.07) -> [Float] {
        guard !samples.isEmpty else { return samples }
        
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        
        // Noise floor threshold: -60dB FS (0.001 RMS)
        guard rms > 0.001 else { return samples }
        
        let gain = targetRMS / rms
        // Limit gain to a reasonable range: +12dB (4.0) to -20dB (0.1)
        let clampedGain = max(0.1, min(4.0, gain))
        
        var normalized = Array(repeating: Float(0), count: samples.count)
        vDSP_vsmul(samples, 1, [clampedGain], &normalized, 1, vDSP_Length(samples.count))
        
        return normalized
    }

    private func applySoftClipping(_ sample: Float) -> Float {
        let threshold: Float = 0.85
        let scale: Float = 0.15
        if sample > threshold {
            return threshold + scale * tanh((sample - threshold) / scale)
        } else if sample < -threshold {
            return -threshold + scale * tanh((sample + threshold) / scale)
        }
        return sample
    }

    private func mixAudioSamples(micAudio: [Float], systemAudio: [Float]) -> [Float] {
        let sampleCount = max(micAudio.count, systemAudio.count)
        guard sampleCount > 0 else { return [] }

        var mixed = Array(repeating: Float(0), count: sampleCount)

        // Envelope follower and ducking states
        var micEnvelope: Float = 0
        var duckFactor: Float = 1.0

        // Time constants for 16kHz sample rate
        let beta: Float = 0.006          // ~10ms envelope tracker
        let gammaAttack: Float = 0.003   // ~20ms duck attack
        let gammaRelease: Float = 0.00015 // ~400ms duck release

        let speechThreshold: Float = 0.015
        let targetDuck: Float = 0.25      // -12dB attenuation

        for index in 0..<sampleCount {
            let micSample = index < micAudio.count ? micAudio[index] : 0
            let systemSample = index < systemAudio.count ? systemAudio[index] : 0

            // 1. Update mic envelope follower
            micEnvelope = (1.0 - beta) * micEnvelope + beta * abs(micSample)

            // 2. Smooth speech-triggered ducking
            let target = micEnvelope > speechThreshold ? targetDuck : 1.0
            if target < duckFactor {
                duckFactor = (1.0 - gammaAttack) * duckFactor + gammaAttack * target
            } else {
                duckFactor = (1.0 - gammaRelease) * duckFactor + gammaRelease * target
            }

            // 3. Mix
            let micGain: Float = 0.7
            let systemGain: Float = 0.7 * duckFactor
            
            let mixedSample = (micSample * micGain) + (systemSample * systemGain)

            // 4. Soft peak limiter to prevent digital clipping
            mixed[index] = applySoftClipping(mixedSample)
        }

        return mixed
    }

    private func startMeetingTranscriptionTimer() {
        whisperTranscriptionTimer?.invalidate()
        whisperTranscriptionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.transcribeAccumulatedAudio()
        }
    }

    private func stopMeetingTranscriptionTimer() {
        whisperTranscriptionTimer?.invalidate()
        whisperTranscriptionTimer = nil
    }

    private func calculateAverageRMS(_ buffers: [AVAudioPCMBuffer]) -> Float {
        guard !buffers.isEmpty else { return 0 }
        var totalRMS: Float = 0
        var count: Int = 0
        for buffer in buffers {
            guard let channelData = buffer.floatChannelData?[0] else { continue }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { continue }
            var sum: Float = 0
            for i in 0..<frameCount {
                sum += channelData[i] * channelData[i]
            }
            totalRMS += sqrt(sum / Float(frameCount))
            count += 1
        }
        return count > 0 ? (totalRMS / Float(count)) : 0
    }

    private func mixSegmentAudio(mic: [AVAudioPCMBuffer], system: [AVAudioPCMBuffer]) throws -> [Float] {
        let shouldMixMicAndSystem = AppSettings.shared.meetingIncludeMicAudio && !mic.isEmpty && !system.isEmpty

        if shouldMixMicAndSystem {
            let micAudio = try WhisperEngine.shared.convertBuffersToFloatArray(mic)
            let systemAudio = try WhisperEngine.shared.convertBuffersToFloatArray(system)
            
            let filteredMic = apply80HzHighPassFilter(to: micAudio)
            let normalizedMic = normalizeLoudness(samples: filteredMic)
            let normalizedSystem = normalizeLoudness(samples: systemAudio)
            
            return mixAudioSamples(micAudio: normalizedMic, systemAudio: normalizedSystem)
        }

        if !mic.isEmpty {
            let micAudio = try WhisperEngine.shared.convertBuffersToFloatArray(mic)
            let filteredMic = apply80HzHighPassFilter(to: micAudio)
            return normalizeLoudness(samples: filteredMic)
        } else if !system.isEmpty {
            let systemAudio = try WhisperEngine.shared.convertBuffersToFloatArray(system)
            return normalizeLoudness(samples: systemAudio)
        }

        return []
    }

    private func transcribeAccumulatedAudio(force: Bool = false, completion: (() -> Void)? = nil) {
        guard !isWhisperTranscribing else {
            completion?()
            return
        }

        // Determine if we have any buffers to transcribe
        let hasBuffers: Bool
        objc_sync_enter(self)
        hasBuffers = !micBuffers.isEmpty || !systemBuffers.isEmpty
        objc_sync_exit(self)

        guard hasBuffers else {
            completion?()
            return
        }

        // Check conditions: force, or silence trigger, or max chunk time exceeded
        let silenceDuration = Date().timeIntervalSince(lastSpeechTime)
        let segmentDuration = Date().timeIntervalSince(chunkStartTime)

        let shouldTranscribe = force ||
            silenceDuration >= silenceTriggerSeconds ||
            segmentDuration >= maxChunkSeconds

        guard shouldTranscribe else {
            completion?()
            return
        }

        // Thread-safe copy and clear of current segment buffers
        var segmentMic: [AVAudioPCMBuffer] = []
        var segmentSystem: [AVAudioPCMBuffer] = []
        objc_sync_enter(self)
        segmentMic = self.micBuffers
        segmentSystem = self.systemBuffers
        self.micBuffers.removeAll()
        self.systemBuffers.removeAll()
        self.micBuffersSinceLastTranscribe.removeAll()
        self.systemBuffersSinceLastTranscribe.removeAll()
        objc_sync_exit(self)

        isWhisperTranscribing = true

        Task {
            do {
                // Mix segment audio
                let audioArray = try self.mixSegmentAudio(mic: segmentMic, system: segmentSystem)
                
                guard !audioArray.isEmpty else {
                    await MainActor.run {
                        self.isWhisperTranscribing = false
                        completion?()
                    }
                    return
                }

                let rms = sqrt(audioArray.map { $0 * $0 }.reduce(0, +) / Float(max(audioArray.count, 1)))
                guard rms > self.silenceThreshold else {
                    await MainActor.run {
                        self.isWhisperTranscribing = false
                        completion?()
                    }
                    return
                }

                // Determine speaker from the energy levels of the segment
                let micEnergy = self.calculateAverageRMS(segmentMic)
                let systemEnergy = self.calculateAverageRMS(segmentSystem)

                let speakerLabel: String
                if !AppSettings.shared.meetingIncludeMicAudio {
                    speakerLabel = "Speaker 2 (Guest)"
                } else if micEnergy > systemEnergy && micEnergy > 0.002 {
                    speakerLabel = "Speaker 1 (Me)"
                } else if systemEnergy > micEnergy && systemEnergy > 0.002 {
                    speakerLabel = "Speaker 2 (Guest)"
                } else {
                    speakerLabel = "Speaker 1 (Me)"
                }

                // Always transcribe live locally with WhisperKit — cloud transcription is
                // never used during a live meeting (avoids unbounded RAM growth and total
                // transcript loss on a network failure).
                guard let whisperKit = WhisperEngine.shared.whisperKitRef else {
                    throw NSError(domain: "MeetingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "WhisperKit not loaded"])
                }

                let result = try await WhisperEngine.shared.transcribeWithCurrentSettings(
                    audioArray: audioArray,
                    whisperKit: whisperKit
                )
                let text = result.outputText.trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    self.isWhisperTranscribing = false
                    self.transcriptionWarning = nil // transcription is working again
                    self.handleMeetingTranscription(text, speakerLabel: speakerLabel)

                    // Re-evaluate if more buffers arrived while we were transcribing
                    let hasMoreBuffers: Bool
                    objc_sync_enter(self)
                    hasMoreBuffers = !self.micBuffers.isEmpty || !self.systemBuffers.isEmpty
                    objc_sync_exit(self)

                    if hasMoreBuffers && self.pendingMeetingFinalisation != nil {
                        // If we are finalising, force transcribe any leftover buffers
                        self.transcribeAccumulatedAudio(force: true) { [weak self] in
                            if let autoSummarise = self?.pendingMeetingFinalisation {
                                self?.finaliseMeeting(autoSummarise: autoSummarise)
                            }
                        }
                    } else if let autoSummarise = self.pendingMeetingFinalisation {
                        self.finaliseMeeting(autoSummarise: autoSummarise)
                    } else {
                        completion?()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isWhisperTranscribing = false
                    debugLog("⚠️ MeetingManager: Transcription failed: \(error)")

                    // The snapshot was destructively taken from the buffer
                    // arrays — put it back (at the front, preserving order) so
                    // the audio is retried instead of silently destroyed.
                    // Capped so a persistent failure can't grow RAM forever.
                    let requeueCap = 12_000 // ≈ 15–20 min of buffers
                    objc_sync_enter(self)
                    self.micBuffers.insert(contentsOf: segmentMic, at: 0)
                    self.systemBuffers.insert(contentsOf: segmentSystem, at: 0)
                    if self.micBuffers.count > requeueCap {
                        self.micBuffers.removeFirst(self.micBuffers.count - requeueCap)
                    }
                    if self.systemBuffers.count > requeueCap {
                        self.systemBuffers.removeFirst(self.systemBuffers.count - requeueCap)
                    }
                    objc_sync_exit(self)

                    self.transcriptionWarning = "Live transcription is failing (\(error.localizedDescription)). Audio is being kept and retried."

                    if let autoSummarise = self.pendingMeetingFinalisation {
                        self.finaliseMeeting(autoSummarise: autoSummarise)
                    } else {
                        completion?()
                    }
                }
            }
        }
    }

    /// Tracks what we've already shown to avoid duplicating text
    private var lastTranscriptLength: Int = 0

    private func calculateRepetitionRatio(_ text: String) -> Float {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        guard words.count > 4 else { return 0.0 }
        
        var bigrams: [String] = []
        for i in 0..<(words.count - 1) {
            bigrams.append("\(words[i]) \(words[i+1])")
        }
        
        guard !bigrams.isEmpty else { return 0.0 }
        let uniqueBigrams = Set(bigrams)
        let ratio = 1.0 - (Float(uniqueBigrams.count) / Float(bigrams.count))
        return ratio
    }

    private func handleMeetingTranscription(_ text: String, speakerLabel: String) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }

        // Filter hallucinations
        let hallucinations: Set<String> = [
            "thank you", "thanks", "thank you.", "thanks.",
            "thanks for watching", "thanks for watching.",
            "you", "thank", "bye", "goodbye", "bye.", "goodbye.",
            "...", ".", "so", "the", "and", "i", "a",
            "uh", "um", "hmm", "huh", "oh", "ah",
            "subtitle", "subtitles", "subscribe",
            "please subscribe", "like and subscribe",
            "thank you for watching", "thank you for watching.",
            "thanks for listening", "thanks for listening.",
            "you know", "right", "okay", "ok",
            "♪", "♪♪", "♪ ♪", "[music]", "(music)",
            "cheers", "cheers."
        ]
        
        guard !hallucinations.contains(cleanedText.lowercased()) else {
            return
        }

        // Repetition check (Phase 4)
        let repRatio = calculateRepetitionRatio(cleanedText)
        if repRatio > 0.70 {
            debugLog("⚠️ MeetingManager: Discarding repetitive transcript segment (ratio: \(repRatio)): '\(cleanedText)'")
            return
        }

        // Add a new chunk for this segment
        if let offsetSeconds = currentSession.map({ Date().timeIntervalSince($0.startTime) }) {
            // Get timestamp of the chunk relative to start of the meeting
            let chunkOffset = max(0, offsetSeconds - (Date().timeIntervalSince(chunkStartTime)))
            
            if var lastChunk = self.currentSession?.chunks.last, lastChunk.speaker == speakerLabel {
                // Append to same speaker chunk if consecutive
                let updatedText = lastChunk.text + " " + cleanedText
                self.currentSession?.chunks[self.currentSession!.chunks.count - 1] = TranscriptChunk(
                    id: lastChunk.id,
                    timestamp: lastChunk.timestamp,
                    offsetSeconds: lastChunk.offsetSeconds,
                    text: updatedText,
                    speaker: speakerLabel
                )
            } else {
                let chunk = TranscriptChunk(
                    offsetSeconds: chunkOffset,
                    text: cleanedText,
                    speaker: speakerLabel
                )
                self.currentSession?.chunks.append(chunk)
            }

            // Rebuild full transcript from chunks
            let fullTranscript = self.currentSession?.chunks.map { chunk in
                let prefix = chunk.speaker.map { "[\($0)] " } ?? ""
                return "\(prefix)\(chunk.text)"
            }.joined(separator: "\n") ?? ""

            self.liveTranscript = fullTranscript
            self.currentSession?.transcript = fullTranscript
        }

        debugLog("📝 MeetingManager: Live transcript updated (\(self.liveTranscript.count) chars, chunks: \(self.currentSession?.chunks.count ?? 0))")
    }

    // MARK: - WAV Helper

    private func createWAVData(fromSamples samples: [Float], sampleRate: Int) -> Data {
        var pcmData = Data(capacity: samples.count * MemoryLayout<Int16>.size)

        for sample in samples {
            let clipped = max(-1, min(1, sample))
            var intSample = Int16(clipped * Float(Int16.max))
            pcmData.append(contentsOf: withUnsafeBytes(of: &intSample) { Array($0) })
        }

        return createWAVData(from: pcmData, sampleRate: sampleRate, channels: 1)
    }

    private func createWAVData(from pcmData: Data, sampleRate: Int, channels: Int) -> Data {
        var wavData = Data()
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = pcmData.count
        let fileSize = 36 + dataSize

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        wavData.append(pcmData)

        return wavData
    }

    // MARK: - Timers

    private func startTimers() {
        // Duration timer — update UI every second
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.currentSession else { return }
            self.recordingDuration = Date().timeIntervalSince(session.startTime)
        }

        // Transcription timer — transcribe meeting audio every 3s
        micBuffers.removeAll()
        systemBuffers.removeAll()
        lastTranscribedBufferCount = 0
        isWhisperTranscribing = false
        startMeetingTranscriptionTimer()

        // Incremental save timer — persist the in-progress session every ~10s so a
        // crash or force-quit mid-meeting loses at most a few seconds of data.
        startIncrementalSaveTimer()
    }

    private func startIncrementalSaveTimer() {
        incrementalSaveTimer?.invalidate()
        incrementalSaveTimer = Timer.scheduledTimer(withTimeInterval: incrementalSaveInterval, repeats: true) { [weak self] _ in
            self?.saveInProgressSession()
        }
    }

    private func stopIncrementalSaveTimer() {
        incrementalSaveTimer?.invalidate()
        incrementalSaveTimer = nil
    }

    private func saveInProgressSession() {
        guard isRecording, var session = currentSession else { return }
        session.transcript = liveTranscript
        session.userNotes = userNotes
        currentSession?.userNotes = userNotes
        saveMeeting(session)
    }

    // MARK: - Persistence

    func saveMeeting(_ session: MeetingSession) {
        let filePath = meetingsDirectory.appendingPathComponent("\(session.id.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(session)
            // .atomic: a crash mid-write must not corrupt the previous good
            // snapshot — this file IS the crash-safety net.
            try data.write(to: filePath, options: .atomic)

            // Update past meetings list
            if let index = pastMeetings.firstIndex(where: { $0.id == session.id }) {
                pastMeetings[index] = session
            } else {
                pastMeetings.insert(session, at: 0)
            }

            debugLog("💾 MeetingManager: Saved meeting to \(filePath.lastPathComponent)")
        } catch {
            debugLog("❌ MeetingManager: Failed to save meeting: \(error)")
        }
    }

    private func loadPastMeetings() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: meetingsDirectory, includingPropertiesForKeys: nil) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var meetings: [MeetingSession] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let meeting = try? decoder.decode(MeetingSession.self, from: data) {
                meetings.append(meeting)
            }
        }

        // Sort by most recent first
        pastMeetings = meetings.sorted { $0.startTime > $1.startTime }
        debugLog("📂 MeetingManager: Loaded \(pastMeetings.count) past meetings")
    }

    func deleteMeeting(_ meetingID: UUID) {
        let filePath = meetingsDirectory.appendingPathComponent("\(meetingID.uuidString).json")
        try? FileManager.default.removeItem(at: filePath)
        pastMeetings.removeAll { $0.id == meetingID }
        debugLog("🗑 MeetingManager: Deleted meeting \(meetingID)")
    }

    // MARK: - Meeting App Detection

    struct MeetingDetectionContext {
        let appName: String
        let bundleIdentifier: String
        let sourceHint: String?

        var defaultMeetingTitle: String {
            if let sourceHint, !sourceHint.isEmpty {
                return "\(appName) — \(sourceHint)"
            }
            return "\(appName) Meeting"
        }

        var cooldownKey: String {
            let hint = sourceHint?.lowercased() ?? ""
            return "\(bundleIdentifier.lowercased())::\(hint)"
        }
    }

    /// Check if a known meeting app is the frontmost application.
    static func detectMeetingApp() -> String? {
        detectMeetingContext()?.appName
    }

    static func detectMeetingContext() -> MeetingDetectionContext? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else { return nil }

        let directMeetingApps: [String: String] = [
            "us.zoom.xos": "Zoom",
            "com.microsoft.teams2": "Microsoft Teams",
            "com.microsoft.teams": "Microsoft Teams",
            "com.apple.FaceTime": "FaceTime",
            "com.tinyspeck.slackmacgap": "Slack Huddle",
            "com.webex.meetingmanager": "Webex",
            "com.discord.Discord": "Discord Call",
            "net.whatsapp.WhatsApp": "WhatsApp Call",
            "org.whispersystems.signal-desktop": "Signal Call",
            "ru.keepcoder.Telegram": "Telegram Call"
        ]

        if let appName = directMeetingApps[bundleID] {
            return MeetingDetectionContext(appName: appName, bundleIdentifier: bundleID, sourceHint: nil)
        }

        if let browserURL = activeBrowserURL(bundleIdentifier: bundleID),
           let meetingContext = classifyMeetingURL(browserURL, bundleIdentifier: bundleID) {
            return meetingContext
        }

        return nil
    }

    func shouldAutoStopDetectedMeeting() -> Bool {
        guard isRecording, let detectionContext = activeDetectionContext else { return false }

        if !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == detectionContext.bundleIdentifier }) {
            debugLog("🛑 MeetingManager: Detected app is no longer running")
            return true
        }

        let silenceDuration = Date().timeIntervalSince(lastSpeechTime)

        if let currentContext = Self.detectMeetingContext(), currentContext.cooldownKey == detectionContext.cooldownKey {
            if isSilentCallStyleMeeting, recordingDuration > 20, silenceDuration > 45 {
                debugLog("🛑 MeetingManager: Auto-stopping after prolonged silence in call-style app")
                return true
            }

            inactiveDetectionPassCount = 0
            return false
        }

        // The meeting app lost frontmost status — but the user may just be
        // taking notes in another app while the call continues. Losing focus
        // alone is NEVER grounds to stop; require sustained silence too.
        if silenceDuration < 30 {
            inactiveDetectionPassCount = 0
            return false
        }

        inactiveDetectionPassCount += 1

        if isSilentCallStyleMeeting, silenceDuration > 20 {
            debugLog("🛑 MeetingManager: Auto-stopping after call context disappeared")
            return true
        }

        if inactiveDetectionPassCount >= 2 {
            debugLog("🛑 MeetingManager: Auto-stopping — context gone and \(Int(silenceDuration))s of silence")
            return true
        }
        return false
    }

    private var isSilentCallStyleMeeting: Bool {
        guard let appName = currentSession?.detectedApp?.lowercased() else { return false }
        return appName.contains("whatsapp") ||
            appName.contains("signal") ||
            appName.contains("telegram") ||
            appName.contains("discord") ||
            appName.contains("facetime")
    }

    private static func classifyMeetingURL(_ urlString: String, bundleIdentifier: String) -> MeetingDetectionContext? {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else { return nil }

        if host.contains("meet.google.com") {
            return MeetingDetectionContext(appName: "Google Meet", bundleIdentifier: bundleIdentifier, sourceHint: host)
        }

        if host.contains("teams.microsoft.com") || host.contains("teams.live.com") {
            return MeetingDetectionContext(appName: "Microsoft Teams", bundleIdentifier: bundleIdentifier, sourceHint: host)
        }

        if host.contains("zoom.us") {
            return MeetingDetectionContext(appName: "Zoom", bundleIdentifier: bundleIdentifier, sourceHint: host)
        }

        if host.contains("discord.com") {
            return MeetingDetectionContext(appName: "Discord Call", bundleIdentifier: bundleIdentifier, sourceHint: host)
        }

        if host.contains("web.whatsapp.com") {
            return MeetingDetectionContext(appName: "WhatsApp Web Call", bundleIdentifier: bundleIdentifier, sourceHint: host)
        }

        if host.contains("app.slack.com") && urlString.lowercased().contains("huddle") {
            return MeetingDetectionContext(appName: "Slack Huddle", bundleIdentifier: bundleIdentifier, sourceHint: host)
        }

        if host.contains("web.telegram.org") {
            return MeetingDetectionContext(appName: "Telegram Call", bundleIdentifier: bundleIdentifier, sourceHint: host)
        }

        return nil
    }

    private static func activeBrowserURL(bundleIdentifier: String) -> String? {
        let scriptSource: String?

        switch bundleIdentifier {
        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac", "company.thebrowser.Browser":
            scriptSource = "tell application id \"\(bundleIdentifier)\" to return URL of active tab of front window"
        case "com.apple.Safari":
            scriptSource = "tell application id \"com.apple.Safari\" to return URL of front document"
        default:
            scriptSource = nil
        }

        guard let scriptSource else { return nil }
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: scriptSource)
        let result = script?.executeAndReturnError(&errorInfo)

        if let errorInfo {
            debugLog("⚠️ MeetingManager: Browser URL detection failed for \(bundleIdentifier): \(errorInfo)")
            return nil
        }

        return result?.stringValue
    }

    // MARK: - Microphone Capture for Meetings

    private func startMicCapture() {
        guard !isMicCapturing else { return }

        micEngine = AVAudioEngine()
        guard let engine = micEngine else { return }

        let inputNode = engine.inputNode
        let hwFormat = inputNode.inputFormat(forBus: 0)

        debugLog("🎤 MeetingManager: Starting mic capture (format: \(hwFormat))")

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hwFormat) { [weak self] buffer, _ in
            guard let self = self, self.isMicCapturing else { return }
            self.appendAudioData(from: buffer, source: .mic)
        }

        do {
            try engine.start()
            isMicCapturing = true
            debugLog("✅ MeetingManager: Mic capture started")
        } catch {
            debugLog("❌ MeetingManager: Mic capture failed: \(error)")
            micEngine = nil
        }
    }

    private func stopMicCapture() {
        guard isMicCapturing, let engine = micEngine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        micEngine = nil
        isMicCapturing = false
        debugLog("⏹ MeetingManager: Mic capture stopped")
    }
}
