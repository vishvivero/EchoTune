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

    func convertBufferToWAVData(_ buffer: AVAudioPCMBuffer, forEngine engine: AudioEngine = .appleSpeech) -> Data {
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
                // OPTIMIZED: Whisper path - Keep Float32, no conversion needed!
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
}
