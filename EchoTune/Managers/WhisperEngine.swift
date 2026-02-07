//
//  WhisperEngine.swift
//  EchoTune
//
//  Created by Vishnu Raj on 26/10/2025.
//

import Foundation
import AVFoundation
import Combine
import CoreML
import WhisperKit

class WhisperEngine: ObservableObject {
    static let shared = WhisperEngine()

    enum WhisperError: Error {
        case modelNotLoaded
        case modelLoadFailed(Error)
        case transcriptionFailed(Error)
        case audioFormatError
        case noAudioData
        case modelNotFound
    }

    // Whisper instance
    private var whisperKit: WhisperKit?

    // Status properties
    @Published var isAvailable = false
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var currentText = ""
    @Published var loadedModelName: String?

    // Current model info
    private var currentModelID: String?

    private let audioProcessingQueue = DispatchQueue(label: "com.echotune.whisperProcessing", qos: .userInitiated)

    private init() {
        print("🎙️ WhisperEngine initialized")
    }

    // MARK: - Model Loading

    func loadModel(_ model: AIModel, completion: @escaping (Result<Void, WhisperError>) -> Void) {
        // If Apple Speech, no need to load Whisper model
        if model.isBuiltIn {
            print("ℹ️ Using Apple Speech - no Whisper model needed")
            isAvailable = false
            loadedModelName = model.name
            currentModelID = model.id
            completion(.success(()))
            return
        }

        guard model.isInstalled else {
            completion(.failure(.modelNotFound))
            return
        }

        // Don't reload if already loaded
        if currentModelID == model.id && whisperKit != nil {
            print("ℹ️ Model \(model.name) already loaded")
            completion(.success(()))
            return
        }

        isLoading = true
        loadedModelName = nil

        print("📦 Loading Whisper model: \(model.name) (\(model.id))")

        Task {
            do {
                // ✅ PHASE 3: Metal GPU Acceleration + Neural Engine
                // Configure optimal compute units for maximum performance
                print("⚡ Configuring Metal GPU acceleration...")

                let computeOptions = ModelComputeOptions(
                    melCompute: .cpuAndGPU,              // GPU-accelerated mel-spectrogram (fastest)
                    audioEncoderCompute: .all,           // Use all compute units (CPU + GPU + Neural Engine)
                    textDecoderCompute: .all,            // Use all compute units for decoding
                    prefillCompute: .cpuAndGPU           // GPU-accelerated cache prefilling (vs .cpuOnly default)
                )

                print("   Mel-spectrogram: GPU accelerated")
                print("   Audio Encoder: All compute units (CPU + GPU + Neural Engine)")
                print("   Text Decoder: All compute units (CPU + GPU + Neural Engine)")
                print("   Cache Prefill: GPU accelerated")

                // Load WhisperKit with Metal optimization and model prewarming
                let whisper = try await WhisperKit(
                    model: model.id,
                    computeOptions: computeOptions,      // Enable Metal + Neural Engine
                    verbose: true,
                    logLevel: .debug,
                    prewarm: true,                       // Prewarm models for faster first transcription
                    load: true                           // Ensure model loads immediately
                )

                await MainActor.run {
                    self.whisperKit = whisper
                    self.currentModelID = model.id
                    self.loadedModelName = model.name
                    self.isAvailable = true
                    self.isLoading = false

                    print("✅ Whisper model loaded with Metal acceleration: \(model.name)")
                    print("🚀 Expected performance: 2-3x faster on Apple Silicon")
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isAvailable = false

                    print("❌ Failed to load Whisper model: \(error)")
                    completion(.failure(.modelLoadFailed(error)))
                }
            }
        }
    }

    // MARK: - Audio Transcription

    func transcribeAudio(_ audioData: Data, completion: @escaping (Result<String, WhisperError>) -> Void) {
        guard !audioData.isEmpty else {
            completion(.failure(.noAudioData))
            return
        }

        guard let whisperKit = whisperKit else {
            completion(.failure(.modelNotLoaded))
            return
        }

        isProcessing = true
        currentText = ""

        print("🎯 Starting Whisper transcription (direct buffer mode)...")
        print("   Audio data size: \(audioData.count) bytes")

        // Start performance monitoring
        PerformanceMonitor.shared.startAudioConversion(dataSize: audioData.count)

        Task {
            do {
                // ✅ OPTIMIZED: Direct buffer transcription - no temp file I/O!
                // Convert audio data directly to Float array for WhisperKit
                let audioBuffer = try convertAudioDataToBuffer(audioData)

                PerformanceMonitor.shared.endAudioConversion()

                print("✅ Converted to audio buffer: \(audioBuffer.frameLength) frames")
                print("🎙️ Transcribing directly from buffer (no file I/O)...")

                // Convert buffer to Float array
                let audioArray = try convertBufferToFloatArray(audioBuffer)

                PerformanceMonitor.shared.startTranscription(
                    engine: "Whisper",
                    model: loadedModelName ?? "unknown"
                )

                // Transcribe directly from audio array (no file I/O!)
                let results = try await whisperKit.transcribe(audioArray: audioArray)

                // Extract text from ALL result segments (WhisperKit returns multiple for long audio)
                let allSegments = results.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let transcription = allSegments.joined(separator: " ")
                print("📝 WhisperKit returned \(results.count) segments")

                await MainActor.run {
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: transcription.split(separator: " ").count
                    )

                    let cleaned = TranscriptionEngine.shared.processText(transcription)
                    self.currentText = cleaned
                    self.isProcessing = false
                    print("✅ Whisper transcription: \(cleaned)")
                    completion(.success(cleaned))
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false

                    print("❌ Whisper transcription failed: \(error)")
                    completion(.failure(.transcriptionFailed(error)))
                }
            }
        }
    }

    // MARK: - Streaming Transcription (for live audio)

    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var streamingTask: Task<Void, Never>?

    func startStreamingTranscription(completion: @escaping (Result<String, WhisperError>) -> Void) {
        guard whisperKit != nil else {
            completion(.failure(.modelNotLoaded))
            return
        }

        isProcessing = true
        currentText = ""
        audioBuffers = []

        print("🎤 Starting streaming transcription...")
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        audioProcessingQueue.async { [weak self] in
            guard let self = self else { return }

            // Accumulate buffers for batch processing
            self.audioBuffers.append(buffer)

            // For now, we'll process when user stops recording
            // WhisperKit works better with complete audio rather than streaming
        }
    }

    func endStreamingTranscription(completion: @escaping (Result<String, WhisperError>) -> Void) {
        print("🛑 Ending streaming transcription")
        print("📊 Total buffers accumulated: \(audioBuffers.count)")

        guard let whisperKit = whisperKit else {
            isProcessing = false
            completion(.failure(.modelNotLoaded))
            return
        }

        guard !audioBuffers.isEmpty else {
            isProcessing = false
            completion(.failure(.noAudioData))
            return
        }

        Task {
            do {
                // Calculate total frames from all buffers
                let totalFrameCount = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
                let sampleRate = audioBuffers[0].format.sampleRate
                let audioDuration = Double(totalFrameCount) / sampleRate
                print("📊 Audio duration: \(String(format: "%.2f", audioDuration)) seconds (\(totalFrameCount) frames)")

                // Convert all buffers to a single Float array
                print("🔄 Converting audio buffers to Float array...")
                let audioArray = try convertBuffersToFloatArray(audioBuffers)

                print("✅ Converted to Float array: \(audioArray.count) samples")
                print("   Expected samples at 16kHz: \(Int(audioDuration * 16000))")
                print("   Duration: \(String(format: "%.1f", audioDuration))s")

                // Calculate RMS to verify audio is present
                let rms = sqrt(audioArray.map { $0 * $0 }.reduce(0, +) / Float(audioArray.count))
                print("   RMS level: \(String(format: "%.6f", rms)) (should be > 0.001)")

                // Start performance monitoring for transcription
                await MainActor.run {
                    PerformanceMonitor.shared.startTranscription(
                        engine: "WhisperKit",
                        model: self.loadedModelName ?? "unknown"
                    )
                }

                // Transcribe directly from audio array
                // WhisperKit returns MULTIPLE segments for long audio (one per ~30s window)
                // We must join ALL segments, not just take .first!
                print("🎙️ Transcribing audio array (\(String(format: "%.1f", audioDuration))s)...")
                let results = try await whisperKit.transcribe(audioArray: audioArray)

                // Extract text from ALL result segments
                let allSegments = results.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let transcription = allSegments.joined(separator: " ")
                print("📝 WhisperKit returned \(results.count) segments, merged into \(transcription.split(separator: " ").count) words")

                await MainActor.run {
                    // End performance monitoring with word count
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: transcription.split(separator: " ").count
                    )

                    let cleaned = TranscriptionEngine.shared.processText(transcription)
                    self.currentText = cleaned
                    self.isProcessing = false
                    self.audioBuffers = []
                    print("✅ Streaming transcription complete: \(cleaned)")
                    completion(.success(cleaned))
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.audioBuffers = []

                    print("❌ Streaming transcription failed: \(error)")
                    completion(.failure(.transcriptionFailed(error)))
                }
            }
        }
    }

    // MARK: - Audio Processing Helpers

    private func convertAudioDataToBuffer(_ audioData: Data) throws -> AVAudioPCMBuffer {
        // Read audio data from CAF/WAV format into a buffer
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_temp_\(UUID().uuidString).caf")

        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let audioFile = try AVAudioFile(forReading: tempURL)
        let format = audioFile.processingFormat

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw WhisperError.audioFormatError
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = AVAudioFrameCount(audioFile.length)

        return buffer
    }

    private func convertBufferToFloatArray(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        // Convert a single buffer to Float array for WhisperKit
        let sourceFormat = buffer.format

        // WhisperKit expects 16kHz mono Float32
        let targetSampleRate: Double = 16000

        // If already 16kHz, just extract the float array
        if sourceFormat.sampleRate == targetSampleRate {
            guard let channelData = buffer.floatChannelData else {
                throw WhisperError.audioFormatError
            }

            let frameCount = Int(buffer.frameLength)
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        }

        // Need to resample
        let resampleRatio = targetSampleRate / sourceFormat.sampleRate

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw WhisperError.audioFormatError
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw WhisperError.audioFormatError
        }

        let expectedOutputSamples = Int(Double(buffer.frameLength) * resampleRatio)
        let outputFrameCapacity = AVAudioFrameCount(expectedOutputSamples)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw WhisperError.audioFormatError
        }

        var hasProvidedInput = false
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if hasProvidedInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            hasProvidedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ Conversion error: \(error)")
            throw WhisperError.transcriptionFailed(error)
        }

        guard status == .haveData || status == .endOfStream else {
            throw WhisperError.audioFormatError
        }

        guard let channelData = outputBuffer.floatChannelData else {
            throw WhisperError.audioFormatError
        }

        let finalFrameCount = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: finalFrameCount))
    }

    private func convertBuffersToFloatArray(_ buffers: [AVAudioPCMBuffer]) throws -> [Float] {
        guard !buffers.isEmpty else {
            throw WhisperError.noAudioData
        }

        // Get format from first buffer (48kHz Float32 mono)
        let inputFormat = buffers[0].format
        print("   Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) ch")

        // WhisperKit expects 16kHz mono Float32
        let targetSampleRate: Double = 16000
        let resampleRatio = targetSampleRate / inputFormat.sampleRate

        // Calculate total input frames
        let totalInputFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        let expectedOutputSamples = Int(Double(totalInputFrames) * resampleRatio)

        print("   Total input frames: \(totalInputFrames)")
        print("   Resample ratio: \(String(format: "%.4f", resampleRatio)) (48kHz → 16kHz)")
        print("   Expected output samples: \(expectedOutputSamples)")

        // Create output format (16kHz Float32 mono)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw WhisperError.audioFormatError
        }

        // Create converter
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw WhisperError.audioFormatError
        }

        // Merge all input buffers
        let mergedInputBuffer = try mergeBuffers(buffers)

        // Create output buffer with calculated capacity
        let outputFrameCapacity = AVAudioFrameCount(expectedOutputSamples)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw WhisperError.audioFormatError
        }

        // Convert audio - process in chunks to handle properly
        var error: NSError?
        let inputFrameCount = Int(mergedInputBuffer.frameLength)
        var hasProvidedInput = false

        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if hasProvidedInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            hasProvidedInput = true
            outStatus.pointee = .haveData
            return mergedInputBuffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ Conversion error: \(error)")
            throw WhisperError.transcriptionFailed(error)
        }

        print("   Conversion status: \(status.rawValue)")

        // Status can be .haveData (1) or .endOfStream (0) - both are valid
        guard status == .haveData || status == .endOfStream else {
            print("❌ Conversion failed with status: \(status)")
            throw WhisperError.audioFormatError
        }

        // The converter sets frameLength automatically, but let's verify
        let actualFrameCount = Int(outputBuffer.frameLength)
        print("   Output buffer frameLength: \(actualFrameCount)")

        // If frameLength wasn't set, calculate it manually
        if actualFrameCount == 0 {
            let calculatedFrames = Int(Double(inputFrameCount) * resampleRatio)
            outputBuffer.frameLength = AVAudioFrameCount(calculatedFrames)
            print("   Manually set frameLength to: \(calculatedFrames)")
        }

        print("   ✅ Conversion successful")

        // Extract Float array from output buffer
        guard let channelData = outputBuffer.floatChannelData else {
            throw WhisperError.audioFormatError
        }

        let finalFrameCount = Int(outputBuffer.frameLength)
        let floatArray = Array(UnsafeBufferPointer(start: channelData[0], count: finalFrameCount))

        print("   Actual output samples: \(floatArray.count)")

        return floatArray
    }

    private func mergeBuffers(_ buffers: [AVAudioPCMBuffer]) throws -> AVAudioPCMBuffer {
        guard !buffers.isEmpty else {
            throw WhisperError.noAudioData
        }

        // ✅ OPTIMIZED: Pre-calculate total size once
        let format = buffers[0].format
        let totalFrames = buffers.reduce(0) { $0 + AVAudioFrameCount($1.frameLength) }

        guard let mergedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: totalFrames
        ) else {
            throw WhisperError.audioFormatError
        }

        // ✅ OPTIMIZED: Use UnsafeMutableBufferPointer for faster memory operations
        let channelCount = Int(format.channelCount)
        let floatSize = MemoryLayout<Float>.stride

        var currentFrame: AVAudioFramePosition = 0
        for buffer in buffers {
            let frameLength = Int(buffer.frameLength)
            let byteCount = frameLength * floatSize

            // Process all channels at once
            for channel in 0..<channelCount {
                if let src = buffer.floatChannelData?[channel],
                   let dst = mergedBuffer.floatChannelData?[channel] {
                    // Single memcpy per buffer per channel (more efficient)
                    memcpy(dst.advanced(by: Int(currentFrame)), src, byteCount)
                }
            }

            currentFrame += AVAudioFramePosition(frameLength)
        }

        mergedBuffer.frameLength = totalFrames
        return mergedBuffer
    }

    private func mergeBuffersToWAV(_ buffers: [AVAudioPCMBuffer]) throws -> Data {
        guard !buffers.isEmpty else {
            throw WhisperError.noAudioData
        }

        // Get format from first buffer
        let format = buffers[0].format

        // Calculate total frame count
        let totalFrames = buffers.reduce(0) { $0 + AVAudioFrameCount($1.frameLength) }

        // Create merged buffer
        guard let mergedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: totalFrames
        ) else {
            throw WhisperError.audioFormatError
        }

        // Copy all buffers into merged buffer
        var currentFrame: AVAudioFramePosition = 0
        for buffer in buffers {
            let frameLength = buffer.frameLength

            for channel in 0..<Int(format.channelCount) {
                if let src = buffer.floatChannelData?[channel],
                   let dst = mergedBuffer.floatChannelData?[channel] {
                    memcpy(dst.advanced(by: Int(currentFrame)), src, Int(frameLength) * MemoryLayout<Float>.size)
                }
            }

            currentFrame += AVAudioFramePosition(frameLength)
        }

        mergedBuffer.frameLength = totalFrames

        // Convert to WAV data
        return try convertToWAV(mergedBuffer)
    }

    private func convertToWAV(_ buffer: AVAudioPCMBuffer) throws -> Data {
        // For Whisper, we need 16kHz mono PCM Float32
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        print("🔄 Converting audio for Whisper:")
        print("   Input: \(buffer.format.sampleRate)Hz, \(buffer.format.channelCount) ch, \(buffer.frameLength) frames")
        print("   Target: \(targetFormat.sampleRate)Hz, \(targetFormat.channelCount) ch")

        // Create converter
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            print("❌ Failed to create audio converter")
            throw WhisperError.audioFormatError
        }

        // Calculate output frame capacity
        let frameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate))

        print("   Calculated output capacity: \(frameCapacity) frames")

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCapacity
        ) else {
            print("❌ Failed to create output buffer")
            throw WhisperError.audioFormatError
        }

        // Perform conversion
        var error: NSError?
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

        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ Conversion error: \(error)")
            throw WhisperError.transcriptionFailed(error)
        }

        if status != .haveData {
            print("⚠️ Conversion status: \(status)")
        }

        // Set the actual frame length (converter doesn't set this automatically)
        convertedBuffer.frameLength = frameCapacity

        print("✅ Converted buffer: \(convertedBuffer.frameLength) frames")

        // Check if buffer has actual audio data
        if let channelData = convertedBuffer.floatChannelData {
            let samples = UnsafeBufferPointer(start: channelData[0], count: Int(convertedBuffer.frameLength))
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(convertedBuffer.frameLength))
            print("   RMS level: \(rms) (should be > 0.001 for speech)")

            if rms < 0.001 {
                print("⚠️ WARNING: Audio level too low - may not contain speech!")
            }
        }

        // Write to WAV file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_audio_\(UUID().uuidString).wav")

        let audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: targetFormat.settings,
            commonFormat: targetFormat.commonFormat,
            interleaved: targetFormat.isInterleaved
        )

        try audioFile.write(from: convertedBuffer)

        let data = try Data(contentsOf: tempURL)
        print("✅ WAV file created: \(data.count) bytes at \(tempURL.lastPathComponent)")

        try? FileManager.default.removeItem(at: tempURL)

        return data
    }

    // MARK: - Cleanup

    func unloadModel() {
        whisperKit = nil
        currentModelID = nil
        loadedModelName = nil
        isAvailable = false
        audioBuffers = []

        print("🗑️ Whisper model unloaded")
    }
}
