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

let wLog = OSLog(subsystem: "com.echotune.EchoTune", category: "whisper")

/// Run an async closure with a timeout. If the closure doesn't finish in time, returns normally (doesn't cancel the work).
private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T? {
    try await withThrowingTaskGroup(of: T?.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        // Return whichever finishes first
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct WhisperTranscriptionResult {
    let outputText: String
    let originalText: String
    let translatedText: String?
    let detectedLanguage: String?

    var wasTranslated: Bool {
        translatedText != nil
    }
}

class WhisperEngine: ObservableObject {
    static let shared = WhisperEngine()

    enum WhisperError: LocalizedError {
        case modelNotLoaded
        case modelLoadFailed(Error)
        case transcriptionFailed(Error)
        case audioFormatError
        case noAudioData
        case modelNotFound

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "The transcription model isn't loaded yet."
            case .modelLoadFailed(let underlying):
                return underlying.localizedDescription
            case .transcriptionFailed(let underlying):
                return underlying.localizedDescription
            case .audioFormatError:
                return "The recorded audio format couldn't be processed."
            case .noAudioData:
                return "No audio was captured."
            case .modelNotFound:
                return "This model's files couldn't be found on disk."
            }
        }
    }

    // MARK: - Stored Properties

    // Whisper instance
    private var whisperKit: WhisperKit?
    private var whisperKitTemp: WhisperKit?  // Temporary holder during init (download vs local path split)

    // Status properties
    @Published var isAvailable = false
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var currentText = ""
    @Published var loadedModelName: String?

    // Loading progress (0.0 to 1.0) for UI feedback during model initialization
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStage: String = ""

    // Current model info
    private var currentModelID: String?

    private let audioProcessingQueue = DispatchQueue(label: "com.echotune.whisperProcessing", qos: .userInitiated)
    private var pendingLoadCompletions: [(Result<Void, WhisperError>) -> Void] = []

    // Streaming state (stored properties must remain in main class file)
    var audioBuffers: [AVAudioPCMBuffer] = []
    var streamingTask: Task<Void, Never>?

    // Live transcription state
    var liveTranscriptionTimer: Timer?
    var liveTranscriptAccumulated: String = ""
    var lastLiveTranscribedBufferCount: Int = 0
    var isLiveTranscribing: Bool = false

    // MARK: - Internal Accessors for Extensions

    /// Provides read-only access to the WhisperKit instance for extension files.
    var whisperKitRef: WhisperKit? {
        whisperKit
    }

    /// Provides access to the audio processing queue for extension files.
    var audioProcessingQueueRef: DispatchQueue {
        audioProcessingQueue
    }

    // MARK: - Initialization

    private init() {
        debugLog("🎙️ WhisperEngine initialized")
    }

    // MARK: - Model Loading

    func loadModel(_ model: AIModel, completion: @escaping (Result<Void, WhisperError>) -> Void) {
        // If Apple Speech, no need to load Whisper model
        if model.isBuiltIn {
            debugLog("ℹ️ Using Apple Speech - no Whisper model needed")
            isAvailable = false
            loadedModelName = model.name
            currentModelID = model.id
            completion(.success(()))
            return
        }

        guard let resolvedModelFolder = ModelManager.shared.resolvedInstalledModelPath(for: model) else {
            debugLog("❌ Whisper model files not found for: \(model.name)")
            completion(.failure(.modelNotFound))
            return
        }

        // Don't reload if already loaded
        if currentModelID == model.id && whisperKit != nil {
            debugLog("ℹ️ Model \(model.name) already loaded")
            completion(.success(()))
            return
        }

        // Guard against concurrent loads — enqueue completion for when current load finishes
        guard !isLoading else {
            debugLog("⚠️ Model is already loading, enqueueing completion for \(model.name)")
            pendingLoadCompletions.append(completion)
            return
        }

        isLoading = true
        loadedModelName = nil
        loadingProgress = 0.0
        loadingStage = "Preparing..."

        debugLog("📦 Loading Whisper model: \(model.name) (\(model.id))")

        Task {
            do {
                // ✅ PHASE 3: Metal GPU Acceleration + Neural Engine
                // Configure optimal compute units for maximum performance
                await MainActor.run {
                    self.loadingProgress = 0.05
                    self.loadingStage = "Setting up..."
                }
                debugLog("⚡ Configuring Metal GPU acceleration...")

                let computeOptions = ModelComputeOptions(
                    melCompute: .cpuAndGPU,              // GPU-accelerated mel-spectrogram (fastest)
                    audioEncoderCompute: .all,           // Use all compute units (CPU + GPU + Neural Engine)
                    textDecoderCompute: .all,            // Use all compute units for decoding
                    prefillCompute: .cpuAndGPU           // GPU-accelerated cache prefilling (vs .cpuOnly default)
                )

                debugLog("   Mel-spectrogram: GPU accelerated")
                debugLog("   Audio Encoder: All compute units (CPU + GPU + Neural Engine)")
                debugLog("   Text Decoder: All compute units (CPU + GPU + Neural Engine)")
                debugLog("   Cache Prefill: GPU accelerated")

                await MainActor.run {
                    self.loadingProgress = 0.1
                    self.loadingStage = "Preparing model directory..."
                }

                // Use Application Support to avoid Documents permission popup.
                // WhisperKit will download to: ~/Library/Application Support/EchoTune/WhisperModels/huggingface/...
                let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let whisperBaseDir = appSupportDir.appendingPathComponent("EchoTune/WhisperModels", isDirectory: true)

                // Ensure directory exists
                try? FileManager.default.createDirectory(at: whisperBaseDir, withIntermediateDirectories: true)

                let modelFolderPath = resolvedModelFolder.path

                let modelExists = FileManager.default.fileExists(atPath: modelFolderPath)
                debugLog("📂 Model folder: \(modelFolderPath)")
                debugLog("   Exists: \(modelExists)")

                await MainActor.run {
                    self.loadingProgress = 0.3
                    self.loadingStage = modelExists ? "Loading model files..." : "Downloading model..."
                }

                // Load WhisperKit with Metal optimization and model prewarming
                // Note: WhisperKit initialization includes CoreML compilation which takes time for large models

                if !modelExists {
                    // Model needs to download first — show download progress
                    await MainActor.run {
                        self.loadingProgress = 0.15
                        self.loadingStage = "Downloading model — this may take a few minutes..."
                    }

                    // Download with progress tracking before initializing WhisperKit
                    let downloadedModelURL = try await WhisperKit.download(variant: model.id, downloadBase: whisperBaseDir) { progress in
                        let fraction = progress.fractionCompleted
                        Task { @MainActor in
                            // Map download progress to 0.15 → 0.55 range
                            self.loadingProgress = 0.15 + (fraction * 0.40)
                            let pct = Int(fraction * 100)
                            if pct < 100 {
                                self.loadingStage = "Downloading model... \(pct)%"
                            } else {
                                self.loadingStage = "Download complete!"
                            }
                        }
                    }

                    await MainActor.run {
                        self.loadingProgress = 0.55
                        self.loadingStage = "Loading AI engine..."
                    }

                    let whisper = try await WhisperKit(
                        model: model.id,
                        downloadBase: whisperBaseDir,
                        modelFolder: downloadedModelURL.path,
                        computeOptions: computeOptions,
                        verbose: true,
                        logLevel: .debug,
                        prewarm: false,
                        load: true,
                        download: false  // Already downloaded
                    )

                    await MainActor.run {
                        self.loadingProgress = 0.75
                        self.loadingStage = "Compiling model for your Mac — first time only..."
                    }

                    self.whisperKitTemp = whisper
                } else {
                    await MainActor.run {
                        self.loadingProgress = 0.3
                        self.loadingStage = "Loading model files..."
                    }

                    let whisper = try await WhisperKit(
                        model: model.id,
                        downloadBase: whisperBaseDir,
                        modelFolder: modelFolderPath,
                        computeOptions: computeOptions,
                        verbose: true,
                        logLevel: .debug,
                        prewarm: false,
                        load: true,
                        download: false
                    )

                    await MainActor.run {
                        self.loadingProgress = 0.75
                        self.loadingStage = "Compiling model for your Mac..."
                    }

                    self.whisperKitTemp = whisper
                }

                let whisper = self.whisperKitTemp!
                self.whisperKitTemp = nil

                // Treat the model as ready as soon as WhisperKit finishes loading.
                // Blocking on prewarm here made onboarding/demo feel broken and could stall for minutes.
                await MainActor.run {
                    self.loadingProgress = 1.0
                    self.loadingStage = "Ready!"

                    self.whisperKit = whisper
                    self.currentModelID = model.id
                    self.loadedModelName = model.name
                    self.isAvailable = true
                    self.isLoading = false

                    debugLog("✅ Whisper model loaded with Metal acceleration: \(model.name)")
                    debugLog("⚡ Skipping blocking prewarm so onboarding can continue immediately")
                    completion(.success(()))

                    // Drain pending completions
                    let pending = self.pendingLoadCompletions
                    self.pendingLoadCompletions.removeAll()
                    for cb in pending { cb(.success(())) }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isAvailable = false
                    self.loadingProgress = 0.0
                    self.loadingStage = "Failed"

                    debugLog("❌ Failed to load Whisper model: \(error)")
                    completion(.failure(.modelLoadFailed(error)))

                    // Drain pending completions
                    let pending = self.pendingLoadCompletions
                    self.pendingLoadCompletions.removeAll()
                    for cb in pending { cb(.failure(.modelLoadFailed(error))) }
                }
            }
        }
    }

    // MARK: - Audio Transcription

    func transcribeAudio(_ audioData: Data, completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) {
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

        debugLog("🎯 Starting Whisper transcription (direct buffer mode)...")
        debugLog("   Audio data size: \(audioData.count) bytes")

        // Start performance monitoring
        PerformanceMonitor.shared.startAudioConversion(dataSize: audioData.count)

        Task {
            do {
                // ✅ OPTIMIZED: Direct buffer transcription - no temp file I/O!
                // Convert audio data directly to Float array for WhisperKit
                let audioBuffer = try convertAudioDataToBuffer(audioData)

                PerformanceMonitor.shared.endAudioConversion()

                debugLog("✅ Converted to audio buffer: \(audioBuffer.frameLength) frames")
                debugLog("🎙️ Transcribing directly from buffer (no file I/O)...")

                // Convert buffer to Float array
                let audioArray = try convertBufferToFloatArray(audioBuffer)

                PerformanceMonitor.shared.startTranscription(
                    engine: "Whisper",
                    model: loadedModelName ?? "unknown"
                )

                // Transcribe directly from audio array (no file I/O!)
                let transcriptionResult = try await self.transcribeWithCurrentSettings(audioArray: audioArray, whisperKit: whisperKit)
                debugLog("📝 WhisperKit detected language: \(transcriptionResult.detectedLanguage ?? "unknown") translated: \(transcriptionResult.wasTranslated)")

                await MainActor.run {
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: transcriptionResult.outputText.split(separator: " ").count
                    )

                    self.currentText = transcriptionResult.outputText
                    self.isProcessing = false
                    debugLog("✅ Whisper transcription: \(transcriptionResult.outputText)")
                    completion(.success(transcriptionResult))
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false

                    debugLog("❌ Whisper transcription failed: \(error)")
                    completion(.failure(.transcriptionFailed(error)))
                }
            }
        }
    }

    // MARK: - Cleanup

    func unloadModel() {
        whisperKit = nil
        currentModelID = nil
        loadedModelName = nil
        isAvailable = false
        audioBuffers = []
        liveTranscriptionTimer?.invalidate()
        liveTranscriptionTimer = nil
        liveTranscriptAccumulated = ""
        lastLiveTranscribedBufferCount = 0
        isLiveTranscribing = false

        debugLog("🗑️ Whisper model unloaded")
    }
}
