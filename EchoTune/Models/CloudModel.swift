//
//  CloudModel.swift
//  EchoTune
//
//  Cloud-based transcription models
//

import Foundation

struct CloudModel: Identifiable {
    let id: String
    let name: String
    let provider: CloudProvider
    let description: String
    let features: [String]
    let apiKeyRequired: Bool
    let apiKeyUrl: String  // Where to get the API key
    let pricing: String

    var displayName: String {
        "\(name) (\(provider.rawValue))"
    }
}

enum CloudProvider: String, CaseIterable {
    case groq = "Groq"
    case elevenLabs = "ElevenLabs"
    case deepgram = "Deepgram"
    case mistral = "Mistral"
    case google = "Google"
    case soniox = "Soniox"

    var websiteUrl: String {
        switch self {
        case .groq:
            return "https://console.groq.com/keys"
        case .elevenLabs:
            return "https://elevenlabs.io/app/speech-synthesis/text-to-speech"
        case .deepgram:
            return "https://console.deepgram.com/signup?jump=keys"
        case .mistral:
            return "https://console.mistral.ai/api-keys"
        case .google:
            return "https://ai.google.dev/gemini-api/docs/api-key"
        case .soniox:
            return "https://soniox.com/pricing"
        }
    }

    var iconColor: String {
        switch self {
        case .groq: return "orange"
        case .elevenLabs: return "purple"
        case .deepgram: return "green"
        case .mistral: return "red"
        case .google: return "blue"
        case .soniox: return "cyan"
        }
    }
}

// Available cloud models
extension CloudModel {
    static let availableModels: [CloudModel] = [
        CloudModel(
            id: "groq-whisper-large-v3-turbo",
            name: "Whisper Large v3 Turbo",
            provider: .groq,
            description: "Ultra-fast Whisper transcription with Groq's LPU™ inference",
            features: ["32x realtime speed", "Best accuracy", "Multilingual"],
            apiKeyRequired: true,
            apiKeyUrl: "https://console.groq.com/keys",
            pricing: "Free tier available"
        ),
        CloudModel(
            id: "elevenlabs-scribe-v1",
            name: "Scribe v1",
            provider: .elevenLabs,
            description: "High-quality speech-to-text from ElevenLabs",
            features: ["Low latency", "Speaker diarization", "High accuracy"],
            apiKeyRequired: true,
            apiKeyUrl: "https://elevenlabs.io/app/speech-synthesis/text-to-speech",
            pricing: "Usage-based pricing"
        ),
        CloudModel(
            id: "deepgram-nova",
            name: "Nova",
            provider: .deepgram,
            description: "Deepgram's fastest and most accurate model",
            features: ["Ultra-low latency", "Streaming support", "99%+ accuracy"],
            apiKeyRequired: true,
            apiKeyUrl: "https://console.deepgram.com/signup?jump=keys",
            pricing: "$0.0043/min"
        ),
        CloudModel(
            id: "deepgram-nova-3-medical",
            name: "Nova-3 Medical",
            provider: .deepgram,
            description: "Specialized medical terminology transcription",
            features: ["Medical vocabulary", "HIPAA compliant", "High precision"],
            apiKeyRequired: true,
            apiKeyUrl: "https://console.deepgram.com/signup?jump=keys",
            pricing: "$0.0059/min"
        ),
        CloudModel(
            id: "mistral-voxtral-mini",
            name: "Voxtral Mini",
            provider: .mistral,
            description: "Efficient multilingual transcription",
            features: ["100+ languages", "Fast inference", "Cost-effective"],
            apiKeyRequired: true,
            apiKeyUrl: "https://console.mistral.ai/api-keys",
            pricing: "Pay as you go"
        ),
        CloudModel(
            id: "google-gemini-2-5-pro",
            name: "Gemini 2.5 Pro",
            provider: .google,
            description: "Advanced AI with multimodal understanding",
            features: ["Context-aware", "Long-form audio", "100+ languages"],
            apiKeyRequired: true,
            apiKeyUrl: "https://ai.google.dev/gemini-api/docs/api-key",
            pricing: "Free tier + usage-based"
        ),
        CloudModel(
            id: "google-gemini-2-5-flash",
            name: "Gemini 2.5 Flash",
            provider: .google,
            description: "Fast and efficient transcription",
            features: ["Ultra-fast", "Real-time capable", "Cost-optimized"],
            apiKeyRequired: true,
            apiKeyUrl: "https://ai.google.dev/gemini-api/docs/api-key",
            pricing: "Lower cost than Pro"
        ),
        CloudModel(
            id: "soniox-stt-async-v3",
            name: "Soniox STT Async v3",
            provider: .soniox,
            description: "Production-grade speech recognition",
            features: ["Custom vocabulary", "Low WER", "Batch processing"],
            apiKeyRequired: true,
            apiKeyUrl: "https://soniox.com/pricing",
            pricing: "$0.005/min"
        )
    ]
}
