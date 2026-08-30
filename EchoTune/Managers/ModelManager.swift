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

    enum ModelError: LocalizedError {
        case downloadFailed
        case installationFailed
        case modelNotFound
        case invalidModel

        var errorDescription: String? {
            switch self {
            case .downloadFailed:
                return "The model download could not be completed. Please check your connection and try again."
            case .installationFailed:
                return "The model download finished, but its files were incomplete or corrupted. Please retry the download."
            case .modelNotFound:
                return "The selected model files could not be found. Please download the model again."
            case .invalidModel:
                return "This model is not supported or its files are incomplete."
            }
        }
    }

    private struct WhisperValidationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
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

        // Migrate model API keys to Keychain (one-time)
        migrateModelApiKeysToKeychain()

        // Defer expensive operations to background thread for faster startup
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Migrate models from ~/Documents/huggingface to Application Support (one-time)
            self.migrateModelsFromDocuments()

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

        AppSettings.shared.$defaultTranscriptionModel
            .removeDuplicates()
            .sink { [weak self] modelID in
                self?.syncCurrentModel(to: modelID)
            }
            .store(in: &cancellables)
    }

    // MARK: - Migration from Documents to Application Support

    /// One-time migration: move WhisperKit models from ~/Documents/huggingface
    /// to ~/Library/Application Support/EchoTune/WhisperModels/huggingface.
    /// This eliminates the Documents permission popup on macOS.
    private func migrateModelsFromDocuments() {
        let hasMigrated = UserDefaults.standard.bool(forKey: "hasCompletedWhisperModelMigration")
        guard !hasMigrated else { return }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldModelsRoot = documentsDir
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")

        guard FileManager.default.fileExists(atPath: oldModelsRoot.path) else {
            debugLog("ℹ️ No legacy models in Documents — nothing to migrate")
            UserDefaults.standard.set(true, forKey: "hasCompletedWhisperModelMigration")
            return
        }

        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let newModelsRoot = appSupportDir
            .appendingPathComponent("EchoTune")
            .appendingPathComponent("WhisperModels")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")

        do {
            try FileManager.default.createDirectory(at: newModelsRoot, withIntermediateDirectories: true)

            let contents = try FileManager.default.contentsOfDirectory(atPath: oldModelsRoot.path)
            for modelFolder in contents {
                let source = oldModelsRoot.appendingPathComponent(modelFolder)
                let dest = newModelsRoot.appendingPathComponent(modelFolder)

                if FileManager.default.fileExists(atPath: dest.path) {
                    debugLog("   ℹ️ Model already exists at destination: \(modelFolder)")
                    continue
                }

                try FileManager.default.moveItem(at: source, to: dest)
                debugLog("   ✅ Migrated model: \(modelFolder)")
            }

            // Clean up empty Documents/huggingface tree
            try? FileManager.default.removeItem(at: documentsDir.appendingPathComponent("huggingface"))
            debugLog("✅ Model migration from Documents complete")
        } catch {
            debugLog("⚠️ Model migration failed: \(error) — models will be re-downloaded to Application Support")
        }

        UserDefaults.standard.set(true, forKey: "hasCompletedWhisperModelMigration")
    }

    private func migrateModelApiKeysToKeychain() {
        let migrationKey = "hasCompletedModelApiKeysMigration"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        for model in availableModels {
            let defaultsKey = apiKeyPrefix + model.id
            if let oldKey = UserDefaults.standard.string(forKey: defaultsKey), !oldKey.isEmpty {
                KeychainHelper.save(oldKey, forKey: defaultsKey)
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Installed Models Check

    private func checkInstalledModels() {
        debugLog("🔍 Checking for installed models in WhisperKit storage")

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

            let whisperKitModelName = preferredInstalledFolderName(for: whisperVariant)

            if let resolvedPath = resolveInstalledModelPath(folderName: whisperKitModelName) {
                var m = model; m.isInstalled = true; m.localPath = resolvedPath
                foundInstalled.append(m)
                installFlags.append((id: model.id, isInstalled: true, localPath: resolvedPath))
                debugLog("   ✅ Found installed model: \(model.name) at \(resolvedPath.path)")
            } else {
                debugLog("   ❌ Model not found: \(model.name) (looking for \(whisperKitModelName))")
            }
        }

        debugLog("📊 Total installed models: \(foundInstalled.count)")

        let preferredModelID = AppSettings.shared.defaultTranscriptionModel
        let savedDefaultID = UserDefaults.standard.string(forKey: "defaultTranscriptionModel")
        debugLog("🔍 Saved default model ID: \(savedDefaultID ?? "none")")
        debugLog("🔍 Preferred model ID: \(preferredModelID)")
        debugLog("   Installed model IDs: \(foundInstalled.map { $0.id })")

        let resolvedCurrent: AIModel?
        if let preferredModel = foundInstalled.first(where: { $0.id == preferredModelID }) {
            resolvedCurrent = preferredModel
            debugLog("✅ Restored preferred model: \(preferredModel.name) (id: \(preferredModel.id))")
        } else if let savedDefaultID = savedDefaultID,
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
                UserDefaults.standard.set(resolved.id, forKey: "defaultTranscriptionModel")
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
                // Download to Application Support (not Documents) to avoid permission popups
                let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let whisperDownloadBase = appSupportDir
                    .appendingPathComponent("EchoTune")
                    .appendingPathComponent("WhisperModels")

                let modelFolderName = self.preferredInstalledFolderName(for: model.id)
                let downloadVariant = self.preferredDownloadVariant(for: model.id)

                self.clearExistingModelArtifacts(folderNames: [modelFolderName, downloadVariant], whisperDownloadBase: whisperDownloadBase)

                let downloadedPath = try await self.downloadAndValidateModel(
                    variant: downloadVariant,
                    expectedFolderName: modelFolderName,
                    whisperDownloadBase: whisperDownloadBase,
                    progressHandler: progressHandler
                )

                guard let installedPath = self.normalizeInstalledModelDirectory(from: downloadedPath) else {
                    debugLog("❌ Download completed but model files were not usable at: \(downloadedPath.path)")
                    throw WhisperValidationError(message: "Downloaded model files were incomplete.")
                }

                await MainActor.run {
                    debugLog("✅ Model downloaded successfully: \(model.name)")

                    var installedModel = model
                    installedModel.isInstalled = true
                    installedModel.localPath = installedPath

                    if let index = self.availableModels.firstIndex(where: { $0.id == model.id }) {
                        self.availableModels[index].isInstalled = true
                        self.availableModels[index].localPath = installedPath
                    }

                    if let existingIndex = self.installedModels.firstIndex(where: { $0.id == model.id }) {
                        self.installedModels[existingIndex] = installedModel
                    } else {
                        self.installedModels.append(installedModel)
                    }

                    if self.currentModel == nil {
                        self.currentModel = installedModel
                    }

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
                    if error is WhisperValidationError {
                        debugLog("⚠️ Model installation rejected: incomplete or corrupted model files")
                    }
                    completion(.failure(.installationFailed))
                }
            }
        }
    }

    // MARK: - Helpers

    private func preferredInstalledFolderName(for modelID: String) -> String {
        switch modelID {
        case "distil-whisper_distil-large-v3":
            return "distil-whisper_distil-large-v3_594MB"
        case "openai_whisper-large-v3-v20240930_turbo", "openai_whisper-large-v3-v20240930_turbo_632MB":
            return "openai_whisper-large-v3-v20240930_turbo_632MB"
        case "openai_whisper-small.en", "openai_whisper-small.en_244MB":
            return "openai_whisper-small.en"
        case "distil-whisper_distil-large-v3_turbo", "distil-whisper_distil-large-v3_turbo_600MB":
            return "distil-whisper_distil-large-v3_turbo_600MB"
        case "openai_whisper-large-v3-turbo", "openai_whisper-large-v3_turbo", "openai_whisper-large-v3_turbo_954MB":
            // The catalog id uses a hyphen ("large-v3-turbo"), but the real HuggingFace/WhisperKit
            // repo folder uses an underscore ("large-v3_turbo"). Without this mapping, downloads
            // fail with "No models found matching ...".
            return "openai_whisper-large-v3_turbo_954MB"
        default:
            if modelID.hasPrefix("distil-") || modelID.hasPrefix("openai_whisper-") {
                return modelID
            }
            return "openai_whisper-\(modelID)"
        }
    }

    private func preferredDownloadVariant(for modelID: String) -> String {
        switch modelID {
        case "distil-whisper_distil-large-v3":
            return "distil-whisper_distil-large-v3_594MB"
        case "openai_whisper-large-v3-v20240930_turbo", "openai_whisper-large-v3-v20240930_turbo_632MB":
            // CRITICAL: must target the _632MB folder explicitly. The bare variant
            // "openai_whisper-large-v3-v20240930_turbo" matches the 1.5GB fp16 folder
            // in the HF repo (glob "*turbo/*" doesn't match "..._turbo_632MB/*"), so
            // WhisperKit would download 2.4x the data into a folder our installer
            // doesn't recognize — the "slow 10-minute download" bug.
            return "openai_whisper-large-v3-v20240930_turbo_632MB"
        case "openai_whisper-small.en", "openai_whisper-small.en_244MB":
            return "openai_whisper-small.en"
        case "distil-whisper_distil-large-v3_turbo", "distil-whisper_distil-large-v3_turbo_600MB":
            return "distil-whisper_distil-large-v3_turbo_600MB"
        case "openai_whisper-large-v3-turbo", "openai_whisper-large-v3_turbo", "openai_whisper-large-v3_turbo_954MB":
            return "openai_whisper-large-v3_turbo_954MB"
        default:
            return whisperVariant(for: modelID) ?? modelID
        }
    }

    // Return WhisperKit variant id if supported, else nil
    private func resolveInstalledModelPath(folderName: String) -> URL? {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let whisperBase = appSupportDir
            .appendingPathComponent("EchoTune")
            .appendingPathComponent("WhisperModels")

        let candidates = [
            whisperBase
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(folderName),
            whisperBase
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(folderName)
        ]

        for candidate in candidates {
            if let normalized = normalizeInstalledModelDirectory(from: candidate) {
                return normalized
            }
        }

        let parentDirectories = Set(candidates.map { $0.deletingLastPathComponent() })
        for parent in parentDirectories {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: parent,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for entry in contents where entry.lastPathComponent == folderName || entry.lastPathComponent.hasPrefix(folderName + "_") {
                if let normalized = normalizeInstalledModelDirectory(from: entry) {
                    return normalized
                }
            }
        }

        return nil
    }

    func resolvedInstalledModelPath(for model: AIModel) -> URL? {
        guard let whisperVariant = whisperVariant(for: model.id) else {
            return nil
        }

        let candidateFolderName = preferredInstalledFolderName(for: whisperVariant)

        if let localPath = model.localPath,
           let normalized = normalizeInstalledModelDirectory(from: localPath) {
            return normalized
        }

        return resolveInstalledModelPath(folderName: candidateFolderName)
    }

    private func whisperVariant(for id: String) -> String? {
        let supported: Set<String> = [
            "tiny.en", "tiny", "base.en", "base", "small.en", "small", "medium.en", "medium", "large-v3",
            "openai_whisper-base",
            "distil-whisper_distil-large-v3",
            "openai_whisper-large-v3-turbo",
            "openai_whisper-large-v3-v20240930_turbo",
            "openai_whisper-small.en",
            "distil-whisper_distil-large-v3_turbo",
            "distil-whisper_distil-large-v3_turbo_600MB"
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

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Remove from installed models
                self.installedModels.removeAll { $0.id == model.id }

                // Update the available models array to mark as not installed
                if let index = self.availableModels.firstIndex(where: { $0.id == model.id }) {
                    self.availableModels[index].isInstalled = false
                }

                // Update current model if needed (extra safety check)
                if self.currentModel?.id == model.id {
                    self.currentModel = self.installedModels.first
                    debugLog("⚠️ Current model was deleted, switching to: \(self.currentModel?.name ?? "none")")
                }

                // Update storage info
                self.updateStorageInfo()

                // Force UI refresh
                self.objectWillChange.send()
            }

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

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentModel = model
            AppSettings.shared.defaultTranscriptionModel = model.id
        }

        // Save to UserDefaults
        UserDefaults.standard.set(model.id, forKey: "defaultTranscriptionModel")
        debugLog("💾 Saved default model: \(model.name) (synced to AppSettings)")

        return true
    }

    func installedModel(withID id: String) -> AIModel? {
        installedModels.first(where: { $0.id == id })
    }

    private func syncCurrentModel(to modelID: String) {
        let canonicalModelID = AppSettings.canonicalTranscriptionModelID(modelID)

        if canonicalModelID != modelID {
            DispatchQueue.main.async {
                AppSettings.shared.defaultTranscriptionModel = canonicalModelID
            }
            return
        }

        guard currentModel?.id != canonicalModelID else {
            return
        }

        if let installedModel = installedModels.first(where: { $0.id == canonicalModelID }) {
            DispatchQueue.main.async { [weak self] in
                self?.currentModel = installedModel
            }
            UserDefaults.standard.set(installedModel.id, forKey: "defaultTranscriptionModel")
            debugLog("🔄 Synced active model to settings default: \(installedModel.name)")
            return
        }

        if let cloudModel = availableModels.first(where: { $0.id == canonicalModelID && $0.category == .cloud && isCloudEnabled($0) }) {
            DispatchQueue.main.async { [weak self] in
                self?.currentModel = cloudModel
            }
            UserDefaults.standard.set(cloudModel.id, forKey: "defaultTranscriptionModel")
            debugLog("🔄 Synced active cloud model to settings default: \(cloudModel.name)")
        }
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
            guard let resolvedPath = resolvedInstalledModelPath(for: installedModel) else { return false }
            return normalizeInstalledModelDirectory(from: resolvedPath) != nil
        case .cloud:
            return isCloudEnabled(installedModel)
        default:
            return false
        }
    }

    private func normalizeInstalledModelDirectory(from candidate: URL) -> URL? {
        ModelArtifactValidator.normalizedDirectory(at: candidate)
    }

    /// Removes a local model's on-disk files and marks it not installed. Used when
    /// loading it failed in a way that suggests the downloaded files are corrupted
    /// or incomplete, so the UI can offer a clean re-download instead of retrying
    /// against permanently-broken files forever.
    func markModelCorruptedAndRemove(_ model: AIModel) {
        guard !model.isBuiltIn else { return }

        if let resolvedPath = resolvedInstalledModelPath(for: model) {
            try? FileManager.default.removeItem(at: resolvedPath)
            debugLog("🧹 Removed corrupted model files for \(model.name) at \(resolvedPath.path)")
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.installedModels.removeAll { $0.id == model.id }
            if let index = self.availableModels.firstIndex(where: { $0.id == model.id }) {
                self.availableModels[index].isInstalled = false
                self.availableModels[index].localPath = nil
            }
            if self.currentModel?.id == model.id {
                self.currentModel = self.installedModels.first
            }
        }
    }

    private func downloadAndValidateModel(
        variant: String,
        expectedFolderName: String,
        whisperDownloadBase: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        var lastError: Error?

        for attempt in 1...2 {
            do {
                let downloadedPath = try await WhisperKit.download(variant: variant, downloadBase: whisperDownloadBase) { progress in
                    DispatchQueue.main.async {
                        self.downloadProgress = progress.fractionCompleted
                        progressHandler?(progress.fractionCompleted)
                        debugLog("⏬ Download progress: \(Int(progress.fractionCompleted * 100))%")
                    }
                }

                if self.normalizeInstalledModelDirectory(from: downloadedPath) != nil {
                    return downloadedPath
                }

                debugLog("⚠️ Download attempt \(attempt) produced incomplete model files for \(expectedFolderName)")
                lastError = WhisperValidationError(message: "Downloaded model files were incomplete.")
            } catch {
                if let recoveredPath = self.resolveInstalledModelPath(folderName: expectedFolderName),
                   self.normalizeInstalledModelDirectory(from: recoveredPath) != nil {
                    debugLog("✅ Recovering usable model after download error for \(expectedFolderName): \(recoveredPath.path)")
                    return recoveredPath
                }

                lastError = error
                debugLog("⚠️ Download attempt \(attempt) failed for \(expectedFolderName): \(error)")
            }

            self.clearExistingModelArtifacts(folderNames: [expectedFolderName, variant], whisperDownloadBase: whisperDownloadBase)
        }

        if let recoveredPath = self.resolveInstalledModelPath(folderName: expectedFolderName),
           self.normalizeInstalledModelDirectory(from: recoveredPath) != nil {
            debugLog("✅ Recovering usable model after retries for \(expectedFolderName): \(recoveredPath.path)")
            return recoveredPath
        }

        throw lastError ?? WhisperValidationError(message: "Downloaded model files were incomplete.")
    }

    private func clearExistingModelArtifacts(folderNames: [String], whisperDownloadBase: URL) {
        let fileManager = FileManager.default
        let uniqueNames = Array(Set(folderNames.filter { !$0.isEmpty }))

        for folderName in uniqueNames {
            if let stalePath = resolveInstalledModelPath(folderName: folderName),
               fileManager.fileExists(atPath: stalePath.path) {
                debugLog("🧹 Removing existing model folder before re-download: \(stalePath.lastPathComponent)")
                try? fileManager.removeItem(at: stalePath)
            }

            let directFolder = whisperDownloadBase
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(folderName)

            if fileManager.fileExists(atPath: directFolder.path) {
                debugLog("🧹 Removing direct model folder before re-download: \(folderName)")
                try? fileManager.removeItem(at: directFolder)
            }

            let huggingFaceCacheFolder = whisperDownloadBase
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(".cache")
                .appendingPathComponent("huggingface")
                .appendingPathComponent("download")
                .appendingPathComponent(folderName)

            if fileManager.fileExists(atPath: huggingFaceCacheFolder.path) {
                debugLog("🧹 Removing Hugging Face cache before re-download: \(folderName)")
                try? fileManager.removeItem(at: huggingFaceCacheFolder)
            }
        }
    }

    // MARK: - Storage

    private func updateStorageInfo() {
        let modelsDirPath = modelsDirectory.path
        let models = installedModels
        
        DispatchQueue.global(qos: .utility).async {
            do {
                let fileSystem = try FileManager.default.attributesOfFileSystem(forPath: modelsDirPath)
                let freeSize = fileSystem[.systemFreeSize] as? Int64 ?? 0

                // Calculate used storage by models
                var calculatedUsed: Int64 = 0
                for model in models {
                    if let localPath = model.localPath,
                       let attributes = try? FileManager.default.attributesOfItem(atPath: localPath.path),
                       let fileSize = attributes[.size] as? Int64 {
                        calculatedUsed += fileSize
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.availableStorage = freeSize
                    self?.usedStorage = calculatedUsed
                }
            } catch {
                debugLog("Failed to get storage info: \(error.localizedDescription)")
            }
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
