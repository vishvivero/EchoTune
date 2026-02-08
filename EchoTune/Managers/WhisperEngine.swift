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
import os.log

private let wLog = OSLog(subsystem: "com.echotune.EchoTune", category: "whisper")

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

        // Guard against concurrent loads
        guard !isLoading else {
            print("⚠️ Model is already loading, skipping duplicate request for \(model.name)")
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

                // Use the model's localPath if set by ModelManager (which knows the correct
                // folder naming convention, e.g., "base" → "openai_whisper-base").
                // Fall back to constructing the path from the model ID.
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let modelFolderPath: String
                if let localPath = model.localPath {
                    modelFolderPath = localPath.path
                } else {
                    // Construct path using WhisperKit naming convention
                    let folderName: String
                    if model.id.hasPrefix("distil-") || model.id.hasPrefix("openai_whisper-") {
                        folderName = model.id
                    } else {
                        folderName = "openai_whisper-\(model.id)"
                    }
                    modelFolderPath = documentsURL
                        .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
                        .appendingPathComponent(folderName)
                        .path
                }

                let modelExists = FileManager.default.fileExists(atPath: modelFolderPath)
                print("📂 Model folder: \(modelFolderPath)")
                print("   Exists: \(modelExists)")

                // Load WhisperKit with Metal optimization and model prewarming
                let whisper = try await WhisperKit(
                    model: model.id,
                    downloadBase: documentsURL,           // Explicit base so it finds local models
                    modelFolder: modelExists ? modelFolderPath : nil,  // Use local folder if available
                    computeOptions: computeOptions,       // Enable Metal + Neural Engine
                    verbose: true,
                    logLevel: .debug,
                    prewarm: true,                        // Prewarm models for faster first transcription
                    load: true,                           // Ensure model loads immediately
                    download: !modelExists                // Only download if not already local
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
        os_log("🎤 startStreamingTranscription, whisperKit=%{public}@, isAvailable=%d", log: wLog, type: .error, whisperKit == nil ? "nil" : "loaded", isAvailable ? 1 : 0)
        guard whisperKit != nil else {
            os_log("❌ whisperKit is nil — modelNotLoaded", log: wLog, type: .error)
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
        os_log("🛑 endStreamingTranscription: buffers=%d whisperKit=%{public}@", log: wLog, type: .error, audioBuffers.count, whisperKit == nil ? "nil" : "loaded")

        guard let whisperKit = whisperKit else {
            os_log("❌ whisperKit nil at endStreaming", log: wLog, type: .error)
            isProcessing = false
            completion(.failure(.modelNotLoaded))
            return
        }

        guard !audioBuffers.isEmpty else {
            os_log("❌ audioBuffers empty at endStreaming", log: wLog, type: .error)
            isProcessing = false
            completion(.failure(.noAudioData))
            return
        }

        // Capture buffers locally — they get cleared by appendAudioBuffer on background queue
        let buffersSnapshot = audioBuffers

        Task {
            do {
                os_log("🔄 Task started: processing %d buffers", log: wLog, type: .error, buffersSnapshot.count)

                // Calculate total frames from all buffers
                let totalFrameCount = buffersSnapshot.reduce(0) { $0 + Int($1.frameLength) }
                let sampleRate = buffersSnapshot[0].format.sampleRate
                let audioDuration = Double(totalFrameCount) / sampleRate
                os_log("📊 Audio: %.2fs (%d frames, %.0fHz)", log: wLog, type: .error, audioDuration, totalFrameCount, sampleRate)

                // Convert all buffers to a single Float array
                let audioArray = try self.convertBuffersToFloatArray(buffersSnapshot)
                os_log("✅ Converted to %d samples", log: wLog, type: .error, audioArray.count)

                // Calculate RMS to verify audio is present
                let rms = sqrt(audioArray.map { $0 * $0 }.reduce(0, +) / Float(max(audioArray.count, 1)))
                os_log("🔊 RMS=%.6f (need >0.001)", log: wLog, type: .error, rms)

                // Start performance monitoring for transcription
                await MainActor.run {
                    PerformanceMonitor.shared.startTranscription(
                        engine: "WhisperKit",
                        model: self.loadedModelName ?? "unknown"
                    )
                }

                // Transcribe directly from audio array
                os_log("🎙️ Calling whisperKit.transcribe(audioArray:)...", log: wLog, type: .error)
                let results = try await whisperKit.transcribe(audioArray: audioArray)
                os_log("✅ WhisperKit returned %d segments", log: wLog, type: .error, results.count)

                // Extract text from ALL result segments
                let allSegments = results.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let transcription = allSegments.joined(separator: " ")
                os_log("📝 Transcription: '%{public}@' (%d words)", log: wLog, type: .error, transcription, transcription.split(separator: " ").count)

                await MainActor.run {
                    // End performance monitoring with word count
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: transcription.split(separator: " ").count
                    )

                    let cleaned = TranscriptionEngine.shared.processText(transcription)
                    self.currentText = cleaned
                    self.isProcessing = false
                    self.audioBuffers = []
                    os_log("✅ Final cleaned: '%{public}@'", log: wLog, type: .error, cleaned)
                    completion(.success(cleaned))
                }
            } catch {
                os_log("❌ Transcription Task FAILED: %{public}@", log: wLog, type: .error, "\(error)")
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
        // Uses file-based resampling for reliability with any buffer size
        return try convertBuffersToFloatArray([buffer])
    }

    private func convertBuffersToFloatArray(_ buffers: [AVAudioPCMBuffer]) throws -> [Float] {
        guard !buffers.isEmpty else {
            throw WhisperError.noAudioData
        }

        let inputFormat = buffers[0].format
        let targetSampleRate: Double = 16000

        os_log("🔄 convertBuffers: %d buffers, format=%.0fHz %dch",
               log: wLog, type: .error, buffers.count, inputFormat.sampleRate, inputFormat.channelCount)

        // If already 16kHz mono, just extract float data directly
        if inputFormat.sampleRate == targetSampleRate && inputFormat.channelCount == 1 {
            var result: [Float] = []
            for buffer in buffers {
                guard let channelData = buffer.floatChannelData else {
                    throw WhisperError.audioFormatError
                }
                let frameCount = Int(buffer.frameLength)
                result.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameCount))
            }
            os_log("✅ Already 16kHz mono, %d samples", log: wLog, type: .error, result.count)
            return result
        }

        // STRATEGY: Merge all small buffers into one large buffer first,
        // then write to a temp file using AVAudioFile (which handles resampling).
        // This is more reliable than per-buffer AVAudioConverter which can produce 0 frames.

        // Step 1: Merge all input buffers into one contiguous buffer
        let totalInputFrames = buffers.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard totalInputFrames > 0 else { throw WhisperError.noAudioData }

        guard let mergedInput = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: totalInputFrames) else {
            throw WhisperError.audioFormatError
        }

        var writeOffset: AVAudioFrameCount = 0
        for buffer in buffers {
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { continue }
            for channel in 0..<Int(inputFormat.channelCount) {
                if let src = buffer.floatChannelData?[channel],
                   let dst = mergedInput.floatChannelData?[channel] {
                    memcpy(dst.advanced(by: Int(writeOffset)), src, frameCount * MemoryLayout<Float>.size)
                }
            }
            writeOffset += buffer.frameLength
        }
        mergedInput.frameLength = totalInputFrames

        os_log("📦 Merged %d buffers → %d frames (%.1fs at %.0fHz)",
               log: wLog, type: .error, buffers.count, totalInputFrames,
               Double(totalInputFrames) / inputFormat.sampleRate, inputFormat.sampleRate)

        // Step 2: Write merged buffer to temp WAV at source sample rate
        let tempInputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_input_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: tempInputURL) }

        let inputFile = try AVAudioFile(
            forWriting: tempInputURL,
            settings: inputFormat.settings,
            commonFormat: inputFormat.commonFormat,
            interleaved: inputFormat.isInterleaved
        )
        try inputFile.write(from: mergedInput)

        // Step 3: Read it back at 16kHz mono using AVAudioFile's automatic conversion
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        let readFile = try AVAudioFile(forReading: tempInputURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let outputFrameCount = AVAudioFrameCount(ceil(Double(readFile.length) * targetSampleRate / readFile.fileFormat.sampleRate))

        os_log("📖 Read file: %lld frames, output estimate: %d frames at 16kHz",
               log: wLog, type: .error, readFile.length, outputFrameCount)

        // AVAudioFile reads with processing format — set to 16kHz mono
        // We need to use AVAudioConverter for the actual resampling
        guard let converter = AVAudioConverter(from: readFile.processingFormat, to: targetFormat) else {
            throw WhisperError.audioFormatError
        }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount + 1000) else {
            throw WhisperError.audioFormatError
        }

        // Read all source audio into a single large buffer for conversion
        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: readFile.processingFormat,
            frameCapacity: AVAudioFrameCount(readFile.length)
        ) else {
            throw WhisperError.audioFormatError
        }
        try readFile.read(into: sourceBuffer)
        sourceBuffer.frameLength = AVAudioFrameCount(readFile.length)

        var inputConsumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        var convError: NSError?
        let status = converter.convert(to: outputBuffer, error: &convError, withInputFrom: inputBlock)

        os_log("🔧 Converter status=%d outFrames=%d err=%{public}@",
               log: wLog, type: .error, status.rawValue, outputBuffer.frameLength,
               convError?.localizedDescription ?? "none")

        // Fallback: if frameLength is 0 but status is haveData, estimate it
        if outputBuffer.frameLength == 0 && (status == .haveData || status == .inputRanDry) {
            outputBuffer.frameLength = outputFrameCount
            os_log("⚠️ frameLength was 0, set to estimated %d", log: wLog, type: .error, outputFrameCount)
        }

        guard outputBuffer.frameLength > 0, let channelData = outputBuffer.floatChannelData else {
            os_log("❌ Conversion produced 0 frames", log: wLog, type: .error)
            throw WhisperError.noAudioData
        }

        let floatArray = Array(UnsafeBufferPointer(start: channelData[0], count: Int(outputBuffer.frameLength)))

        // Verify audio content
        let rms = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(max(floatArray.count, 1)))
        os_log("✅ Converted: %d samples, RMS=%.6f", log: wLog, type: .error, floatArray.count, rms)

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
