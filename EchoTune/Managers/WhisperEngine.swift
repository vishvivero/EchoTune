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

    enum WhisperError: Error {
        case modelNotLoaded
        case modelLoadFailed(Error)
        case transcriptionFailed(Error)
        case audioFormatError
        case noAudioData
        case modelNotFound
    }

    // MARK: - Stored Properties

    // Whisper instance
    private var whisperKit: WhisperKit?

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

        guard model.isInstalled else {
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
                    self.loadingProgress = 0.1
                    self.loadingStage = "Configuring GPU acceleration..."
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
                    self.loadingProgress = 0.2
                    self.loadingStage = "Setting up model directory..."
                }

                // Use Application Support to avoid Documents permission popup.
                // WhisperKit will download to: ~/Library/Application Support/EchoTune/WhisperModels/huggingface/...
                let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let whisperBaseDir = appSupportDir.appendingPathComponent("EchoTune/WhisperModels", isDirectory: true)

                // Ensure directory exists
                try? FileManager.default.createDirectory(at: whisperBaseDir, withIntermediateDirectories: true)

                // Use the model's localPath if set by ModelManager (which knows the correct
                // folder naming convention, e.g., "base" → "openai_whisper-base").
                // Fall back to constructing the path from the model ID.
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
                    modelFolderPath = whisperBaseDir
                        .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
                        .appendingPathComponent(folderName)
                        .path
                }

                let modelExists = FileManager.default.fileExists(atPath: modelFolderPath)
                debugLog("📂 Model folder: \(modelFolderPath)")
                debugLog("   Exists: \(modelExists)")

                await MainActor.run {
                    self.loadingProgress = 0.3
                    self.loadingStage = modelExists ? "Loading model files..." : "Downloading model..."
                }

                // Load WhisperKit with Metal optimization and model prewarming
                // Note: WhisperKit initialization includes CoreML compilation which takes time for large models
                await MainActor.run {
                    self.loadingProgress = 0.4
                    self.loadingStage = "Initializing WhisperKit..."
                }

                let whisper = try await WhisperKit(
                    model: model.id,
                    downloadBase: whisperBaseDir,         // Use App Support (no Documents permission needed)
                    modelFolder: modelExists ? modelFolderPath : nil,  // Use local folder if available
                    computeOptions: computeOptions,       // Enable Metal + Neural Engine
                    verbose: true,
                    logLevel: .debug,
                    prewarm: false,                       // We'll prewarm separately for progress tracking
                    load: true,                           // Ensure model loads immediately
                    download: !modelExists                // Only download if not already local
                )

                await MainActor.run {
                    self.loadingProgress = 0.7
                    self.loadingStage = "Compiling CoreML models..."
                }

                // Prewarm the model for faster first transcription
                await MainActor.run {
                    self.loadingProgress = 0.85
                    self.loadingStage = "Warming up model..."
                }

                // Prewarm decoder for faster first inference
                try? await whisper.prewarmModels()

                await MainActor.run {
                    self.loadingProgress = 1.0
                    self.loadingStage = "Ready!"

                    self.whisperKit = whisper
                    self.currentModelID = model.id
                    self.loadedModelName = model.name
                    self.isAvailable = true
                    self.isLoading = false

                    debugLog("✅ Whisper model loaded with Metal acceleration: \(model.name)")
                    debugLog("🚀 Expected performance: 2-3x faster on Apple Silicon")
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

        debugLog("🗑️ Whisper model unloaded")
    }
}
