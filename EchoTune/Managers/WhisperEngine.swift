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
    /// Already-decoded committed segments, available the instant streaming
    /// ends (before the final tail decode completes). Used for immediate
    /// streaming insertion at stop.
    var committedPrefix: String? = nil
    /// Word-level confidence from WhisperKit when timestamp alignment is
    /// enabled. Nil means the decoder returned text without word timings.
    var agreementWords: [AgreementWord]? = nil

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
    // Completions are keyed by the requested model. A request for model B
    // arriving while model A loads must never receive A's success result.
    private var pendingLoadCompletions: [String: [(Result<Void, WhisperError>) -> Void]] = [:]

    // Streaming state (stored properties must remain in main class file)
    var audioBuffers: [AVAudioPCMBuffer] = []
    /// The currently running live tick. Stop cancellation awaits this task
    /// before snapshotting the tail so a tick cannot race final decoding.
    var currentTickTask: Task<Void, Never>?
    /// The stop/finalization task. A new recording cancels it and advances the
    /// session token so an old completion cannot touch the new session.
    var streamingTask: Task<Void, Never>?
    var streamingSessionID = UUID()
    var streamingSessionStartedAt: Date?

    // Live transcription state
    var liveTimerSource: DispatchSourceTimer?
    let liveTimerQueue = DispatchQueue(label: "com.echotune.whisper.liveTimer", qos: .utility)
    var liveTranscriptAccumulated: String = ""
    var lastLiveTranscribedBufferCount: Int = 0
    var isLiveTranscribing: Bool = false
    /// Committed text from each completed preview tick (source of truth for final result)
    var liveSegmentTranscripts: [String] = []
    /// Cumulative word candidates assembled from completed ticks. Keeping the
    /// candidate stream cumulative lets AgreementEngine compare the same
    /// positional frontier across successive delta decodes.
    var liveAgreementWords: [AgreementWord] = []
    /// Last rolling-window text used to extract only newly arrived words for
    /// the final segment cache.
    var liveWindowTranscript = ""
    var liveWindowAgreementWords: [AgreementWord] = []
    var agreementEngine = AgreementEngine()

    /// VAD failures must never drop speech or flood the log on every tick.
    var didLogVADDecodeFailure = false

    /// Language detected on the first decode of the current dictation session.
    /// Live ticks reuse it instead of running a fresh detection pass on every
    /// 4s tick (Phase 2). Reset at the start of every session — see
    /// `resetSessionLanguage()`. Settable internally so the pin transitions
    /// are unit-testable without a loaded model.
    var sessionDetectedLanguage: String?

    /// Clears the session language pin. Every dictation — live or batch —
    /// calls this before decoding, because a new dictation is a new session.
    func resetSessionLanguage() {
        sessionDetectedLanguage = nil
    }

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
            pendingLoadCompletions[model.id, default: []].append(completion)
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
                    audioEncoderCompute: .cpuAndGPU,     // GPU encoder — avoids 2-min ANE specialization on every load
                    textDecoderCompute: .cpuAndGPU,      // GPU decoder — as fast or faster than ANE on M2+ (WhisperKit benchmarks)
                    prefillCompute: .cpuAndGPU           // GPU-accelerated cache prefilling (vs .cpuOnly default)
                )

                debugLog("   Mel-spectrogram: GPU accelerated")
                debugLog("   Audio Encoder: CPU + GPU (ANE specialization skipped for fast load)")
                debugLog("   Text Decoder: CPU + GPU (ANE specialization skipped for fast load)")
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

                // Phase 3: use the compiled CoreML models bundled with the app, but
                // only when they provably match the model we're about to load.
                //
                // WhisperKit loads <modelFolder>/<Name>.mlmodelc directly
                // (ModelUtilities.detectModelURL), so the bundles go at the top
                // level of the model folder — not a "compiled/" subdir. They are
                // symlinked because a .mlmodelc is a directory bundle and macOS
                // forbids hard-linking directories (the previous linkItem always
                // failed silently).
                switch CompiledModelBundleCheck.validate(
                    modelId: model.id,
                    bundleResourceURL: Bundle.main.resourceURL
                ) {
                case .success(let compiledDir):
                    let linkStart = CFAbsoluteTimeGetCurrent()
                    var linked = 0
                    if let entries = try? FileManager.default.contentsOfDirectory(atPath: compiledDir.path) {
                        for entry in entries where entry.hasSuffix(".mlmodelc") {
                            let src = compiledDir.appendingPathComponent(entry)
                            let dst = URL(fileURLWithPath: modelFolderPath).appendingPathComponent(entry)
                            // Never clobber a bundle the downloader already produced.
                            guard !FileManager.default.fileExists(atPath: dst.path) else { continue }
                            try? FileManager.default.createSymbolicLink(at: dst, withDestinationURL: src)
                            linked += 1
                        }
                    }
                    let linkMS = Int((CFAbsoluteTimeGetCurrent() - linkStart) * 1000)
                    debugLog("⚡ Compiled models verified — linked \(linked) bundles into the model folder (\(linkMS) ms)")
                case .failure(let reason):
                    debugLog("ℹ️ Not using bundled compiled models: \(reason) — CoreML will compile on load")
                }

                await MainActor.run {
                    self.loadingProgress = 0.3
                    self.loadingStage = modelExists ? "Loading model files..." : "Downloading model..."
                }

                // HEARTBEAT: WhisperKit's model load has no progress API (4 sequential
                // CoreML loads; the ~1GB AudioEncoder dominates — ~40-60s on first load
                // while CoreML compiles + caches). Without this, the UI freezes at 30%
                // for the whole load and users think it's hung.
                // Asymptotic creep 0.30 → 0.74: honest (never claims done early), keeps
                // moving, and the real jump to 1.0 happens only on actual completion.
                let loadHeartbeat = Task { [weak self] in
                    var elapsed: Double = 0
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 250_000_000) // 250ms
                        elapsed += 0.25
                        await MainActor.run {
                            guard let self, self.isLoading else { return }
                            // While a download is driving progress (its own 0.15→0.55 map),
                            // the heartbeat stays hands-off. It only creeps during the
                            // CoreML load phase, which has no progress API.
                            if self.loadingStage.hasPrefix("Downloading") { return }
                            let creep = 0.44 * (1 - exp(-elapsed / 30))
                            self.loadingProgress = min(0.74, max(self.loadingProgress, 0.30 + creep))
                            let secs = Int(elapsed)
                            if secs >= 10 && secs % 10 == 0 {
                                self.loadingStage = "Loading AI engine… \(secs)s (first load is the slowest)"
                            }
                        }
                    }
                }
                // deferred cancel so the heartbeat stops however the load ends
                defer { loadHeartbeat.cancel() }

                // Load WhisperKit with Metal optimization and model prewarming
                // Note: WhisperKit initialization includes CoreML compilation which takes time for large models

                if !modelExists {
                    // Model needs to download first — show download progress
                    await MainActor.run {
                        self.loadingProgress = 0.15
                        self.loadingStage = "Downloading model — this may take a few minutes..."
                    }

                    // ModelManager owns staging, resumable Hub downloads,
                    // integrity validation, and archive-on-replace. Keep this
                    // load path on the same transaction as Settings downloads.
                    let downloadedModel = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AIModel, Error>) in
                        ModelManager.shared.downloadModel(model, progressHandler: { fraction in
                            Task { @MainActor in
                                self.loadingProgress = 0.15 + (fraction * 0.40)
                                let pct = Int(fraction * 100)
                                if pct < 100 {
                                    self.loadingStage = "Downloading model... \(pct)% · \(ModelManager.shared.downloadProgressSummary)"
                                } else {
                                    self.loadingStage = "Download complete!"
                                }
                            }
                        }) { result in
                            switch result {
                            case .success(let installed):
                                continuation.resume(returning: installed)
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                    guard let downloadedModelURL = downloadedModel.localPath else {
                        throw WhisperError.modelNotFound
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

                    // Drain only waiters for the model that actually loaded.
                    // Other model requests are rejected and can retry explicitly.
                    let pending = self.pendingLoadCompletions.removeValue(forKey: model.id) ?? []
                    for cb in pending { cb(.success(())) }
                    let superseded = self.pendingLoadCompletions
                    self.pendingLoadCompletions.removeAll()
                    for callbacks in superseded.values {
                        for cb in callbacks { cb(.failure(.modelNotLoaded)) }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isAvailable = false
                    self.loadingProgress = 0.0
                    self.loadingStage = "Failed"

                    debugLog("❌ Failed to load Whisper model: \(error)")
                    completion(.failure(.modelLoadFailed(error)))

                    let pending = self.pendingLoadCompletions.removeValue(forKey: model.id) ?? []
                    for cb in pending { cb(.failure(.modelLoadFailed(error))) }
                    let superseded = self.pendingLoadCompletions
                    self.pendingLoadCompletions.removeAll()
                    for callbacks in superseded.values {
                        for cb in callbacks { cb(.failure(.modelNotLoaded)) }
                    }
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
        streamingSessionStartedAt = Date()
        currentText = ""

        // A new batch dictation is a new session: drop any language pinned by
        // a previous session so detection starts from scratch.
        resetSessionLanguage()

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

                // Trim non-speech before the final decode. Separate speech
                // regions are decoded independently so a long pause does not
                // make Whisper run two sentences together. Silence-only input
                // is reported as no audio instead of reaching Whisper.
                guard let decodeSegments = await self.audioSegmentsForDecode(audioArray, context: "batch dictation") else {
                    throw WhisperError.noAudioData
                }

                var segmentResults: [WhisperTranscriptionResult] = []
                segmentResults.reserveCapacity(decodeSegments.count)
                for (index, decodeSegment) in decodeSegments.enumerated() {
                    let segmentResult = try await self.transcribeWithCurrentSettings(
                        audioArray: decodeSegment,
                        whisperKit: whisperKit,
                        detectLanguage: index == 0 ? nil : false,
                        mode: .final
                    )
                    segmentResults.append(segmentResult)
                }
                let transcriptionResult = self.mergeTranscriptionResults(segmentResults)
                debugLog("📝 WhisperKit detected language: \(transcriptionResult.detectedLanguage ?? "unknown") translated: \(transcriptionResult.wasTranslated) from \(segmentResults.count) speech segment(s)")

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
        currentTickTask?.cancel()
        streamingTask?.cancel()
        streamingSessionID = UUID()
        whisperKit = nil
        currentModelID = nil
        loadedModelName = nil
        isAvailable = false
        audioBuffers = []
        liveTimerSource?.cancel()
        liveTimerSource = nil
        liveTranscriptAccumulated = ""
        lastLiveTranscribedBufferCount = 0
        isLiveTranscribing = false
        liveSegmentTranscripts = []
        liveAgreementWords = []
        liveWindowTranscript = ""
        liveWindowAgreementWords = []
        agreementEngine.reset()
        didLogVADDecodeFailure = false

        debugLog("🗑️ Whisper model unloaded")
    }
}
