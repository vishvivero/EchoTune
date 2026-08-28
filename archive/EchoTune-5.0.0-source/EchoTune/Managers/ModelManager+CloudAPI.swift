//
//  ModelManager+CloudAPI.swift
//  EchoTune
//
//  Extracted from ModelManager.swift — cloud API key management.
//

import Foundation
import Combine

// MARK: - Cloud API Keys

extension ModelManager {

    func apiKey(for model: AIModel) -> String {
        KeychainHelper.load(forKey: apiKeyPrefix + model.id)
    }

    func saveApiKey(_ key: String, for model: AIModel) {
        KeychainHelper.save(key, forKey: apiKeyPrefix + model.id)
        objectWillChange.send()
    }

    func clearApiKey(for model: AIModel) {
        KeychainHelper.delete(forKey: apiKeyPrefix + model.id)
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
}
