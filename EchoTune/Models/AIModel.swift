//
//  AIModel.swift
//  EchoTune
//
//  Extracted from ModelManager.swift
//

import Foundation

// MARK: - AIModel

enum AIModelBackend: String, CaseIterable, Codable, Hashable {
    case appleSpeech
    case whisper
    case parakeet
    case senseVoice
    case paraformer
    case groq
    case deepgram
    case openAI
}

struct AIModel: Identifiable, Equatable, Hashable {
    let id: String
    let backend: AIModelBackend
    let name: String
    let size: Int64
    let description: String
    let language: String
    /// Explicit one-language default for multilingual roster selection.
    /// Nil means the existing auto-detect/preferred-language behavior remains.
    let fixedLanguage: String?
    let url: URL
    let type: ModelSize
    let category: ModelCategory
    let speedRating: Int  // 1-5 stars
    let accuracyRating: Int  // 1-5 stars
    let isBuiltIn: Bool

    var isInstalled: Bool = false
    var localPath: URL?

    init(id: String, name: String, size: Int64, description: String, language: String, fixedLanguage: String? = nil, url: URL, type: ModelSize, category: ModelCategory = .recommended, speedRating: Int = 3, accuracyRating: Int = 3, isBuiltIn: Bool = false, backend: AIModelBackend? = nil) {
        self.id = id
        self.backend = backend ?? Self.defaultBackend(for: id, isBuiltIn: isBuiltIn, category: category)
        self.name = name
        self.size = size
        self.description = description
        self.language = language
        self.fixedLanguage = fixedLanguage
        self.url = url
        self.type = type
        self.category = category
        self.speedRating = speedRating
        self.accuracyRating = accuracyRating
        self.isBuiltIn = isBuiltIn
    }

    /// The single model EchoTune recommends and selects by default, on every
    /// Mac. Onboarding, Settings and the fallback default all read this so the
    /// recommendation can only ever be changed in one place.
    static let recommendedModelID = "parakeet-tdt-0.6b-v3"

    var isRecommended: Bool { id == Self.recommendedModelID }

    private static func defaultBackend(for id: String, isBuiltIn: Bool, category: ModelCategory) -> AIModelBackend {
        if isBuiltIn || id == "apple-speech" { return .appleSpeech }
        if id.hasPrefix("groq-") { return .groq }
        if id.hasPrefix("deepgram-") { return .deepgram }
        return category == .local ? .whisper : .whisper
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

    /// One-line, plain-English note on what this model is best at.
    /// Shown in onboarding instead of star ratings — helps users pick by
    /// use case rather than abstract scores.
    var insight: String {
        switch id {
        case "apple-speech":
            return "Built into macOS — no download. Great for quick notes and drafts."
        case "openai_whisper-small", "openai_whisper-small.en":
            return "Lightweight — noticeably better than Base for English, ideal for 8GB Macs."
        case "openai_whisper-large-v3-v20240930_turbo", "openai_whisper-large-v3-v20240930_turbo_632MB":
            return "Slim Whisper flagship — max accuracy, 34% smaller download. Best on M2+."
        case AIModel.recommendedModelID:
            return "Recommended for every Mac — the fastest local model, running on the Neural Engine."
        case "groq-whisper-large-v3-turbo":
            return "Cloud-powered — top accuracy with no local download (needs free Groq API key)."
        case "deepgram-nova":
            return "Cloud-powered — fast and accurate (needs API key)."
        case "paraformer-large-zh":
            return "Experimental Mandarin local ASR — optimized for zh dictation."
        case "parakeet-ja-0.6b":
            return "Experimental Japanese local ASR — optimized for ja dictation."
        default:
            return description
        }
    }

    static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - ModelCategory

enum ModelCategory: String, CaseIterable {
    case recommended = "Recommended"
    case local = "Local"
    case cloud = "Cloud"
    case comingSoon = "Coming Soon"
}
