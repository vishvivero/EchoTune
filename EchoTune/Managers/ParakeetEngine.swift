//
//  ParakeetEngine.swift
//  EchoTune
//
//  Batch transcription with FluidAudio's CoreML Parakeet TDT models.
//

import Foundation
import AVFoundation
import Combine
import FluidAudio
import os.log

@available(macOS 14.0, *)
final class ParakeetEngine: ObservableObject {
    static let shared = ParakeetEngine()

    @Published var isAvailable = false
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStage: String = ""
    @Published var currentModelID: String?
    @Published var loadedModelName: String?

    private let wLog = OSLog(subsystem: "com.echotune", category: "Parakeet")
    private var asrManager: AsrManager?
    private var loadedVersion: AsrModelVersion?
    private var loadTask: Task<Void, Never>?
    private var pendingCompletions: [String: [(Result<Void, Error>) -> Void]] = [:]

    private init() {
        os_log("🦜 ParakeetEngine initialized", log: wLog, type: .info)
    }

    enum ModelVersion: String {
        case v2 = "parakeet-tdt-0.6b-v2"
        case v3 = "parakeet-tdt-0.6b-v3"

        var fluidVersion: AsrModelVersion {
            switch self {
            case .v2: return .v2
            case .v3: return .v3
            }
        }
    }

    static func version(for modelID: String) -> ModelVersion? {
        ModelVersion(rawValue: modelID)
    }

    static func isModelInstalled(for modelID: String) -> Bool {
        guard let version = version(for: modelID) else { return false }
        return AsrModels.modelsExist(
            at: AsrModels.defaultCacheDirectory(for: version.fluidVersion),
            version: version.fluidVersion
        )
    }

    /// Downloads and loads a model. FluidAudio owns the cache and model files.
    /// Concurrent requests for the same model share one load operation.
    func loadModel(_ model: AIModel, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let version = Self.version(for: model.id) else {
            completion(.failure(ParakeetError.unsupportedModel(model.id)))
            return
        }

        if currentModelID == model.id, isAvailable, asrManager != nil {
            completion(.success(()))
            return
        }

        pendingCompletions[model.id, default: []].append(completion)
        if loadTask != nil {
            // A different model cannot safely replace an active actor-backed load.
            // Its completion is resolved when the current load finishes, then the
            // caller can retry; same-model callers share the result above.
            return
        }

        isLoading = true
        loadingProgress = 0
        loadingStage = "Preparing Parakeet…"
        let modelID = model.id

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let models = try await AsrModels.downloadAndLoad(
                    version: version.fluidVersion,
                    progressHandler: { [weak self] progress in
                        Task { @MainActor in
                            self?.loadingProgress = progress.fractionCompleted
                            switch progress.phase {
                            case .listing:
                                self?.loadingStage = "Finding Parakeet model…"
                            case .downloading:
                                self?.loadingStage = "Downloading Parakeet model…"
                            case .compiling(let name):
                                self?.loadingStage = "Loading \(name)…"
                            @unknown default:
                                self?.loadingStage = "Preparing Parakeet…"
                            }
                        }
                    }
                )
                let manager = AsrManager(config: .default, models: models)
                guard await manager.isAvailable else {
                    throw ParakeetError.modelLoadFailed("FluidAudio returned an unavailable model")
                }
                self.asrManager = manager
                self.loadedVersion = version.fluidVersion
                await MainActor.run {
                    self.currentModelID = modelID
                    self.loadedModelName = model.name
                    self.isAvailable = true
                    self.isLoading = false
                    self.loadingProgress = 1
                    self.loadingStage = "Ready"
                }
                self.resolve(modelID, result: .success(()))
            } catch {
                await MainActor.run {
                    self.isAvailable = false
                    self.isLoading = false
                    self.loadingStage = "Parakeet unavailable — Whisper fallback"
                }
                self.resolve(modelID, result: .failure(error))
            }
            self.loadTask = nil
        }
        loadTask = task
    }

    /// Async preparation API used by model-management UI and tests.
    func prepareModel(_ model: AIModel) async throws {
        try await withCheckedThrowingContinuation { continuation in
            loadModel(model) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func resolve(_ modelID: String, result: Result<Void, Error>) {
        let completions = pendingCompletions.removeValue(forKey: modelID) ?? []
        completions.forEach { $0(result) }
        // Requests for another model must not hang indefinitely.
        let otherIDs = pendingCompletions.keys.filter { $0 != modelID }
        for otherID in otherIDs {
            let waiting = pendingCompletions.removeValue(forKey: otherID) ?? []
            waiting.forEach { $0(.failure(ParakeetError.loadSuperseded)) }
        }
    }

    func unloadModel() {
        loadTask?.cancel()
        loadTask = nil
        asrManager = nil
        loadedVersion = nil
        currentModelID = nil
        loadedModelName = nil
        isAvailable = false
    }

    /// Transcribes 16 kHz mono Float32 samples. FluidAudio handles long audio
    /// through its streaming-threshold/disk-backed batch path.
    func transcribe(audioArray: [Float]) async throws -> WhisperTranscriptionResult {
        guard let manager = asrManager, let loadedVersion else {
            throw ParakeetError.modelNotLoaded
        }
        guard !audioArray.isEmpty else { throw ParakeetError.noAudioData }

        var decoderState = TdtDecoderState.make(
            decoderLayers: loadedVersion.decoderLayers
        )
        let result = try await manager.transcribe(audioArray, decoderState: &decoderState)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return WhisperTranscriptionResult(
            outputText: text,
            originalText: text,
            translatedText: nil,
            detectedLanguage: "en"
        )
    }

    /// Reads the Float32 CAF emitted by AudioManager and normalizes it to the
    /// 16 kHz mono sample format required by FluidAudio.
    func transcribe(audioData: Data) async throws -> WhisperTranscriptionResult {
        guard !audioData.isEmpty else { throw ParakeetError.noAudioData }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("parakeet-input-\(UUID().uuidString).caf")
        try audioData.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw ParakeetError.audioFormatError
        }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(max(1, ceil(Double(file.length) * ratio)))
        guard let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw ParakeetError.audioFormatError
        }
        try file.read(into: input)
        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, conversionError == nil,
              let samples = output.floatChannelData?[0] else {
            throw ParakeetError.audioFormatError
        }
        return try await transcribe(audioArray: Array(UnsafeBufferPointer(start: samples, count: Int(output.frameLength))))
    }

    // Parakeet is intentionally batch-only in Phase 5. These methods retain
    // the old UI-facing API and fail explicitly rather than silently decoding
    // with the wrong engine.
    func startStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        completion(.failure(ParakeetError.batchOnly))
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {}

    func stopStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        completion(.failure(ParakeetError.batchOnly))
    }
}

enum ParakeetError: LocalizedError {
    case modelNotLoaded
    case noAudioData
    case audioFormatError
    case unsupportedModel(String)
    case modelLoadFailed(String)
    case loadSuperseded
    case batchOnly

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "The Parakeet model is not loaded."
        case .noAudioData: return "No audio was captured."
        case .audioFormatError: return "The recorded audio could not be converted for Parakeet."
        case .unsupportedModel(let id): return "Unsupported Parakeet model: \(id)"
        case .modelLoadFailed(let reason): return "Parakeet model failed to load: \(reason)"
        case .loadSuperseded: return "The requested Parakeet load was superseded; please retry."
        case .batchOnly: return "Parakeet batch transcription does not support live streaming."
        }
    }
}
