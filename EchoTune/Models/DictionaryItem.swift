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
    var dateAdded: Date

    init(id: UUID = UUID(), spokenForm: String, writtenForm: String, caseSensitive: Bool = false) {
        self.id = id
        self.spokenForm = spokenForm
        self.writtenForm = writtenForm
        self.caseSensitive = caseSensitive
        self.dateAdded = Date()
    }
}

// Correct spelling: teach the model proper spellings
struct CorrectSpelling: Identifiable, Codable {
    let id: UUID
    var word: String               // Correct spelling
    var variations: [String]       // Common misspellings or variations
    var dateAdded: Date

    init(id: UUID = UUID(), word: String, variations: [String] = []) {
        self.id = id
        self.word = word
        self.variations = variations
        self.dateAdded = Date()
    }
}
