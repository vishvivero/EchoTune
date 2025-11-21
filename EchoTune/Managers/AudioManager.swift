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

    // Recording metrics
    private var recordingStartTime: Date?
    private(set) var lastRecordingDuration: TimeInterval = 0

    // VAD integration
    private var recordedBuffers: [AVAudioPCMBuffer] = []  // Store buffers for VAD analysis
    var onSpeechDetected: ((VADManager.SpeechProbability) -> Void)?  // Callback for speech detection

    // Audio format (will be set to hardware's native format)
    private var recordingFormat: AVAudioFormat?

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
            print("⚠️ Already recording, ignoring start request")
            return
        }

        // Clean up any existing audio engine first
        if let existingEngine = audioEngine, existingEngine.isRunning {
            print("⚠️ Stopping existing audio engine")
            existingEngine.stop()
            existingEngine.inputNode.removeTap(onBus: 0)
        }

        // Reset VAD state for new recording
        VADManager.shared.resetState()
        recordedBuffers.removeAll()

        // Initialize audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let inputNode = inputNode else {
            print("❌ Failed to get input node")
            return
        }

        // Use the hardware's native input format instead of forcing a specific sample rate
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        recordingFormat = hardwareFormat

        print("🎤 Recording with hardware format: \(hardwareFormat)")
        print("   Sample rate: \(hardwareFormat.sampleRate) Hz")
        print("   Channels: \(hardwareFormat.channelCount)")
        print("🎙️ VAD enabled: \(VADManager.shared.config.enabled)")

        // Prepare buffer for recording
        let bufferSize = AVAudioFrameCount(hardwareFormat.sampleRate * 60) // 60 seconds max
        audioBuffer = AVAudioPCMBuffer(
            pcmFormat: hardwareFormat,
            frameCapacity: bufferSize
        )

        // Set up tap on input node using the hardware's native format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] (buffer, time) in
            guard let self = self, self.isRecording else { return }

            // VAD: Detect speech in this buffer
            let vadResult = VADManager.shared.detectSpeech(in: buffer)

            // Update published properties on main thread
            DispatchQueue.main.async {
                self.speechProbability = vadResult.probability
                self.isSpeechDetected = vadResult.isSpeech
            }

            // Notify callback of speech detection
            self.onSpeechDetected?(vadResult)

            // Store buffer for later VAD analysis
            if let bufferCopy = self.copyBuffer(buffer) {
                self.recordedBuffers.append(bufferCopy)
            }

            // Send buffer to live transcription if callback is set
            self.onAudioBuffer?(buffer)

            // Also append buffer data for backup/fallback
            if let audioBuffer = self.audioBuffer {
                let offset = Int(audioBuffer.frameLength)
                let framesAvailable = Int(audioBuffer.frameCapacity - audioBuffer.frameLength)
                let framesToCopy = min(Int(buffer.frameLength), framesAvailable)

                if framesToCopy > 0 {
                    // Copy audio data to our buffer
                    for channel in 0..<Int(buffer.format.channelCount) {
                        let inputData = buffer.floatChannelData![channel]
                        let outputData = audioBuffer.floatChannelData![channel]

                        for frame in 0..<framesToCopy {
                            outputData[offset + frame] = inputData[frame]
                        }
                    }

                    audioBuffer.frameLength += AVAudioFrameCount(framesToCopy)
                }

                // Calculate audio level (RMS)
                self.calculateAudioLevel(buffer)
            }
        }
        
        // Start audio engine
        do {
            try audioEngine?.start()
            isRecording = true
            recordingStartTime = Date()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            return
        }
    }
    
    enum AudioEngine {
        case whisper    // Needs Float32 format
        case appleSpeech // Needs Int16 format
    }

    func stopRecording(forEngine engine: AudioEngine = .appleSpeech) -> Data? {
        guard isRecording, let audioEngine = audioEngine, let audioBuffer = audioBuffer else {
            return nil
        }

        // Calculate recording duration
        if let startTime = recordingStartTime {
            lastRecordingDuration = Date().timeIntervalSince(startTime)
        }

        // Stop recording
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        // Convert buffer using optimized path for target engine
        let audioData = convertBufferToWAVData(audioBuffer, forEngine: engine)

        // Clean up
        self.audioEngine = nil
        self.audioBuffer = nil

        // Return nil if conversion failed (empty data)
        return audioData.isEmpty ? nil : audioData
    }

    func getRecordingDuration() -> TimeInterval {
        return lastRecordingDuration
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
            print("❌ Buffer is empty - no audio data recorded")
            return Data()
        }

        print("📊 Buffer info:")
        print("   Frame length: \(buffer.frameLength)")
        print("   Frame capacity: \(buffer.frameCapacity)")
        print("   Format: \(buffer.format)")
        print("   Target engine: \(engine)")

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
                print("🚀 Optimized path: Whisper (Float32, no conversion)")

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
                print("✓ CAF file written (Float32, no conversion)")

                data = try Data(contentsOf: tempFileURL)

            case .appleSpeech:
                // Apple Speech path - Convert to Int16 (what SFSpeechRecognizer prefers)
                print("🔄 Converting Float32 → Int16 for Apple Speech Recognition")

                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: sourceFormat.sampleRate,
                    channels: sourceFormat.channelCount,
                    interleaved: false
                ) else {
                    print("❌ Failed to create Int16 format")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                    print("❌ Failed to create audio converter")
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
                    print("❌ Conversion failed: \(error?.localizedDescription ?? "unknown")")
                    PerformanceMonitor.shared.endAudioConversion()
                    return Data()
                }

                print("✓ Converted to Int16 PCM (\(targetBuffer.frameLength) frames)")

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
                print("✓ CAF file written (Int16 PCM)")

                data = try Data(contentsOf: tempFileURL)
            }

            PerformanceMonitor.shared.endAudioConversion()

            print("✓ CAF data size: \(data.count) bytes")
            return data
        } catch {
            print("❌ Failed to convert buffer to CAF: \(error.localizedDescription)")
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
            print("❌ Failed to get audio devices size")
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)

        guard status == noErr else {
            print("❌ Failed to get audio devices")
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
            print("❌ Invalid device ID")
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
            print("✓ Successfully set audio input device: \(id)")

            // Update current device
            let devices = getAvailableInputDevices()
            currentInputDevice = devices.first(where: { $0.id == id })

            // Restart audio engine if recording
            if isRecording {
                stopRecording()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startRecording()
                }
            }
        } else {
            print("❌ Failed to set audio input device: \(status)")
        }
    }

    // MARK: - VAD Integration

    /// Get VAD analysis of recorded audio
    func getVADAnalysis() -> VADManager.AnalysisResult? {
        guard !recordedBuffers.isEmpty else {
            print("⚠️ No recorded buffers available for VAD analysis")
            return nil
        }

        guard let format = recordingFormat else {
            print("⚠️ No recording format available")
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
