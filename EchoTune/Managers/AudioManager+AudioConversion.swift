//
//  AudioManager+AudioConversion.swift
//  EchoTune
//
//  Audio format conversion — WAV/CAF encoding for different engines
//  Split from AudioManager.swift
//

import Foundation
import AVFoundation

// MARK: - Audio Conversion

extension AudioManager {

    // MARK: - Audio Engine Type

    enum AudioEngine {
        case whisper    // Needs Float32 format (CAF)
        case appleSpeech // Needs Int16 format (CAF)
        case cloud      // Needs WAV (RIFF) format for Groq/Deepgram
    }

    func convertFileToEngineFormat(forEngine engine: AudioEngine) -> Data {
        let sourceURL = tempFileURL
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            debugLog("❌ Source audio file does not exist")
            return Data()
        }
        
        // Start performance monitoring
        PerformanceMonitor.shared.startAudioConversion(dataSize: 0)
        
        defer {
            PerformanceMonitor.shared.endAudioConversion()
        }
        
        do {
            let srcFile = try AVAudioFile(forReading: sourceURL)
            let sourceFormat = srcFile.processingFormat
            let totalFrames = srcFile.length
            
            guard totalFrames > 0 else {
                debugLog("❌ Source audio file has no frames")
                return Data()
            }
            
            debugLog("📊 Source Audio File Info:")
            debugLog("   Length: \(totalFrames) frames")
            debugLog("   Format: \(sourceFormat)")
            debugLog("   Target engine: \(engine)")
            
            switch engine {
            case .whisper:
                // Whisper path - Keep Float32, no conversion needed!
                // Just return the contents of the CAF file
                debugLog("🚀 Optimized path: Whisper (read Float32 CAF file directly)")
                return try Data(contentsOf: sourceURL)
                
            case .appleSpeech:
                // Convert Float32 to Int16 CAF file
                debugLog("🔄 Converting Float32 → Int16 for Apple Speech Recognition")
                
                let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("apple_speech.caf")
                try? FileManager.default.removeItem(at: targetURL)
                
                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: sourceFormat.sampleRate,
                    channels: sourceFormat.channelCount,
                    interleaved: false
                ) else {
                    debugLog("❌ Failed to create Int16 target format")
                    return Data()
                }
                
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: sourceFormat.sampleRate,
                    AVNumberOfChannelsKey: sourceFormat.channelCount,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                
                let targetFile = try AVAudioFile(
                    forWriting: targetURL,
                    settings: settings,
                    commonFormat: .pcmFormatInt16,
                    interleaved: false
                )
                
                guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                    debugLog("❌ Failed to create audio converter")
                    return Data()
                }
                
                let bufferSize: AVAudioFrameCount = 32768
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: bufferSize),
                      let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: bufferSize) else {
                    debugLog("❌ Failed to allocate conversion buffers")
                    return Data()
                }
                
                while srcFile.framePosition < totalFrames {
                    let framesToRead = min(bufferSize, AVAudioFrameCount(totalFrames - srcFile.framePosition))
                    inputBuffer.frameLength = 0
                    try srcFile.read(into: inputBuffer, frameCount: framesToRead)
                    
                    var inputConsumed = false
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        if inputConsumed {
                            outStatus.pointee = .noDataNow
                            return nil
                        }
                        inputConsumed = true
                        outStatus.pointee = .haveData
                        return inputBuffer
                    }
                    
                    outputBuffer.frameLength = 0
                    var error: NSError?
                    let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                    
                    if status == .error {
                        debugLog("❌ Conversion failed: \(error?.localizedDescription ?? "unknown")")
                        return Data()
                    }
                    
                    try targetFile.write(from: outputBuffer)
                }
                
                debugLog("✓ Apple Speech CAF conversion complete")
                let data = try Data(contentsOf: targetURL)
                try? FileManager.default.removeItem(at: targetURL)
                return data
                
            case .cloud:
                // Convert to 16kHz mono Int16 WAV (RIFF)
                debugLog("☁️ Converting to WAV (RIFF) for cloud upload")
                
                let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_upload.wav")
                try? FileManager.default.removeItem(at: targetURL)
                
                let cloudSampleRate: Double = 16000
                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: cloudSampleRate,
                    channels: 1,
                    interleaved: true
                ) else {
                    debugLog("❌ Failed to create cloud target format")
                    return Data()
                }
                
                let targetFile = try AVAudioFile(
                    forWriting: targetURL,
                    settings: targetFormat.settings,
                    commonFormat: .pcmFormatInt16,
                    interleaved: true
                )
                
                guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                    debugLog("❌ Failed to create audio converter for cloud")
                    return Data()
                }
                
                let bufferSize: AVAudioFrameCount = 32768
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: bufferSize) else {
                    debugLog("❌ Failed to allocate input buffer")
                    return Data()
                }
                
                while srcFile.framePosition < totalFrames {
                    let framesToRead = min(bufferSize, AVAudioFrameCount(totalFrames - srcFile.framePosition))
                    inputBuffer.frameLength = 0
                    try srcFile.read(into: inputBuffer, frameCount: framesToRead)
                    
                    let outputFrameCapacity = AVAudioFrameCount(ceil(Double(inputBuffer.frameLength) * cloudSampleRate / sourceFormat.sampleRate)) + 100
                    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                        debugLog("❌ Failed to allocate cloud output buffer")
                        return Data()
                    }
                    
                    var inputConsumed = false
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        if inputConsumed {
                            outStatus.pointee = .endOfStream
                            return nil
                        }
                        inputConsumed = true
                        outStatus.pointee = .haveData
                        return inputBuffer
                    }
                    
                    var convError: NSError?
                    let convStatus = converter.convert(to: outputBuffer, error: &convError, withInputFrom: inputBlock)
                    if convStatus == .error {
                        debugLog("❌ Cloud audio conversion failed: \(convError?.localizedDescription ?? "unknown")")
                        return Data()
                    }
                    
                    try targetFile.write(from: outputBuffer)
                }
                
                debugLog("✓ WAV file created")
                let data = try Data(contentsOf: targetURL)
                try? FileManager.default.removeItem(at: targetURL)
                return data
            }
        } catch {
            debugLog("❌ Failed to convert audio file: \(error.localizedDescription)")
            return Data()
        }
    }
}
