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

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    // Audio session properties
    var audioEngine: AVAudioEngine?  // Public for accessing input format
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: AVAudioPCMBuffer?
    private var audioFile: AVAudioFile?
    
    // Recording state
    @Published var isRecording = false
    @Published var isPermissionGranted = false
    @Published var audioLevel: Float = 0.0
    @Published var speechProbability: Float = 0.0  // VAD: 0.0-1.0
    @Published var isSpeechDetected: Bool = false  // VAD: true if speech detected
    @Published var recordingDuration: TimeInterval = 0  // Live recording duration for UI

    // Recording metrics
    private var recordingStartTime: Date?
    private(set) var lastRecordingDuration: TimeInterval = 0
    private var durationTimer: Timer?

    // Maximum recording duration (default 30 minutes, 0 = unlimited)
    static let maxRecordingDuration: TimeInterval = 1800 // 30 minutes

    // VAD integration
    private var recordedBuffers: [AVAudioPCMBuffer] = []  // Store buffers for VAD analysis
    var onSpeechDetected: ((VADManager.SpeechProbability) -> Void)?  // Callback for speech detection

    // Audio format (will be set to hardware's native format)
    private var recordingFormat: AVAudioFormat?

    // Growing audio buffer storage — replaces the old fixed 60s cap
    // Audio is stored in chunks to avoid massive contiguous allocations
    private var audioChunks: [AVAudioPCMBuffer] = []
    private var currentChunk: AVAudioPCMBuffer?
    private var currentChunkFrameOffset: AVAudioFrameCount = 0
    private static let chunkDurationSeconds: Double = 30 // Each chunk holds 30s of audio

    // Format normalization — ensures all downstream code gets Float32 non-interleaved
    private var tapConverter: AVAudioConverter?
    private var normalizedFormat: AVAudioFormat?

    // Callback for live audio streaming
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // Temporary file URL for recording (using CAF format for better Float32 support)
    private var tempFileURL: URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("recording.caf")
    }
    
    override init() {
        super.init()
        checkPermission()
    }

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
    
    func startRecording() {
        guard !isRecording else {
            debugLog("⚠️ Already recording, ignoring start request")
            return
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

        // Reset growing buffer storage
        audioChunks.removeAll()
        currentChunk = nil
        currentChunkFrameOffset = 0

        // Initialize audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let inputNode = inputNode else {
            debugLog("❌ Failed to get input node")
            return
        }

        // Use the hardware's native input format instead of forcing a specific sample rate
        let hardwareFormat = inputNode.inputFormat(forBus: 0)

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

        // Allocate first chunk (30 seconds of audio per chunk)
        let chunkFrameCapacity = AVAudioFrameCount(activeFormat.sampleRate * AudioManager.chunkDurationSeconds)
        currentChunk = AVAudioPCMBuffer(pcmFormat: activeFormat, frameCapacity: chunkFrameCapacity)

        // Also maintain the legacy audioBuffer for backward compat (sized for first 30s, will grow via chunks)
        audioBuffer = AVAudioPCMBuffer(pcmFormat: activeFormat, frameCapacity: chunkFrameCapacity)

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

            // Update published properties on main thread
            DispatchQueue.main.async {
                self.speechProbability = vadResult.probability
                self.isSpeechDetected = vadResult.isSpeech
            }

            // Notify callback of speech detection
            self.onSpeechDetected?(vadResult)

            // Store buffer for later VAD analysis
            self.recordedBuffers.append(safeCopy)

            // Send buffer to live transcription if callback is set
            self.onAudioBuffer?(safeCopy)

            // Append to growing chunk-based storage
            self.appendToChunkedStorage(safeCopy)

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
                }
            }
        } catch {
            debugLog("Failed to start audio engine: \(error.localizedDescription)")
            return
        }
    }

    /// Appends audio to the growing chunk-based buffer system.
    /// When the current chunk fills up, it's stored and a new chunk is allocated.
    private func appendToChunkedStorage(_ buffer: AVAudioPCMBuffer) {
        guard var chunk = currentChunk else { return }

        let totalFrames = Int(buffer.frameLength)
        var sourceOffset = 0
        var remaining = totalFrames

        while remaining > 0 {
            let framesAvailable = Int(chunk.frameCapacity - currentChunkFrameOffset)

            if framesAvailable == 0 {
                // Current chunk is full — save it and allocate a new one
                chunk.frameLength = currentChunkFrameOffset
                audioChunks.append(chunk)

                // Memory cap: limit to ~600 chunks (~10 min at 30s/chunk = 300 chunks, but be generous)
                let maxChunks = 600
                if audioChunks.count > maxChunks {
                    audioChunks.removeFirst()
                    debugLog("⚠️ Audio buffer memory cap reached — dropped oldest chunk")
                }

                let newCapacity = AVAudioFrameCount(buffer.format.sampleRate * AudioManager.chunkDurationSeconds)
                guard let newChunk = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: newCapacity) else {
                    debugLog("⚠️ Failed to allocate new audio chunk — recording may be truncated")
                    return
                }
                currentChunk = newChunk
                chunk = newChunk
                currentChunkFrameOffset = 0

                let totalSeconds = Double(audioChunks.count) * AudioManager.chunkDurationSeconds
                debugLog("📦 Audio chunk \(audioChunks.count) stored (\(Int(totalSeconds))s total buffered)")
                continue
            }

            let copyCount = min(remaining, framesAvailable)

            // Copy audio data into current chunk
            for channel in 0..<Int(buffer.format.channelCount) {
                guard let inputData = buffer.floatChannelData?[channel],
                      let outputData = chunk.floatChannelData?[channel] else { break }
                memcpy(outputData.advanced(by: Int(currentChunkFrameOffset)),
                       inputData.advanced(by: sourceOffset),
                       copyCount * MemoryLayout<Float>.size)
            }

            currentChunkFrameOffset += AVAudioFrameCount(copyCount)
            chunk.frameLength = currentChunkFrameOffset
            sourceOffset += copyCount
            remaining -= copyCount
        }

        // Also update the legacy audioBuffer for backward compatibility
        if let audioBuffer = self.audioBuffer {
            let offset = Int(audioBuffer.frameLength)
            let legacyAvailable = Int(audioBuffer.frameCapacity - audioBuffer.frameLength)
            let legacyCopy = min(totalFrames, legacyAvailable)

            if legacyCopy > 0 {
                for channel in 0..<Int(buffer.format.channelCount) {
                    if let inputData = buffer.floatChannelData?[channel],
                       let outputData = audioBuffer.floatChannelData?[channel] {
                        memcpy(outputData.advanced(by: offset), inputData, legacyCopy * MemoryLayout<Float>.size)
                    }
                }
                audioBuffer.frameLength += AVAudioFrameCount(legacyCopy)
            }
        }
    }
    
    enum AudioEngine {
        case whisper    // Needs Float32 format (CAF)
        case appleSpeech // Needs Int16 format (CAF)
        case cloud      // Needs WAV (RIFF) format for Groq/Deepgram
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

        // Merge all audio chunks into a single buffer for conversion
        let mergedBuffer = mergeAllAudioChunks()

        guard let finalBuffer = mergedBuffer else {
            debugLog("⚠️ No audio data captured")
            cleanup()
            return nil
        }

        let totalDuration = Double(finalBuffer.frameLength) / finalBuffer.format.sampleRate
        debugLog("📊 Total recorded audio: \(String(format: "%.1f", totalDuration))s (\(finalBuffer.frameLength) frames across \(audioChunks.count + 1) chunks)")

        // Convert buffer using optimized path for target engine
        let audioData = convertBufferToWAVData(finalBuffer, forEngine: engine)

        // Clean up
        cleanup()

        // Return nil if conversion failed (empty data)
        return audioData.isEmpty ? nil : audioData
    }

    /// Merge all audio chunks (including current partial chunk) into a single buffer
    private func mergeAllAudioChunks() -> AVAudioPCMBuffer? {
        // Finalize the current chunk
        var allChunks = audioChunks
        if let current = currentChunk, currentChunkFrameOffset > 0 {
            current.frameLength = currentChunkFrameOffset
            allChunks.append(current)
        }

        guard !allChunks.isEmpty else {
            // Fallback to legacy buffer
            return audioBuffer
        }

        // Calculate total frames
        let totalFrames = allChunks.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard totalFrames > 0 else { return audioBuffer }

        let format = allChunks[0].format
        guard let merged = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            debugLog("⚠️ Failed to allocate merged buffer (\(totalFrames) frames) — falling back to legacy buffer")
            return audioBuffer
        }

        var writeOffset: AVAudioFrameCount = 0
        for chunk in allChunks {
            let frameCount = Int(chunk.frameLength)
            for channel in 0..<Int(format.channelCount) {
                if let src = chunk.floatChannelData?[channel],
                   let dst = merged.floatChannelData?[channel] {
                    memcpy(dst.advanced(by: Int(writeOffset)), src, frameCount * MemoryLayout<Float>.size)
                }
            }
            writeOffset += chunk.frameLength
        }
        merged.frameLength = totalFrames

        return merged
    }

    private func cleanup() {
        self.audioEngine = nil
        self.audioBuffer = nil
        self.audioChunks.removeAll()
        self.currentChunk = nil
        self.currentChunkFrameOffset = 0
        self.tapConverter = nil
        self.normalizedFormat = nil
    }

    func getRecordingDuration() -> TimeInterval {
        return lastRecordingDuration
    }

    /// Returns the total buffered audio duration in seconds (across all chunks)
    var totalBufferedDuration: TimeInterval {
        guard let format = recordingFormat else { return 0 }
        let chunkFrames = audioChunks.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        let currentFrames = currentChunkFrameOffset
        return Double(chunkFrames + currentFrames) / format.sampleRate
    }

    /// Formatted recording duration string (MM:SS)
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
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
    
    private func convertBufferToWAVData(_ buffer: AVAudioPCMBuffer, forEngine engine: AudioEngine = .appleSpeech) -> Data {
        // Check if buffer has any data
        if buffer.frameLength == 0 {
            debugLog("❌ Buffer is empty - no audio data recorded")
            return Data()
        }

        debugLog("📊 Buffer info:")
        debugLog("   Frame length: \(buffer.frameLength)")
        debugLog("   Frame capacity: \(buffer.frameCapacity)")
        debugLog("   Format: \(buffer.format)")
        debugLog("   Target engine: \(engine)")

        // Start performance monitoring
        PerformanceMonitor.shared.startAudioConversion(dataSize: Int(buffer.frameLength) * 4)

        // Create CAF file in temporary directory
        do {
            // Remove existing file if present
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        do {
            let sourceFormat = buffer.format
            let data: Data

            switch engine {
            case .whisper:
                // ✅ OPTIMIZED: Whisper path - Keep Float32, no conversion needed!
                debugLog("🚀 Optimized path: Whisper (Float32, no conversion)")

                // Whisper uses Float32 directly - just write the buffer as-is
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: sourceFormat.sampleRate,
                    AVNumberOfChannelsKey: sourceFormat.channelCount,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]

                audioFile = try AVAudioFile(
                    forWriting: tempFileURL,
                    settings: settings,
                    commonFormat: .pcmFormatFloat32,
                    interleaved: false
                )

                try audioFile?.write(from: buffer)
                debugLog("✓ CAF file written (Float32, no conversion)")

                data = try Data(contentsOf: tempFileURL)

            case .appleSpeech:
                // Apple Speech path - Convert to Int16 (what SFSpeechRecognizer prefers)
                debugLog("🔄 Converting Float32 → Int16 for Apple Speech Recognition")

                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: sourceFormat.sampleRate,
                    channels: sourceFormat.channelCount,
                    interleaved: false
                ) else {
                    debugLog("❌ Failed to create Int16 format")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                    debugLog("❌ Failed to create audio converter")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                let targetBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: buffer.frameCapacity
                )!

                var inputConsumed = false
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    if inputConsumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                var error: NSError?
                let status = converter.convert(to: targetBuffer, error: &error, withInputFrom: inputBlock)

                if status == .error {
                    debugLog("❌ Conversion failed: \(error?.localizedDescription ?? "unknown")")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                debugLog("✓ Converted to Int16 PCM (\(targetBuffer.frameLength) frames)")

                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: targetFormat.sampleRate,
                    AVNumberOfChannelsKey: targetFormat.channelCount,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]

                audioFile = try AVAudioFile(
                    forWriting: tempFileURL,
                    settings: settings,
                    commonFormat: .pcmFormatInt16,
                    interleaved: false
                )

                try audioFile?.write(from: targetBuffer)
                debugLog("✓ CAF file written (Int16 PCM)")

                data = try Data(contentsOf: tempFileURL)

            case .cloud:
                // Cloud services (Groq/Deepgram) need proper WAV (RIFF) format
                // Convert to 16kHz mono Int16 WAV — universally accepted
                debugLog("☁️ Converting to WAV (RIFF) for cloud upload")

                let cloudSampleRate: Double = 16000
                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: cloudSampleRate,
                    channels: 1,
                    interleaved: true
                ) else {
                    debugLog("❌ Failed to create cloud target format")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                    debugLog("❌ Failed to create audio converter for cloud")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * cloudSampleRate / sourceFormat.sampleRate)) + 100
                guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                    debugLog("❌ Failed to create cloud output buffer")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                var inputConsumed = false
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    if inputConsumed { outStatus.pointee = .endOfStream; return nil }
                    inputConsumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                var convError: NSError?
                let convStatus = converter.convert(to: targetBuffer, error: &convError, withInputFrom: inputBlock)
                if convStatus == .error {
                    debugLog("❌ Cloud audio conversion failed: \(convError?.localizedDescription ?? "unknown")")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                debugLog("✓ Converted to 16kHz mono Int16 (\(targetBuffer.frameLength) frames)")

                // Write as proper WAV (RIFF) file
                let wavURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_upload.wav")
                try? FileManager.default.removeItem(at: wavURL)

                let wavFile = try AVAudioFile(
                    forWriting: wavURL,
                    settings: targetFormat.settings,
                    commonFormat: .pcmFormatInt16,
                    interleaved: true
                )
                try wavFile.write(from: targetBuffer)

                data = try Data(contentsOf: wavURL)
                try? FileManager.default.removeItem(at: wavURL)
                debugLog("✓ WAV file created: \(data.count) bytes")
            }

            PerformanceMonitor.shared.endAudioConversion()

            debugLog("✓ Audio data size: \(data.count) bytes")
            return data
        } catch {
            debugLog("❌ Failed to convert buffer: \(error.localizedDescription)")
            PerformanceMonitor.shared.endAudioConversion()
            return Data()
        }
    }

    // MARK: - Audio Device Selection

    // Published property for current input device
    @Published var currentInputDevice: AudioDevice?

    func getAvailableInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []

        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)

        guard status == noErr else {
            debugLog("❌ Failed to get audio devices size")
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)

        guard status == noErr else {
            debugLog("❌ Failed to get audio devices")
            return devices
        }

        // Get default input device ID
        var defaultInputDeviceID: AudioDeviceID = 0
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &dataSize, &defaultInputDeviceID)

        // Filter for input devices and get their names
        for deviceID in audioDevices {
            // Check if device has input channels
            var inputChannelsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: 0
            )

            status = AudioObjectGetPropertyDataSize(deviceID, &inputChannelsAddress, 0, nil, &dataSize)
            guard status == noErr else { continue }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }

            status = AudioObjectGetPropertyData(deviceID, &inputChannelsAddress, 0, nil, &dataSize, bufferList)
            guard status == noErr, bufferList.pointee.mNumberBuffers > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var name: CFString = "" as CFString
            dataSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &dataSize, &name)

            guard status == noErr else { continue }

            let deviceName = name as String
            let isDefault = (deviceID == defaultInputDeviceID)
            let (deviceType, deviceIcon) = self.getDeviceTypeAndIcon(for: deviceName)

            devices.append(AudioDevice(
                id: String(deviceID),
                name: deviceName,
                type: deviceType,
                icon: deviceIcon,
                isDefault: isDefault
            ))

            if isDefault {
                currentInputDevice = AudioDevice(
                    id: String(deviceID),
                    name: deviceName,
                    type: deviceType,
                    icon: deviceIcon,
                    isDefault: true
                )
            }
        }

        return devices
    }

    private func getDeviceTypeAndIcon(for deviceName: String) -> (type: String, icon: String) {
        let lowercasedName = deviceName.lowercased()

        if lowercasedName.contains("built-in") || lowercasedName.contains("internal") {
            return ("Internal", "mic.fill")
        } else if lowercasedName.contains("airpods") {
            return ("Bluetooth", "airpodspro")
        } else if lowercasedName.contains("bluetooth") {
            return ("Bluetooth", "wave.3.right")
        } else if lowercasedName.contains("usb") {
            return ("USB", "mic.badge.plus")
        } else if lowercasedName.contains("external") {
            return ("External", "mic.badge.plus")
        } else if lowercasedName.contains("display") || lowercasedName.contains("hdmi") {
            return ("Display", "display")
        } else {
            return ("External", "mic")
        }
    }

    func selectAudioDevice(id: String) {
        guard let deviceID = AudioDeviceID(id) else {
            debugLog("❌ Invalid device ID")
            return
        }

        // Set as default input device
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceIDValue = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceIDValue
        )

        if status == noErr {
            debugLog("✓ Successfully set audio input device: \(id)")

            // Update current device
            let devices = getAvailableInputDevices()
            currentInputDevice = devices.first(where: { $0.id == id })

            // Restart audio engine if recording
            if isRecording {
                _ = stopRecording()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startRecording()
                }
            }
        } else {
            debugLog("❌ Failed to set audio input device: \(status)")
        }
    }

    // MARK: - VAD Integration

    /// Get VAD analysis of recorded audio
    func getVADAnalysis() -> VADManager.AnalysisResult? {
        guard !recordedBuffers.isEmpty else {
            debugLog("⚠️ No recorded buffers available for VAD analysis")
            return nil
        }

        guard let format = recordingFormat else {
            debugLog("⚠️ No recording format available")
            return nil
        }

        return VADManager.shared.analyzeSpeechSegments(
            from: recordedBuffers,
            sampleRate: format.sampleRate
        )
    }

    /// Check if recording has significant speech
    func hasSignificantSpeech() -> Bool {
        guard !recordedBuffers.isEmpty else {
            return false
        }

        return VADManager.shared.hasSignificantSpeech(in: recordedBuffers)
    }

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
