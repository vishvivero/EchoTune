//
//  CloudModel.swift
//  EchoTune
//
//  Curated cloud models exposed in the product UI.
//  EchoTune currently surfaces a single cloud transcription provider: Groq.
//

import Foundation

struct CloudModel: Identifiable {
    let id: String
    let name: String
    let provider: CloudProvider
    let description: String
    let features: [String]
    let apiKeyRequired: Bool
    let apiKeyUrl: String
    let pricing: String

    var displayName: String {
        "\(name) (\(provider.rawValue))"
    }
}

enum CloudProvider: String, CaseIterable {
    case groq = "Groq"

    var websiteUrl: String {
        switch self {
        case .groq:
            return "https://console.groq.com/keys"
        }
    }

    var iconColor: String {
        switch self {
        case .groq:
            return "orange"
        }
    }
}

extension CloudModel {
    static let availableModels: [CloudModel] = [
        CloudModel(
            id: "groq-whisper-large-v3-turbo",
            name: "Whisper Large v3 Turbo",
            provider: .groq,
            description: "Ultra-fast cloud transcription with the simplest API-key onboarding flow.",
            features: ["Fastest setup", "Great multilingual accuracy", "Shared key with Groq enhancement"],
            apiKeyRequired: true,
            apiKeyUrl: "https://console.groq.com/keys",
            pricing: "Free tier available"
        )
    ]
}
