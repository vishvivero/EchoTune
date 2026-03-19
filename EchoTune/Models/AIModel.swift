//
//  AIModel.swift
//  EchoTune
//
//  Extracted from ModelManager.swift
//

import Foundation

// MARK: - AIModel

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

// MARK: - ModelCategory

enum ModelCategory: String, CaseIterable {
    case recommended = "Recommended"
    case local = "Local"
    case cloud = "Cloud"
    case comingSoon = "Coming Soon"
}
