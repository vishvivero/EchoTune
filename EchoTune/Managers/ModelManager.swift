//
//  ModelManager.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import Combine
import WhisperKit

class ModelManager: ObservableObject {
    static let shared = ModelManager()

    // MARK: - ModelError

    enum ModelError: Error {
        case downloadFailed
        case installationFailed
        case modelNotFound
        case invalidModel
    }

    // MARK: - Published Properties

    // Model status
    @Published var availableModels: [AIModel] = []
    @Published var installedModels: [AIModel] = []
    @Published var currentModel: AIModel?

    // Download status
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var currentDownloadModel: AIModel?

    // Storage info
    @Published var availableStorage: Int64 = 0
    @Published var usedStorage: Int64 = 0

    /// Fires once after `checkInstalledModels()` finishes on the background thread.
    /// Observers (e.g. AppCoordinator.preloadDefaultModel) can wait on this.
    @Published var isReady = false

    // MARK: - Internal / Private State

    private var cancellables = Set<AnyCancellable>()
    private var observations: [NSKeyValueObservation] = []
    private let modelsDirectory: URL
    let apiKeyPrefix = "apiKey:"

    // MARK: - Init

    init() {
        // Create models directory in Application Support
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupportDirectory.appendingPathComponent("EchoTune/Models", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Load available models
        loadAvailableModels()

        // Defer expensive operations to background thread for faster startup
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            // Check installed models
            self.checkInstalledModels()

            // Update storage info
            self.updateStorageInfo()

            // Signal readiness on main thread
            DispatchQueue.main.async {
                self.isReady = true
                NotificationCenter.default.post(name: NSNotification.Name("ModelManagerReady"), object: nil)
            }
        }

        // Observe API key changes to refresh cloud model availability
        NotificationCenter.default.addObserver(forName: NSNotification.Name("APIKeyChanged"), object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.global(qos: .utility).async {
                self.checkInstalledModels()
            }
        }
    }

    // MARK: - Installed Models Check

    private func checkInstalledModels() {
        // WhisperKit stores models in Application Support to avoid Documents permission popup:
        // ~/Library/Application Support/EchoTune/WhisperModels/huggingface/models/argmaxinc/whisperkit-coreml/
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let whisperKitModelsPath = appSupportDir
            .appendingPathComponent("EchoTune")
            .appendingPathComponent("WhisperModels")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")

        debugLog("🔍 Checking for installed models at:")
        debugLog("   WhisperKit path: \(whisperKitModelsPath.path)")

        // Accumulate results on background thread
        var foundInstalled: [AIModel] = []
        var installFlags: [(id: String, isInstalled: Bool, localPath: URL?)] = []

        for model in availableModels {
            if model.id == "apple-speech" {
                var m = model; m.isInstalled = true
                foundInstalled.append(m)
                installFlags.append((id: model.id, isInstalled: true, localPath: nil))
                debugLog("   ✅ Built-in model: \(model.name)")
                continue
            }

            if model.category == .cloud {
                let hasKey = isCloudEnabled(model)
                if hasKey {
                    var m = model; m.isInstalled = true
                    foundInstalled.append(m)
                    installFlags.append((id: model.id, isInstalled: true, localPath: nil))
                    debugLog("   ✅ Cloud model enabled: \(model.name)")
                } else {
                    debugLog("   ⚠️ Cloud model (no API key): \(model.name)")
                }
                continue
            }

            guard let whisperVariant = whisperVariant(for: model.id) else { continue }

            let whisperKitModelName: String
            if whisperVariant.hasPrefix("distil-") || whisperVariant.hasPrefix("openai_whisper-") {
                whisperKitModelName = whisperVariant
            } else {
                whisperKitModelName = "openai_whisper-\(whisperVariant)"
            }
            let whisperKitModelPath = whisperKitModelsPath.appendingPathComponent(whisperKitModelName)

            if FileManager.default.fileExists(atPath: whisperKitModelPath.path) {
                var m = model; m.isInstalled = true; m.localPath = whisperKitModelPath
                foundInstalled.append(m)
                installFlags.append((id: model.id, isInstalled: true, localPath: whisperKitModelPath))
                debugLog("   ✅ Found installed model: \(model.name) at \(whisperKitModelPath.lastPathComponent)")
            } else {
                debugLog("   ❌ Model not found: \(model.name) (looking for \(whisperKitModelName))")
            }
        }

        debugLog("📊 Total installed models: \(foundInstalled.count)")

        let savedDefaultID = UserDefaults.standard.string(forKey: "defaultModelID")
        debugLog("🔍 Saved default model ID: \(savedDefaultID ?? "none")")
        debugLog("   Installed model IDs: \(foundInstalled.map { $0.id })")

        let resolvedCurrent: AIModel?
        if let savedDefaultID = savedDefaultID,
           let savedModel = foundInstalled.first(where: { $0.id == savedDefaultID }) {
            resolvedCurrent = savedModel
            debugLog("✅ Restored default model: \(savedModel.name) (id: \(savedModel.id))")
        } else if let firstInstalled = foundInstalled.first {
            resolvedCurrent = firstInstalled
            debugLog("✅ Set default model (fallback): \(firstInstalled.name) (id: \(firstInstalled.id))")
        } else {
            resolvedCurrent = nil
        }

        // Marshal ALL @Published mutations to main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.installedModels = foundInstalled

            // Update availableModels install flags
            for flag in installFlags {
                if let index = self.availableModels.firstIndex(where: { $0.id == flag.id }) {
                    self.availableModels[index].isInstalled = flag.isInstalled
                    if let path = flag.localPath {
                        self.availableModels[index].localPath = path
                    }
                }
            }

            if let resolved = resolvedCurrent, self.currentModel == nil || self.currentModel?.id != resolved.id {
                self.currentModel = resolved
            }

            // Sync AppSettings for routing consistency
            // Only override AppSettings if no user preference is saved,
            // or if the preferred model is installed (avoid downgrading to a smaller model)
            let preferredModel = AppSettings.shared.defaultTranscriptionModel
            if let resolved = resolvedCurrent {
                let preferredIsInstalled = foundInstalled.contains(where: { $0.id == preferredModel })
                if !preferredIsInstalled {
                    // Preferred model not installed yet — use best available but trigger download
                    AppSettings.shared.defaultTranscriptionModel = resolved.id
                    debugLog("⚠️ Preferred model '\(preferredModel)' not installed, using '\(resolved.id)' temporarily")
                    
                    // Auto-download the preferred model if it's a local model
                    if let targetModel = self.availableModels.first(where: { $0.id == preferredModel }),
                       targetModel.category == .local {
                        debugLog("📥 Auto-downloading preferred default model: \(preferredModel)")
                        self.downloadModel(targetModel) { [weak self] result in
                            if case .success(let downloaded) = result {
                                DispatchQueue.main.async {
                                    debugLog("✅ Preferred model downloaded, setting as active: \(downloaded.id)")
                                    _ = self?.setCurrentModel(downloaded)
                                }
                            }
                        }
                    }
                }
                // If preferred IS installed, keep AppSettings as-is (don't override user choice)
            }
        }
    }

    // MARK: - Model Queries

    func getModels(for category: ModelCategory) -> [AIModel] {
        if category == .recommended {
            // For recommended category, show all models regardless of their usability
            return availableModels.filter { SystemSpecsAnalyzer.shared.isRecommendedModel($0) }
        }
        return availableModels.filter { displayedCategory(for: $0) == category }
    }

    // Compute where a model should be displayed based on current capabilities
    private func displayedCategory(for model: AIModel) -> ModelCategory {
        if isModelUsableNow(model) { return model.category }
        return .comingSoon
    }

    private func isModelUsableNow(_ model: AIModel) -> Bool {
        if model.isBuiltIn { return true }
        switch model.category {
        case .local:
            // Usable only if WhisperKit supports download for this variant
            return canDownload(model)
        case .cloud:
            // Mark as usable only when we implement the connector AND the API key is present
            return isCloudConnectorImplemented(for: model) && isCloudEnabled(model)
        case .recommended, .comingSoon:
            return false
        }
    }

    private func isCloudConnectorImplemented(for model: AIModel) -> Bool {
        switch model.id {
        case "groq-whisper-large-v3-turbo":
            return true  // GroqTranscriptionService is implemented
        case "deepgram-nova":
            return true  // DeepgramTranscriptionService is implemented
        default:
            return false
        }
    }

    // MARK: - Download

    func downloadModel(_ model: AIModel, progressHandler: ((Double) -> Void)? = nil, completion: @escaping (Result<AIModel, ModelError>) -> Void) {
        // Don't download built-in models
        guard !model.isBuiltIn else {
            completion(.success(model))
            return
        }

        // Only WhisperKit-supported variants can be downloaded
        guard let variant = whisperVariant(for: model.id) else {
            debugLog("❌ Download not supported for model: \(model.id)")
            completion(.failure(.invalidModel))
            return
        }

        guard !isDownloading else {
            completion(.failure(.downloadFailed))
            return
        }

        isDownloading = true
        currentDownloadModel = model
        downloadProgress = 0

        debugLog("📥 Starting download for \(model.name) (\(model.id))")

        // Use WhisperKit to download the model
        Task {
            do {
                // Use WhisperKit to download the model
                _ = try await WhisperKit.download(variant: variant) { progress in
                    DispatchQueue.main.async {
                        self.downloadProgress = progress.fractionCompleted
                        progressHandler?(progress.fractionCompleted)
                        debugLog("⏬ Download progress: \(Int(progress.fractionCompleted * 100))%")
                    }
                }

                await MainActor.run {
                    debugLog("✅ Model downloaded successfully: \(model.name)")

                    // Update installed models
                    var installedModel = model
                    installedModel.isInstalled = true
                    // Point to WhisperKit location in Application Support (no Documents permission needed)
                    let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let whisperRoot = appSupportDir
                        .appendingPathComponent("EchoTune")
                        .appendingPathComponent("WhisperModels")
                        .appendingPathComponent("huggingface")
                        .appendingPathComponent("models")
                        .appendingPathComponent("argmaxinc")
                        .appendingPathComponent("whisperkit-coreml")
                    // Handle model naming consistently
                    let modelFolderName: String
                    if variant.hasPrefix("distil-") || variant.hasPrefix("openai_whisper-") {
                        modelFolderName = variant
                    } else {
                        modelFolderName = "openai_whisper-\(variant)"
                    }
                    installedModel.localPath = whisperRoot.appendingPathComponent(modelFolderName)

                    // Update available models array
                    if let index = self.availableModels.firstIndex(where: { $0.id == model.id }) {
                        self.availableModels[index].isInstalled = true
                    }

                    // Add to installed models if not already there
                    if !self.installedModels.contains(where: { $0.id == model.id }) {
                        self.installedModels.append(installedModel)
                    }

                    // Set as current model if we don't have one
                    if self.currentModel == nil {
                        self.currentModel = installedModel
                    }

                    // Update storage info
                    self.updateStorageInfo()

                    self.isDownloading = false
                    self.currentDownloadModel = nil

                    completion(.success(installedModel))
                }
            } catch {
                await MainActor.run {
                    debugLog("❌ Download failed: \(error)")
                    self.isDownloading = false
                    self.currentDownloadModel = nil
                    completion(.failure(.downloadFailed))
                }
            }
        }
    }

    // MARK: - Helpers

    // Return WhisperKit variant id if supported, else nil
    private func whisperVariant(for id: String) -> String? {
        let supported: Set<String> = [
            "tiny.en", "tiny", "base.en", "base", "small.en", "small", "medium.en", "medium", "large-v3",
            // Turbo models (optimized/quantized)
            "openai_whisper-large-v3_turbo",
            "distil-whisper_distil-large-v3_turbo"
        ]
        return supported.contains(id) ? id : nil
    }

    // Public check for UI to enable/disable downloads
    func canDownload(_ model: AIModel) -> Bool {
        return whisperVariant(for: model.id) != nil
    }

    // MARK: - Delete

    func deleteModel(_ model: AIModel) -> Bool {
        // Don't allow deleting built-in models
        guard !model.isBuiltIn else {
            debugLog("❌ Cannot delete built-in model: \(model.name)")
            return false
        }

        // Don't allow deleting the current model
        guard currentModel?.id != model.id else {
            debugLog("❌ Cannot delete current model: \(model.name). Please select a different model first.")
            return false
        }

        guard model.isInstalled, let localPath = model.localPath else {
            debugLog("❌ Model not installed or no local path: \(model.name)")
            return false
        }

        do {
            try FileManager.default.removeItem(at: localPath)
            debugLog("✅ Deleted model file: \(localPath.path)")

            // Remove from installed models
            installedModels.removeAll { $0.id == model.id }

            // Update the available models array to mark as not installed
            if let index = availableModels.firstIndex(where: { $0.id == model.id }) {
                availableModels[index].isInstalled = false
            }

            // Update current model if needed (extra safety check)
            if currentModel?.id == model.id {
                currentModel = installedModels.first
                debugLog("⚠️ Current model was deleted, switching to: \(currentModel?.name ?? "none")")
            }

            // Update storage info
            updateStorageInfo()

            // Force UI refresh
            objectWillChange.send()

            debugLog("✅ Model deleted successfully: \(model.name)")
            return true
        } catch {
            debugLog("❌ Failed to delete model: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Current Model

    func setCurrentModel(_ model: AIModel) -> Bool {
        guard model.isInstalled else {
            return false
        }

        currentModel = model

        // Save to UserDefaults
        UserDefaults.standard.set(model.id, forKey: "defaultModelID")

        // Keep AppSettings.defaultTranscriptionModel in sync (used by TranscriptionEngine routing)
        AppSettings.shared.defaultTranscriptionModel = model.id
        debugLog("💾 Saved default model: \(model.name) (synced to AppSettings)")

        return true
    }

    func installedModel(withID id: String) -> AIModel? {
        installedModels.first(where: { $0.id == id })
    }

    func isInstalledAndUsable(_ model: AIModel) -> Bool {
        guard let installedModel = installedModel(withID: model.id) else {
            return false
        }

        if installedModel.isBuiltIn {
            return true
        }

        switch installedModel.category {
        case .local:
            return installedModel.localPath != nil
        case .cloud:
            return isCloudEnabled(installedModel)
        default:
            return false
        }
    }

    // MARK: - Storage

    private func updateStorageInfo() {
        do {
            let fileSystem = try FileManager.default.attributesOfFileSystem(forPath: modelsDirectory.path)

            if let freeSize = fileSystem[.systemFreeSize] as? Int64 {
                availableStorage = freeSize
            }

            // Calculate used storage by models
            usedStorage = 0
            for model in installedModels {
                if let localPath = model.localPath,
                   let attributes = try? FileManager.default.attributesOfItem(atPath: localPath.path),
                   let fileSize = attributes[.size] as? Int64 {
                    usedStorage += fileSize
                }
            }
        } catch {
            debugLog("Failed to get storage info: \(error.localizedDescription)")
        }
    }

    func getModelForType(_ type: ModelSize) -> AIModel? {
        // First check installed models
        if let model = installedModels.first(where: { $0.type == type }) {
            return model
        }

        // If not installed, return available model
        return availableModels.first(where: { $0.type == type })
    }

    func getTotalStorageUsedString() -> String {
        return ByteCountFormatter.string(fromByteCount: usedStorage, countStyle: .file)
    }
}
