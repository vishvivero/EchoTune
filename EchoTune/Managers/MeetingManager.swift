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

    // MARK: - Private
    private let systemAudioCapture = SystemAudioCapture()
    private let summaryEngine = MeetingSummaryEngine.shared
    private var audioBuffer = Data()
    private var chunkTimer: Timer?
    private var durationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Configuration
    private let chunkIntervalSeconds: TimeInterval = 30  // Transcribe every 30 seconds
    private let meetingsDirectory: URL

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
            self?.appendAudioData(from: buffer)
        }

        debugLog("✅ MeetingManager initialised (storage: \(meetingsDirectory.path))")
    }

    // MARK: - Start Meeting

    func startMeeting(title: String = "", template: MeetingTemplate = .general, detectedApp: String? = nil) {
        guard !isRecording else {
            debugLog("⚠️ MeetingManager: Already recording a meeting")
            return
        }

        // Check permission
        guard SystemAudioCapture.hasPermission() else {
            debugLog("❌ MeetingManager: Screen Recording permission required")
            SystemAudioCapture.requestPermission()
            return
        }

        let session = MeetingSession(
            title: title.isEmpty ? "Meeting \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))" : title,
            detectedApp: detectedApp,
            template: template
        )

        currentSession = session
        liveTranscript = ""
        audioBuffer = Data()

        debugLog("🎙️ MeetingManager: Starting meeting '\(session.title)'")

        // Start system audio capture
        Task {
            do {
                try await systemAudioCapture.startCapture()

                await MainActor.run {
                    self.isRecording = true
                    self.startTimers()
                }

                debugLog("✅ MeetingManager: Meeting recording started")
            } catch {
                debugLog("❌ MeetingManager: Failed to start capture: \(error)")
                await MainActor.run {
                    self.currentSession = nil
                }
            }
        }
    }

    // MARK: - Stop Meeting

    func stopMeeting(autoSummarise: Bool = true) {
        guard isRecording else { return }

        debugLog("⏹ MeetingManager: Stopping meeting recording...")

        // Stop timers
        chunkTimer?.invalidate()
        chunkTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil

        // Stop audio capture
        Task {
            await systemAudioCapture.stopCapture()
        }

        isRecording = false

        // Process any remaining audio buffer
        processAudioChunk()

        // Finalise session
        guard var session = currentSession else { return }
        session.endTime = Date()
        session.transcript = liveTranscript

        debugLog("📝 MeetingManager: Meeting ended. Duration: \(session.formattedDuration), Transcript: \(session.transcript.count) chars")

        // Save before summary (in case summary fails)
        saveMeeting(session)

        // Generate summary
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
                    self.currentSession = updatedSession
                    self.saveMeeting(updatedSession)
                    debugLog("✅ MeetingManager: Summary generated for '\(updatedSession.title)'")

                case .failure(let error):
                    debugLog("❌ MeetingManager: Summary failed: \(error)")
                    self.currentSession = session
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
        isGeneratingSummary = true
        generateSummary(for: meeting)
    }

    // MARK: - Audio Processing

    private func appendAudioData(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Convert Float32 PCM to 16-bit PCM (WAV compatible)
        var int16Buffer = [Int16](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let sample = max(-1.0, min(1.0, channelData[i]))
            int16Buffer[i] = Int16(sample * Float(Int16.max))
        }

        let data = int16Buffer.withUnsafeBufferPointer { bufferPointer in
            Data(buffer: bufferPointer)
        }

        audioBuffer.append(data)
    }

    private func processAudioChunk() {
        guard !audioBuffer.isEmpty else { return }
        guard let session = currentSession else { return }

        let chunkData = audioBuffer
        audioBuffer = Data()  // Reset buffer

        let offsetSeconds = Date().timeIntervalSince(session.startTime)

        debugLog("🔄 MeetingManager: Processing audio chunk (\(chunkData.count) bytes, offset: \(Int(offsetSeconds))s)")

        // Create WAV data from raw PCM
        let wavData = createWAVData(from: chunkData, sampleRate: 16000, channels: 1)

        // Transcribe using the existing TranscriptionEngine
        TranscriptionEngine.shared.transcribe(audioData: wavData) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    debugLog("📝 MeetingManager: Chunk transcribed: \(trimmed.prefix(80))...")

                    // Append to live transcript
                    if !self.liveTranscript.isEmpty {
                        self.liveTranscript += " "
                    }
                    self.liveTranscript += trimmed

                    // Add chunk with timestamp
                    let chunk = TranscriptChunk(offsetSeconds: offsetSeconds, text: trimmed)
                    self.currentSession?.chunks.append(chunk)
                    self.currentSession?.transcript = self.liveTranscript

                case .failure(let error):
                    debugLog("⚠️ MeetingManager: Chunk transcription failed: \(error)")
                }
            }
        }
    }

    // MARK: - WAV Helper

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
        // Chunk timer — transcribe every N seconds
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkIntervalSeconds, repeats: true) { [weak self] _ in
            self?.processAudioChunk()
        }

        // Duration timer — update UI every second
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.currentSession else { return }
            self.recordingDuration = Date().timeIntervalSince(session.startTime)
        }
    }

    // MARK: - Persistence

    private func saveMeeting(_ session: MeetingSession) {
        let filePath = meetingsDirectory.appendingPathComponent("\(session.id.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(session)
            try data.write(to: filePath)

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

    /// Check if a known meeting app is the frontmost application
    static func detectMeetingApp() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let bundleID = frontApp.bundleIdentifier ?? ""

        let meetingApps: [String: String] = [
            "us.zoom.xos": "Zoom",
            "com.microsoft.teams2": "Microsoft Teams",
            "com.microsoft.teams": "Microsoft Teams",
            "com.google.Chrome": "Google Meet",  // Best effort — Chrome could be anything
            "com.brave.Browser": "Google Meet",
            "com.apple.Safari": "FaceTime",
            "com.apple.FaceTime": "FaceTime",
            "com.tinyspeck.slackmacgap": "Slack Huddle",
            "com.webex.meetingmanager": "Webex",
            "com.discord.Discord": "Discord Call",
        ]

        return meetingApps[bundleID]
    }
}
