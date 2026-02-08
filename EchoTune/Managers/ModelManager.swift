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
    enum ModelError: Error {
        case downloadFailed
        case installationFailed
        case modelNotFound
        case invalidModel
    }
    
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
    
    private var cancellables = Set<AnyCancellable>()
    private var observations: [NSKeyValueObservation] = []
    private let modelsDirectory: URL
    private let apiKeyPrefix = "apiKey:"

    /// Fires once after `checkInstalledModels()` finishes on the background thread.
    /// Observers (e.g. AppCoordinator.preloadDefaultModel) can wait on this.
    @Published var isReady = false
    
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
    
    private func loadAvailableModels() {
        // Define available Whisper models (will use WhisperKit for loading)
        availableModels = [
            // Built-in Apple Speech
            AIModel(
                id: "apple-speech",
                name: "Apple Speech",
                size: 0,
                description: "Uses native Apple Speech framework for transcription",
                language: "Multilingual",
                url: URL(string: "builtin://apple-speech")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 3,
                isBuiltIn: true
            ),
            // Supported Whisper local models (downloadable via WhisperKit)

            // Tiny models
            AIModel(
                id: "tiny.en",
                name: "Tiny (English)",
                size: 75 * 1024 * 1024, // 75MB
                description: "Tiny model, fastest, less accurate",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 2
            ),
            AIModel(
                id: "tiny",
                name: "Tiny",
                size: 75 * 1024 * 1024,
                description: "Tiny model, fastest, less accurate, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 2
            ),

            // Base models
            AIModel(
                id: "base.en",
                name: "Base (English)",
                size: 143 * 1024 * 1024, // 143MB
                description: "Base model, good balance between speed and accuracy",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 4,
                accuracyRating: 3
            ),
            AIModel(
                id: "base",
                name: "Base",
                size: 143 * 1024 * 1024,
                description: "Base model, good balance between speed and accuracy, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 4,
                accuracyRating: 3
            ),

            // Small models
            AIModel(
                id: "small.en",
                name: "Small (English)",
                size: 488 * 1024 * 1024, // 488MB
                description: "Small model, better accuracy, slower",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 3,
                accuracyRating: 4
            ),
            AIModel(
                id: "small",
                name: "Small",
                size: 488 * 1024 * 1024,
                description: "Small model, better accuracy, slower, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 3,
                accuracyRating: 4
            ),

            // Medium models
            AIModel(
                id: "medium.en",
                name: "Medium (English)",
                size: 1500 * 1024 * 1024, // 1.5GB
                description: "Medium model, high accuracy, requires more resources",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 2,
                accuracyRating: 4
            ),
            AIModel(
                id: "medium",
                name: "Medium",
                size: 1500 * 1024 * 1024,
                description: "Medium model, high accuracy, requires more resources, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 2,
                accuracyRating: 4
            ),

            // Large v3
            AIModel(
                id: "large-v3",
                name: "Large v3",
                size: 2900 * 1024 * 1024, // 2.9GB
                description: "Largest model, best accuracy, slowest, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 1,
                accuracyRating: 5
            ),

            // Large v3 Turbo (Optimized/Quantized)
            AIModel(
                id: "openai_whisper-large-v3_turbo",
                name: "Large v3 Turbo",
                size: 954 * 1024 * 1024, // 954MB (3x smaller!)
                description: "Optimized Large v3: 2-3x faster, same accuracy, uses quantization",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 3,
                accuracyRating: 5
            ),

            // Distilled Large v3 Turbo (Fastest large model)
            AIModel(
                id: "distil-whisper_distil-large-v3_turbo",
                name: "Distil Large v3 Turbo",
                size: 600 * 1024 * 1024, // 600MB (5x smaller!)
                description: "Distilled + Turbo: Fastest large model, 3-4x faster than base large-v3",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 4,
                accuracyRating: 4
            ),
            // Cloud models (require API key)
            AIModel(
                id: "groq-whisper-large-v3-turbo",
                name: "Groq Whisper",
                size: 0,
                description: "Lightning-fast cloud transcription via Groq (requires API key)",
                language: "Multilingual",
                url: URL(string: "https://console.groq.com")!,
                type: .fast,
                category: .cloud,
                speedRating: 5,
                accuracyRating: 5,
                isBuiltIn: false
            ),
            AIModel(
                id: "deepgram-nova",
                name: "Deepgram Nova 2",
                size: 0,
                description: "High-accuracy cloud transcription via Deepgram (requires API key)",
                language: "Multilingual",
                url: URL(string: "https://console.deepgram.com")!,
                type: .accurate,
                category: .cloud,
                speedRating: 4,
                accuracyRating: 5,
                isBuiltIn: false
            ),

            // Coming soon list (not selectable, no download)
            AIModel(
                id: "parakeet-v3",
                name: "Parakeet V3",
                size: 2200 * 1024 * 1024,
                description: "High-quality local ASR (coming soon)",
                language: "Multilingual",
                url: URL(string: "comingsoon://parakeet-v3")!,
                type: .accurate,
                category: .comingSoon,
                speedRating: 2,
                accuracyRating: 5
            ),
        ]
    }
    
    private func checkInstalledModels() {
        // WhisperKit stores models in: ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
        let whisperKitModelsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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
            if let resolved = resolvedCurrent {
                AppSettings.shared.defaultTranscriptionModel = resolved.id
            }
        }
    }

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
                    // Point to WhisperKit location
                    let whisperRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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

    // MARK: - Cloud API Keys
    func apiKey(for model: AIModel) -> String {
        UserDefaults.standard.string(forKey: apiKeyPrefix + model.id) ?? ""
    }

    func saveApiKey(_ key: String, for model: AIModel) {
        UserDefaults.standard.set(key, forKey: apiKeyPrefix + model.id)
        objectWillChange.send()
    }

    func clearApiKey(for model: AIModel) {
        UserDefaults.standard.removeObject(forKey: apiKeyPrefix + model.id)
        objectWillChange.send()
    }

    func apiKeyURL(for model: AIModel) -> URL? {
        switch model.id {
        case "groq-whisper-large-v3-turbo":
            return URL(string: "https://console.groq.com/keys")
        case "elevenlabs-scribe-v1":
            return URL(string: "https://elevenlabs.io/app/subscription")
        case "deepgram-nova", "deepgram-nova-3-medical":
            return URL(string: "https://console.deepgram.com/api-keys")
        case "mistral-voxtral-mini":
            return URL(string: "https://console.mistral.ai/api-keys/")
        case "gemini-2.5-pro", "gemini-2.5-flash":
            return URL(string: "https://aistudio.google.com/app/apikey")
        case "soniox-stt-async-v3":
            return URL(string: "https://soniox.com/docs/authentication")
        default:
            return nil
        }
    }

    func isCloudEnabled(_ model: AIModel) -> Bool {
        guard model.category == .cloud else { return false }
        // Check both the per-model key store AND the global AppSettings keys
        let perModelKey = apiKey(for: model)
        if !perModelKey.isEmpty { return true }
        // Fall back to AppSettings global API keys
        switch model.id {
        case "groq-whisper-large-v3-turbo":
            return !AppSettings.shared.groqAPIKey.isEmpty
        case "deepgram-nova":
            return !AppSettings.shared.deepgramAPIKey.isEmpty
        default:
            return false
        }
    }
    
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

struct AIModel: Identifiable, Equatable {
    let id: String
    let name: String
    let size: Int64
    let description: String
    let language: String
    let url: URL
    let type: ModelSize
    let category: ModelCategory
    let speedRating: Int  // 1-5 stars
    let accuracyRating: Int  // 1-5 stars
    let isBuiltIn: Bool

    var isInstalled: Bool = false
    var localPath: URL?

    init(id: String, name: String, size: Int64, description: String, language: String, url: URL, type: ModelSize, category: ModelCategory = .recommended, speedRating: Int = 3, accuracyRating: Int = 3, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.size = size
        self.description = description
        self.language = language
        self.url = url
        self.type = type
        self.category = category
        self.speedRating = speedRating
        self.accuracyRating = accuracyRating
        self.isBuiltIn = isBuiltIn
    }

    var filename: String {
        if isBuiltIn {
            return id
        }
        return "\(id).mlmodelc"
    }

    var formattedSize: String {
        if size == 0 {
            return "Built-in"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var speedRatingStars: String {
        return String(repeating: "⭐", count: speedRating)
    }

    var accuracyRatingStars: String {
        return String(repeating: "⭐", count: accuracyRating)
    }

    static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        return lhs.id == rhs.id
    }
}

enum ModelCategory: String, CaseIterable {
    case recommended = "Recommended"
    case local = "Local"
    case cloud = "Cloud"
    case comingSoon = "Coming Soon"
}





