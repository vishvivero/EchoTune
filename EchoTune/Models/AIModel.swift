//
//  AIModel.swift
//  EchoTune
//
//  Extracted from ModelManager.swift
//

import Foundation

// MARK: - AIModel

struct AIModel: Identifiable, Equatable, Hashable {
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

    /// One-line, plain-English note on what this model is best at.
    /// Shown in onboarding instead of star ratings — helps users pick by
    /// use case rather than abstract scores.
    var insight: String {
        switch id {
        case "apple-speech":
            return "Built into macOS — no download. Great for quick notes and drafts."
        case "distil-whisper_distil-large-v3_turbo_600MB":
            return "Best all-rounder — great for emails, documents, and daily dictation."
        case "openai_whisper-large-v3-turbo":
            return "Top accuracy — ideal for long, technical, or precise dictation."
        case "openai_whisper-base":
            return "Lightweight and fast — suits Macs with less RAM and quick dictation bursts."
        case "parakeet-tdt-0.6b-v3":
            return "Near-real-time speed on Apple Silicon — for when speed matters most."
        case "parakeet-tdt-0.6b-v2":
            return "English-optimised — top English accuracy with fast loading."
        case "groq-whisper-large-v3-turbo":
            return "Cloud-powered — top accuracy with no local download (needs API key)."
        case "deepgram-nova":
            return "Cloud-powered — fast and accurate (needs API key)."
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
