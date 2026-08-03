//
//  ParakeetEngine.swift
//  EchoTune
//
//  Fast transcription engine using NVIDIA Parakeet TDT via FluidAudio CoreML.
//  Runs on Apple Neural Engine — ~120x realtime (1 min audio ≈ 0.5s on M4).
//  Loads in seconds (no CoreML compilation). 25 European languages.
//

import Foundation
import AppKit
import Combine
import os.log

#if canImport(FluidAudio)
import FluidAudio

@available(macOS 14.0, *)
class ParakeetEngine: ObservableObject {

    static let shared = ParakeetEngine()

    // MARK: - Published State (mirrors WhisperEngine pattern)
    @Published var isAvailable: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStage: String = ""
    @Published var currentModelID: String?
    @Published var loadedModelName: String?

    // MARK: - Internal State
    private var transcriber: FluidTranscriber?
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var isProcessing: Bool = false
    private var currentText: String = ""
    private let wLog = OSLog(subsystem: "com.echotune", category: "Parakeet")
    private var liveTranscriptionTimer: Timer?
    private var liveTranscriptAccumulated: String = ""
    private var lastLiveTranscribedBufferCount: Int = 0
    private var isLiveTranscribing: Bool = false
    private let processingQueue = DispatchQueue(label: "com.echotune.parakeet", qos: .userInitiated)

    private init() {
        os_log("🦜 ParakeetEngine initialized", log: wLog, type: .info)
    }

    // MARK: - Model Loading

    func loadModel(_ model: AIModel, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isLoading else {
            completion(.failure(ParakeetError.alreadyLoading))
            return
        }

        isLoading = true
        loadedModelName = nil
        loadingProgress = 0.0
        loadingStage = "Preparing Neural Engine..."

        os_log("🦜 Loading Parakeet model: %{public}@", log: wLog, type: .info, model.id)

        Task {
            do {
                await MainActor.run {
                    self.loadingProgress = 0.2
                    self.loadingStage = "Loading Parakeet TDT model..."
                }

                // FluidAudio handles model download + loading automatically
                // Model ID format: "FluidInference/parakeet-tdt-0.6b-v3-coreml"
                let modelIdentifier = model.id  // e.g. "parakeet-tdt-0.6b-v3" → mapped to HF repo

                // Map our model IDs to FluidAudio model identifiers
                let fluidModelID = mapToFluidModelID(model.id)

                await MainActor.run {
                    self.loadingProgress = 0.5
                    self.loadingStage = "Downloading model (if needed)..."
                }

                let transcriber = try await FluidTranscriber(model: fluidModelID)

                await MainActor.run {
                    self.loadingProgress = 0.8
                    self.loadingStage = "Warming Neural Engine..."
                }

                // Warm up with a tiny sample for first-inference latency reduction
                let dummyAudio = [Float](repeating: 0.0, count: 16000)  // 1s of silence
                _ = try? await transcriber.transcribe(audioArray: dummyAudio)

                await MainActor.run {
                    self.loadingProgress = 1.0
                    self.loadingStage = "Ready!"
                    self.transcriber = transcriber
                    self.currentModelID = model.id
                    self.loadedModelName = model.name
                    self.isAvailable = true
                    self.isLoading = false
                }

                completion(.success(()))
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    os_log("❌ Parakeet load failed: %{public}@", log: self.wLog, type: .error, error.localizedDescription)
                }
                completion(.failure(error))
            }
        }
    }

    func unloadModel() {
        transcriber = nil
        currentModelID = nil
        loadedModelName = nil
        isAvailable = false
        audioBuffers = []
        liveTranscriptionTimer?.invalidate()
        liveTranscriptionTimer = nil
        liveTranscriptAccumulated = ""
        lastLiveTranscribedBufferCount = 0
        isLiveTranscribing = false
        os_log("🗑️ Parakeet model unloaded", log: wLog, type: .info)
    }

    // MARK: - Transcription

    func transcribe(audioArray: [Float]) async throws -> WhisperTranscriptionResult {
        guard let transcriber = transcriber else {
            throw ParakeetError.modelNotLoaded
        }

        isProcessing = true
        defer { isProcessing = false }

        os_log("🦜 Transcribing %d samples with Parakeet", log: wLog, type: .info, audioArray.count)

        let startTime = Date()
        let text = try await transcriber.transcribe(audioArray: audioArray)
        let elapsed = Date().timeIntervalSince(startTime)
        let rtf = elapsed / (Double(audioArray.count) / 16000.0)

        os_log("✅ Parakeet transcription: %.2fs (%.2fx realtime)", log: wLog, type: .info, elapsed, rtf)

        // Parakeet doesn't provide language detection — assume the preferred language
        let language = AppSettings.shared.preferredLanguage.components(separatedBy: "-").first ?? "en"

        return WhisperTranscriptionResult(
            outputText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            originalText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            translatedText: nil,
            detectedLanguage: language
        )
    }

    // MARK: - Streaming Support

    func startStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        audioBuffers = []
        liveTranscriptAccumulated = ""
        lastLiveTranscribedBufferCount = 0
        startLiveTranscriptionTimer()
        completion(.success(WhisperTranscriptionResult(
            outputText: "",
            originalText: "",
            translatedText: nil,
            detectedLanguage: AppSettings.shared.preferredLanguage.components(separatedBy: "-").first
        )))
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        processingQueue.async { [weak self] in
            self?.audioBuffers.append(buffer)
        }
    }

    func stopStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        stopLiveTranscriptionTimer()
        completion(.success(WhisperTranscriptionResult(
            outputText: liveTranscriptAccumulated,
            originalText: liveTranscriptAccumulated,
            translatedText: nil,
            detectedLanguage: AppSettings.shared.preferredLanguage.components(separatedBy: "-").first
        )))
    }

    // MARK: - Private Helpers

    private func startLiveTranscriptionTimer() {
        stopLiveTranscriptionTimer()
        DispatchQueue.main.async { [weak self] in
            self?.liveTranscriptionTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                self?.processLiveTranscriptionChunk()
            }
        }
    }

    private func stopLiveTranscriptionTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.liveTranscriptionTimer?.invalidate()
            self?.liveTranscriptionTimer = nil
        }
    }

    private func processLiveTranscriptionChunk() {
        guard !isLiveTranscribing, let transcriber = transcriber else { return }

        let (buffersSnapshot, bufferCount): ([AVAudioPCMBuffer], Int) = processingQueue.sync {
            let count = self.audioBuffers.count
            guard count > self.lastLiveTranscribedBufferCount else { return ([], count) }
            return (Array(self.audioBuffers), count)
        }

        guard !buffersSnapshot.isEmpty, bufferCount > lastLiveTranscribedBufferCount else { return }

        isLiveTranscribing = true
        lastLiveTranscribedBufferCount = bufferCount

        Task {
            do {
                let audioArray = convertBuffersToFloatArray(buffersSnapshot)
                let result = try await transcribe(audioArray: audioArray)
                await MainActor.run {
                    if !result.outputText.isEmpty {
                        self.liveTranscriptAccumulated += result.outputText + " "
                    }
                    self.isLiveTranscribing = false
                }
            } catch {
                await MainActor.run {
                    self.isLiveTranscribing = false
                }
            }
        }
    }

    private func convertBuffersToFloatArray(_ buffers: [AVAudioPCMBuffer]) -> [Float] {
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        var result = [Float](repeating: 0, count: totalFrames)
        var offset = 0
        for buffer in buffers {
            if let ptr = buffer.floatChannelData?.pointee {
                let count = Int(buffer.frameLength)
                result.withUnsafeMutableBufferPointer { dest in
                    dest.baseAddress!.advanced(by: offset).update(from: ptr, count: count)
                }
                offset += count
            }
        }
        return result
    }

    /// Maps internal model IDs to FluidAudio HuggingFace identifiers.
    private func mapToFluidModelID(_ id: String) -> String {
        switch id {
        case "parakeet-tdt-0.6b-v3":
            return "FluidInference/parakeet-tdt-0.6b-v3-coreml"
        case "parakeet-tdt-0.6b-v2":
            return "FluidInference/parakeet-tdt-0.6b-v2-coreml"
        default:
            return "FluidInference/parakeet-tdt-0.6b-v3-coreml"
        }
    }
}

// MARK: - Errors

enum ParakeetError: LocalizedError {
    case modelNotLoaded
    case alreadyLoading

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Parakeet model is not loaded"
        case .alreadyLoading: return "A model is already loading"
        }
    }
}

#else

/// No-op stub when FluidAudio package is not linked.
/// Compiles cleanly so the rest of the app can reference ParakeetEngine without #if checks.
@available(macOS 14.0, *)
class ParakeetEngine: ObservableObject {
    static let shared = ParakeetEngine()
    @Published var isAvailable: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStage: String = "FluidAudio package not linked"
    @Published var currentModelID: String?
    @Published var loadedModelName: String?

    func loadModel(_ model: AIModel, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(ParakeetError.modelNotLoaded))
    }
    func unloadModel() {}
    func transcribe(audioArray: [Float]) async throws -> WhisperTranscriptionResult {
        throw ParakeetError.modelNotLoaded
    }
    func startStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        completion(.failure(ParakeetError.modelNotLoaded))
    }
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {}
    func stopStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        completion(.failure(ParakeetError.modelNotLoaded))
    }
}

enum ParakeetError: LocalizedError {
    case modelNotLoaded
    var errorDescription: String? { "Parakeet model is not loaded" }
}

#endif
