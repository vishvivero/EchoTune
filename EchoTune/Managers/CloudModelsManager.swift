//
//  CloudModelsManager.swift
//  EchoTune
//
//  Manages cloud transcription models and keeps their API keys aligned with
//  AppSettings so the UI and runtime use the same credentials.
//

import Foundation
import Combine

class CloudModelsManager: ObservableObject {
    static let shared = CloudModelsManager()

    @Published var availableModels: [CloudModel] = CloudModel.availableModels
    @Published var apiKeys: [String: String] = [:]

    private let apiKeysStorageKey = "cloudModelApiKeys"

    private init() {
        loadAPIKeys()
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("APIKeyChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func setAPIKey(_ key: String, for modelId: String) {
        switch modelId {
        case "groq-whisper-large-v3-turbo":
            AppSettings.shared.groqAPIKey = key
        case "google-gemini-2-5-flash", "google-gemini-2-5-pro":
            AppSettings.shared.geminiAPIKey = key
        default:
            apiKeys[modelId] = key
            saveAPIKeys()
        }
        objectWillChange.send()
    }

    func getAPIKey(for modelId: String) -> String? {
        switch modelId {
        case "groq-whisper-large-v3-turbo":
            return AppSettings.shared.groqAPIKey
        case "google-gemini-2-5-flash", "google-gemini-2-5-pro":
            return AppSettings.shared.geminiAPIKey
        default:
            return apiKeys[modelId]
        }
    }

    func removeAPIKey(for modelId: String) {
        switch modelId {
        case "groq-whisper-large-v3-turbo":
            AppSettings.shared.groqAPIKey = ""
        case "google-gemini-2-5-flash", "google-gemini-2-5-pro":
            AppSettings.shared.geminiAPIKey = ""
        default:
            apiKeys.removeValue(forKey: modelId)
            saveAPIKeys()
        }
        objectWillChange.send()
    }

    func hasAPIKey(for modelId: String) -> Bool {
        guard let key = getAPIKey(for: modelId) else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func validateAPIKey(_ key: String, for model: CloudModel) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        switch model.provider {
        case .groq:
            return trimmed.hasPrefix("gsk_")
        }
    }

    func isConfigured(_ model: CloudModel) -> Bool {
        hasAPIKey(for: model.id)
    }

    var configuredModels: [CloudModel] {
        availableModels.filter { isConfigured($0) }
    }

    var unconfiguredModels: [CloudModel] {
        availableModels.filter { !isConfigured($0) }
    }

    private func saveAPIKeys() {
        if let encoded = try? JSONEncoder().encode(apiKeys) {
            UserDefaults.standard.set(encoded, forKey: apiKeysStorageKey)
        }
    }

    private func loadAPIKeys() {
        if let data = UserDefaults.standard.data(forKey: apiKeysStorageKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            apiKeys = decoded
        }
    }

    func getModel(byId id: String) -> CloudModel? {
        availableModels.first { $0.id == id }
    }

    func models(for provider: CloudProvider) -> [CloudModel] {
        availableModels.filter { $0.provider == provider }
    }
}
