//
//  CloudModelsManager.swift
//  EchoTune
//
//  Manages cloud-based transcription models and API keys
//

import Foundation
import Combine

class CloudModelsManager: ObservableObject {
    static let shared = CloudModelsManager()

    @Published var availableModels: [CloudModel] = CloudModel.availableModels
    @Published var apiKeys: [String: String] = [:]  // modelId: apiKey

    private let apiKeysStorageKey = "cloudModelApiKeys"

    private init() {
        loadAPIKeys()
    }

    // MARK: - API Key Management

    func setAPIKey(_ key: String, for modelId: String) {
        apiKeys[modelId] = key
        saveAPIKeys()
    }

    func getAPIKey(for modelId: String) -> String? {
        return apiKeys[modelId]
    }

    func removeAPIKey(for modelId: String) {
        apiKeys.removeValue(forKey: modelId)
        saveAPIKeys()
    }

    func hasAPIKey(for modelId: String) -> Bool {
        guard let key = apiKeys[modelId] else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func validateAPIKey(_ key: String, for model: CloudModel) -> Bool {
        // Basic validation - just check it's not empty
        // In production, you'd make an API call to validate
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count > 10
    }

    // MARK: - Model Status

    func isConfigured(_ model: CloudModel) -> Bool {
        return hasAPIKey(for: model.id)
    }

    var configuredModels: [CloudModel] {
        availableModels.filter { isConfigured($0) }
    }

    var unconfiguredModels: [CloudModel] {
        availableModels.filter { !isConfigured($0) }
    }

    // MARK: - Persistence

    private func saveAPIKeys() {
        // In production, use Keychain for sensitive data
        // For now, using UserDefaults (encrypted in a real app)
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

    // MARK: - Helper Methods

    func getModel(byId id: String) -> CloudModel? {
        return availableModels.first { $0.id == id }
    }

    func models(for provider: CloudProvider) -> [CloudModel] {
        return availableModels.filter { $0.provider == provider }
    }
}
