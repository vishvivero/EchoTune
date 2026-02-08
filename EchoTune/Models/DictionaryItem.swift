//
//  DictionaryItem.swift
//  EchoTune
//
//  Models for custom dictionary entries
//

import Foundation

// Word replacement: spoken word → written replacement
struct WordReplacement: Identifiable, Codable {
    let id: UUID
    var spokenForm: String        // What the user says (e.g., "btw")
    var writtenForm: String        // What gets typed (e.g., "by the way")
    var caseSensitive: Bool        // Whether to match case exactly
    var isEnabled: Bool            // Whether this replacement is active
    var dateAdded: Date

    init(id: UUID = UUID(), spokenForm: String, writtenForm: String, caseSensitive: Bool = false, isEnabled: Bool = true) {
        self.id = id
        self.spokenForm = spokenForm
        self.writtenForm = writtenForm
        self.caseSensitive = caseSensitive
        self.isEnabled = isEnabled
        self.dateAdded = Date()
    }

    // Backward-compatible Codable
    enum CodingKeys: String, CodingKey {
        case id, spokenForm, writtenForm, caseSensitive, isEnabled, dateAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        spokenForm = try container.decode(String.self, forKey: .spokenForm)
        writtenForm = try container.decode(String.self, forKey: .writtenForm)
        caseSensitive = try container.decode(Bool.self, forKey: .caseSensitive)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
    }
}

// Correct spelling: teach the model proper spellings
struct CorrectSpelling: Identifiable, Codable {
    let id: UUID
    var word: String               // Correct spelling
    var variations: [String]       // Common misspellings or variations
    var isEnabled: Bool            // Whether this spelling is active
    var dateAdded: Date

    init(id: UUID = UUID(), word: String, variations: [String] = [], isEnabled: Bool = true) {
        self.id = id
        self.word = word
        self.variations = variations
        self.isEnabled = isEnabled
        self.dateAdded = Date()
    }

    // Backward-compatible Codable
    enum CodingKeys: String, CodingKey {
        case id, word, variations, isEnabled, dateAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        word = try container.decode(String.self, forKey: .word)
        variations = try container.decode([String].self, forKey: .variations)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
    }
}
