//
//  AudioManager.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import AVFoundation
import Combine
import CoreAudio

// MARK: - Audio Device Model

struct AudioDevice: Identifiable {
    let id: String
    let name: String
    let type: String
    let icon: String
    var isDefault: Bool = false
}

// MARK: - AudioManager Core

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    // MARK: - Audio Session Properties

    var audioEngine: AVAudioEngine?  // Public for accessing input format
    private var inputNode: AVAudioInputNode?
    var audioBuffer: AVAudioPCMBuffer?
    var audioFile: AVAudioFile?

    // MARK: - Recording State

    @Published var isRecording = false
    @Published var isPermissionGranted = false
    @Published var audioLevel: Float = 0.0
    @Published var speechProbability: Float = 0.0  // VAD: 0.0-1.0
    @Published var isSpeechDetected: Bool = false  // VAD: true if speech detected
    @Published var recordingDuration: TimeInterval = 0  // Live recording duration for UI

    // MARK: - Recording Metrics

    private var recordingStartTime: Date?
    private(set) var lastRecordingDuration: TimeInterval = 0
    private var durationTimer: Timer?

    // Maximum recording duration (default 30 minutes, 0 = unlimited)
    static let maxRecordingDuration: TimeInterval = 1800 // 30 minutes

    // MARK: - VAD Integration

    var recordedBuffers: [AVAudioPCMBuffer] = []  // Kept for backward compatibility, unused
    var recordedVADHistory: [VADManager.SpeechProbability] = [] // Efficient VAD analysis history
    var onSpeechDetected: ((VADManager.SpeechProbability) -> Void)?  // Callback for speech detection
    var onMaxDurationReached: (() -> Void)?  // Fired once when maxRecordingDuration is hit
    
    // Background queue for writing audio to disk
    private let fileWriteQueue = DispatchQueue(label: "com.echotune.AudioManager.fileWriteQueue", qos: .userInitiated)
    private let whisperConversionQueue = DispatchQueue(label: "com.echotune.AudioManager.whisperConversionQueue", qos: .userInitiated)

    // MARK: - Audio Format

    var recordingFormat: AVAudioFormat?

    // MARK: - Chunked Audio Storage

    // Growing audio buffer storage — replaces the old fixed 60s cap
    // Audio is stored in chunks to avoid massive contiguous allocations
    var audioChunks: [AVAudioPCMBuffer] = []
    var currentChunk: AVAudioPCMBuffer?
    var currentChunkFrameOffset: AVAudioFrameCount = 0
    static let chunkDurationSeconds: Double = 30 // Each chunk holds 30s of audio

    // MARK: - Format Normalization

    // Format normalization — ensures all downstream code gets Float32 non-interleaved
    private var tapConverter: AVAudioConverter?
    private var normalizedFormat: AVAudioFormat?

    // Dedicated Whisper stream format. Converting once at capture time avoids
    // constructing a new resampler for every 4-second live transcription tick.
    private var whisperTapConverter: AVAudioConverter?
    private var whisperFormat: AVAudioFormat?

    // MARK: - Callbacks

    // Callback for live audio streaming (native/recording format)
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // Whisper receives a dedicated 16 kHz mono stream so its live ticks do not
    // repeatedly resample the accumulated native-format recording.
    var onWhisperAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // MARK: - Temporary File URL

    // Temporary file URL for recording (using CAF format for better Float32 support)
    var tempFileURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("recording.caf")
    }

    // MARK: - Published Device Property

    // Published property for current input device
    @Published var currentInputDevice: AudioDevice?

    // MARK: - Init

    override init() {
        super.init()
        checkPermission()
    }

    // MARK: - Permissions

    func checkPermission() {
        // macOS uses AVCaptureDevice for microphone permission
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            isPermissionGranted = true
        case .denied, .restricted:
            isPermissionGranted = false
        case .notDetermined:
            isPermissionGranted = false
        @unknown default:
            isPermissionGranted = false
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        // macOS uses AVCaptureDevice for microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isPermissionGranted = granted
                completion(granted)
            }
        }
    }

    // MARK: - Recording

    private var _totalFramesWritten: Int64 = 0
    var totalFramesWritten: Int64 {
        get {
            fileWriteQueue.sync { _totalFramesWritten }
        }
        set {
            fileWriteQueue.async { self._totalFramesWritten = newValue }
        }
    }

    /// Outcome of a recording start attempt (7.4.4).
    enum StartResult {
        case started
        case alreadyRecording
        case noInputDevice
        case engineStartFailed(String)

        var isSuccess: Bool {
            if case .started = self { return true }
            return false
        }
    }

    /// Removes the tap and stops the engine so a failed start cannot leave the
    /// microphone open or a stale tap installed.
    private func teardownAfterFailedStart() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isRecording = false
        recordingStartTime = nil
    }

    @discardableResult
    func startRecording() -> StartResult {
        guard !isRecording else {
            debugLog("⚠️ Already recording, ignoring start request")
            return .alreadyRecording
        }

        // Clean up any existing audio engine first
        if let existingEngine = audioEngine, existingEngine.isRunning {
            debugLog("⚠️ Stopping existing audio engine")
            existingEngine.stop()
            existingEngine.inputNode.removeTap(onBus: 0)
        }

        // Reset VAD state for new recording
        VADManager.shared.resetState()
        recordedBuffers.removeAll()
        recordedVADHistory.removeAll()

        // Reset growing buffer storage
        audioChunks.removeAll()
        currentChunk = nil
        currentChunkFrameOffset = 0

        // Initialize audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let inputNode = inputNode else {
            debugLog("❌ Failed to get input node")
            teardownAfterFailedStart()
            return .noInputDevice
        }

        // Use the hardware's native input format instead of forcing a specific sample rate
        let hardwareFormat = inputNode.inputFormat(forBus: 0)

        // With no working input device (Bluetooth headset off, USB mic unplugged)
        // the format comes back 0 Hz / 0 ch — building AVAudioFormat from it
        // returns nil and installTap would throw. Bail out with a clear message.
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            debugLog("❌ No valid audio input device (format: \(hardwareFormat))")
            NotificationManager.shared.showNotification(
                title: "No Microphone Available",
                body: "Connect a microphone and try again.",
                sound: false
            )
            teardownAfterFailedStart()
            return .noInputDevice
        }

        debugLog("🎤 Recording with hardware format: \(hardwareFormat)")
        debugLog("   Sample rate: \(hardwareFormat.sampleRate) Hz")
        debugLog("   Channels: \(hardwareFormat.channelCount)")
        debugLog("🎙️ VAD enabled: \(VADManager.shared.config.enabled)")
        debugLog("📏 Max recording duration: \(AudioManager.maxRecordingDuration > 0 ? "\(Int(AudioManager.maxRecordingDuration))s" : "unlimited")")

        // Normalize to Float32 non-interleaved if hardware format isn't already
        if hardwareFormat.commonFormat != .pcmFormatFloat32 || hardwareFormat.isInterleaved {
            let normalized = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: hardwareFormat.sampleRate,
                channels: hardwareFormat.channelCount,
                interleaved: false
            )!
            tapConverter = AVAudioConverter(from: hardwareFormat, to: normalized)
            normalizedFormat = normalized
            recordingFormat = normalized
            debugLog("🔄 Tap format normalization: \(hardwareFormat) → Float32 non-interleaved")
        } else {
            tapConverter = nil
            normalizedFormat = nil
            recordingFormat = hardwareFormat
            debugLog("✅ Hardware format is already Float32 non-interleaved")
        }

        let activeFormat = normalizedFormat ?? hardwareFormat

        // Prepare one stateful converter for the Whisper stream. The converter
        // runs on a serial queue below, preserving buffer order while keeping
        // the real-time audio tap free of resampling work.
        whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )
        if let whisperFormat {
            whisperTapConverter = AVAudioConverter(from: activeFormat, to: whisperFormat)
            debugLog("🎙️ Whisper capture stream: \(activeFormat.sampleRate)Hz/\(activeFormat.channelCount)ch → 16kHz mono")
        }

        // Open audio file for writing to disk
        do {
            try? FileManager.default.removeItem(at: tempFileURL)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: activeFormat.sampleRate,
                AVNumberOfChannelsKey: activeFormat.channelCount,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: !activeFormat.isInterleaved
            ]
            audioFile = try AVAudioFile(
                forWriting: tempFileURL,
                settings: settings,
                commonFormat: activeFormat.commonFormat,
                interleaved: activeFormat.isInterleaved
            )
            _totalFramesWritten = 0
            debugLog("📝 Opened audio file for streaming to disk at \(tempFileURL.path)")
        } catch {
            debugLog("❌ Failed to create AVAudioFile for streaming: \(error.localizedDescription)")
            teardownAfterFailedStart()
            return .engineStartFailed("Could not open audio file: \(error.localizedDescription)")
        }

        // Set up tap on input node using the hardware's native format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] (buffer, time) in
            guard let self = self, self.isRecording else { return }

            // Normalize format if needed (e.g., Int16 → Float32)
            let normalizedBuffer: AVAudioPCMBuffer
            if let converter = self.tapConverter, let normFmt = self.normalizedFormat {
                guard let converted = AVAudioPCMBuffer(pcmFormat: normFmt, frameCapacity: buffer.frameLength) else { return }
                var error: NSError?
                var inputConsumed = false
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    if inputConsumed { outStatus.pointee = .noDataNow; return nil }
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                let status = converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
                guard status != .error else { return }
                converted.frameLength = buffer.frameLength
                normalizedBuffer = converted
            } else {
                normalizedBuffer = buffer
            }

            // CRITICAL: Copy buffer before any async use — tap buffers are reused by the audio engine
            guard let safeCopy = self.copyBuffer(normalizedBuffer) else { return }

            // VAD: Detect speech in this buffer
            let vadResult = VADManager.shared.detectSpeech(in: safeCopy)

            // Record for post-recording analysis — hasSignificantSpeech() reads
            // this after stop; without it every recording is rejected as silent.
            self.recordedVADHistory.append(vadResult)

            // Update published properties on main thread
            DispatchQueue.main.async {
                self.speechProbability = vadResult.probability
                self.isSpeechDetected = vadResult.isSpeech
            }

            // Notify callback of speech detection
            self.onSpeechDetected?(vadResult)

            // Send the native-format copy to Apple Speech or other consumers.
            self.onAudioBuffer?(safeCopy)

            // Convert once into Whisper's 16 kHz mono format. This replaces
            // the previous per-tick AVAudioConverter construction in
            // WhisperEngine.convertBuffersToFloatArray().
            if self.onWhisperAudioBuffer != nil {
                self.whisperConversionQueue.async { [weak self] in
                    guard let self else { return }
                    guard let whisperBuffer = self.convertToWhisperBuffer(safeCopy) else {
                        debugLog("⚠️ Failed to convert capture buffer to Whisper format")
                        return
                    }
                    self.onWhisperAudioBuffer?(whisperBuffer)
                }
            }

            // Write to audio file on background queue to keep memory footprint flat
            self.fileWriteQueue.async { [weak self] in
                guard let self = self, let file = self.audioFile else { return }
                do {
                    try file.write(from: safeCopy)
                    self._totalFramesWritten += Int64(safeCopy.frameLength)
                } catch {
                    debugLog("❌ Failed to write buffer chunk to disk: \(error.localizedDescription)")
                }
            }

            // Calculate audio level (RMS)
            self.calculateAudioLevel(safeCopy)
        }

        // Start audio engine
        do {
            try audioEngine?.start()
            isRecording = true
            recordingStartTime = Date()

            // Start duration tracking timer
            DispatchQueue.main.async {
                self.recordingDuration = 0
                self.durationTimer?.invalidate()
                self.durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self, let start = self.recordingStartTime else { return }
                    self.recordingDuration = Date().timeIntervalSince(start)

                    // Enforce the documented 30-minute cap: auto-stop once and
                    // let the coordinator route to the correct stop path.
                    let max = AudioManager.maxRecordingDuration
                    if max > 0, self.recordingDuration >= max {
                        self.durationTimer?.invalidate()
                        self.durationTimer = nil
                        self.onMaxDurationReached?()
                    }
                }
            }
        } catch {
            debugLog("Failed to start audio engine: \(error.localizedDescription)")
            teardownAfterFailedStart()
            return .engineStartFailed(error.localizedDescription)
        }

        return .started
    }

    func stopRecording(forEngine engine: AudioEngine = .appleSpeech) -> Data? {
        guard isRecording, let audioEngine = audioEngine else {
            return nil
        }

        // Calculate recording duration
        if let startTime = recordingStartTime {
            lastRecordingDuration = Date().timeIntervalSince(startTime)
        }

        // Stop duration timer
        DispatchQueue.main.async {
            self.durationTimer?.invalidate()
            self.durationTimer = nil
        }

        // Stop recording
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        // Flush the dedicated Whisper conversion stream before the caller
        // starts finalisation, otherwise the final converted buffers could
        // arrive after WhisperEngine snapshots its tail.
        whisperConversionQueue.sync {
            self.flushWhisperConverter()
        }

        // Wait for all remaining disk writes to finish, then close file
        fileWriteQueue.sync {
            self.audioFile = nil
        }

        // Convert file using optimized path for target engine
        let audioData = convertFileToEngineFormat(forEngine: engine)

        // Clean up
        cleanup()

        // Return nil if conversion failed (empty data)
        return audioData.isEmpty ? nil : audioData
    }

    // MARK: - Cleanup

    private func cleanup() {
        self.audioEngine = nil
        self.audioBuffer = nil
        self.audioChunks.removeAll()
        self.currentChunk = nil
        self.currentChunkFrameOffset = 0
        self.tapConverter = nil
        self.normalizedFormat = nil
        self.whisperTapConverter = nil
        self.whisperFormat = nil
        try? FileManager.default.removeItem(at: tempFileURL)
    }

    /// Converts one captured native-format buffer to the persistent Whisper
    /// stream format. Called serially, once per capture buffer.
    private func convertToWhisperBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter = whisperTapConverter,
              let whisperFormat else { return nil }

        let ratio = whisperFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: capacity) else {
            return nil
        }

        var inputConsumed = false
        var conversionError: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if inputConsumed {
                status.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            status.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: output, error: &conversionError, withInputFrom: inputBlock)
        if let conversionError {
            debugLog("⚠️ Whisper capture conversion failed: \(conversionError.localizedDescription)")
            return nil
        }
        guard status != .error, output.frameLength > 0 else { return nil }
        return output
    }

    /// Flushes the resampler's small delayed tail at end of recording.
    /// Without an explicit end-of-stream signal, AVAudioConverter can retain
    /// a few samples from the final capture buffer.
    private func flushWhisperConverter() {
        guard let converter = whisperTapConverter,
              let whisperFormat else { return }

        guard let output = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: 1024) else {
            return
        }

        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            inputStatus.pointee = .endOfStream
            return nil
        }
        if let conversionError {
            debugLog("⚠️ Whisper capture flush failed: \(conversionError.localizedDescription)")
            return
        }
        guard status != .error, output.frameLength > 0 else { return }
        onWhisperAudioBuffer?(output)
    }

    // MARK: - Duration Helpers

    func getRecordingDuration() -> TimeInterval {
        return lastRecordingDuration
    }

    /// Returns the total buffered audio duration in seconds (across all chunks)
    var totalBufferedDuration: TimeInterval {
        guard let format = recordingFormat else { return 0 }
        return Double(totalFramesWritten) / format.sampleRate
    }

    /// Formatted recording duration string (MM:SS)
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Audio Level

    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        // Calculate RMS (root mean square) for audio level
        var rms: Float = 0.0

        for channel in 0..<channelCount {
            let data = channelData[channel]

            for frame in 0..<frameCount {
                let sample = data[frame]
                rms += sample * sample
            }
        }

        rms = sqrt(rms / Float(frameCount * channelCount))

        // Apply smoothing and publish on main thread to satisfy SwiftUI's threading rules
        let smoothingFactor: Float = 0.1
        let newLevel = audioLevel * (1 - smoothingFactor) + rms * smoothingFactor
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = newLevel
        }
    }

    // MARK: - Buffer Copy

    /// Copy an audio buffer (for storing)
    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else {
            return nil
        }

        copy.frameLength = buffer.frameLength

        // Copy channel data
        for channel in 0..<Int(buffer.format.channelCount) {
            if let src = buffer.floatChannelData?[channel],
               let dst = copy.floatChannelData?[channel] {
                memcpy(dst, src, Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }

        return copy
    }
}
