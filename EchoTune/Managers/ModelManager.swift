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
            // Check installed models
            self?.checkInstalledModels()

            // Update storage info
            self?.updateStorageInfo()
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
        // Clear current list
        installedModels = []

        // WhisperKit stores models in: ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
        let whisperKitModelsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")

        print("🔍 Checking for installed models at:")
        print("   WhisperKit path: \(whisperKitModelsPath.path)")

        // Check for each model if it exists
        for model in availableModels {
            // Only Apple Speech is considered built-in
            if model.id == "apple-speech" {
                var installedModel = model
                installedModel.isInstalled = true
                installedModels.append(installedModel)

                // IMPORTANT: Update the availableModels array too (used by UI)
                if let index = availableModels.firstIndex(where: { $0.id == model.id }) {
                    availableModels[index].isInstalled = true
                }

                print("   ✅ Built-in model: \(model.name)")
                continue
            }

            // Only check for Whisper variants supported by WhisperKit
            guard let whisperVariant = whisperVariant(for: model.id) else {
                continue
            }
            // WhisperKit downloads models with "openai_whisper-" prefix for standard models
            // But special models like distil-whisper and openai_whisper-large-v3_turbo use their full ID
            let whisperKitModelName: String
            if whisperVariant.hasPrefix("distil-") || whisperVariant.hasPrefix("openai_whisper-") {
                // Special models use their ID as-is (no prefix)
                whisperKitModelName = whisperVariant
            } else {
                // Standard models get the openai_whisper- prefix
                whisperKitModelName = "openai_whisper-\(whisperVariant)"
            }
            let whisperKitModelPath = whisperKitModelsPath.appendingPathComponent(whisperKitModelName)

            if FileManager.default.fileExists(atPath: whisperKitModelPath.path) {
                var installedModel = model
                installedModel.isInstalled = true
                installedModel.localPath = whisperKitModelPath
                installedModels.append(installedModel)

                // Update the available models array
                if let index = availableModels.firstIndex(where: { $0.id == model.id }) {
                    availableModels[index].isInstalled = true
                }

                print("   ✅ Found installed model: \(model.name) at \(whisperKitModelPath.lastPathComponent)")
            } else {
                print("   ❌ Model not found: \(model.name) (looking for \(whisperKitModelName))")
            }
        }

        print("📊 Total installed models: \(installedModels.count)")

        // Load saved default model preference
        if let savedDefaultID = UserDefaults.standard.string(forKey: "defaultModelID"),
           let savedModel = installedModels.first(where: { $0.id == savedDefaultID }) {
            currentModel = savedModel
            print("✅ Restored default model: \(savedModel.name)")
        } else if currentModel == nil, let firstInstalled = installedModels.first {
            currentModel = firstInstalled
            print("✅ Set default model: \(firstInstalled.name)")
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
        // Currently no cloud connectors are implemented; set to false for all
        switch model.id {
        case "groq-whisper-large-v3-turbo":
            return false
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
            print("❌ Download not supported for model: \(model.id)")
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

        print("📥 Starting download for \(model.name) (\(model.id))")

        // Use WhisperKit to download the model
        Task {
            do {
                // Use WhisperKit to download the model
                _ = try await WhisperKit.download(variant: variant) { progress in
                    DispatchQueue.main.async {
                        self.downloadProgress = progress.fractionCompleted
                        progressHandler?(progress.fractionCompleted)
                        print("⏬ Download progress: \(Int(progress.fractionCompleted * 100))%")
                    }
                }

                await MainActor.run {
                    print("✅ Model downloaded successfully: \(model.name)")

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
                    print("❌ Download failed: \(error)")
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
        return !apiKey(for: model).isEmpty
    }
    
    func deleteModel(_ model: AIModel) -> Bool {
        // Don't allow deleting built-in models
        guard !model.isBuiltIn else {
            print("❌ Cannot delete built-in model: \(model.name)")
            return false
        }

        // Don't allow deleting the current model
        guard currentModel?.id != model.id else {
            print("❌ Cannot delete current model: \(model.name). Please select a different model first.")
            return false
        }

        guard model.isInstalled, let localPath = model.localPath else {
            print("❌ Model not installed or no local path: \(model.name)")
            return false
        }

        do {
            try FileManager.default.removeItem(at: localPath)
            print("✅ Deleted model file: \(localPath.path)")

            // Remove from installed models
            installedModels.removeAll { $0.id == model.id }

            // Update the available models array to mark as not installed
            if let index = availableModels.firstIndex(where: { $0.id == model.id }) {
                availableModels[index].isInstalled = false
            }

            // Update current model if needed (extra safety check)
            if currentModel?.id == model.id {
                currentModel = installedModels.first
                print("⚠️ Current model was deleted, switching to: \(currentModel?.name ?? "none")")
            }

            // Update storage info
            updateStorageInfo()

            // Force UI refresh
            objectWillChange.send()

            print("✅ Model deleted successfully: \(model.name)")
            return true
        } catch {
            print("❌ Failed to delete model: \(error.localizedDescription)")
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
        print("💾 Saved default model: \(model.name)")

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
            print("Failed to get storage info: \(error.localizedDescription)")
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





