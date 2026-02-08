//
//  DictionaryManager.swift
//  EchoTune
//
//  Manages custom dictionary for word replacements and correct spellings
//

import Foundation
import Combine

class DictionaryManager: ObservableObject {
    static let shared = DictionaryManager()

    @Published var wordReplacements: [WordReplacement] = []
    @Published var correctSpellings: [CorrectSpelling] = []

    private let replacementsKey = "wordReplacements"
    private let spellingsKey = "correctSpellings"

    private init() {
        loadDictionary()
    }

    // MARK: - Word Replacements

    func addReplacement(_ replacement: WordReplacement) {
        wordReplacements.append(replacement)
        saveReplacements()
    }

    func updateReplacement(_ replacement: WordReplacement) {
        if let index = wordReplacements.firstIndex(where: { $0.id == replacement.id }) {
            wordReplacements[index] = replacement
            saveReplacements()
        }
    }

    func deleteReplacement(_ replacement: WordReplacement) {
        wordReplacements.removeAll { $0.id == replacement.id }
        saveReplacements()
    }

    func toggleReplacement(_ replacement: WordReplacement) {
        if let index = wordReplacements.firstIndex(where: { $0.id == replacement.id }) {
            wordReplacements[index].isEnabled.toggle()
            saveReplacements()
        }
    }

    // Apply replacements to transcribed text
    func applyReplacements(to text: String) -> String {
        var result = text

        for replacement in wordReplacements where replacement.isEnabled {
            // Replace whole words only (not parts of words)
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: replacement.spokenForm))\\b"

            if let regex = try? NSRegularExpression(pattern: pattern, options: replacement.caseSensitive ? [] : [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement.writtenForm)
            }
        }

        return result
    }

    // MARK: - Correct Spellings

    func addSpelling(_ spelling: CorrectSpelling) {
        correctSpellings.append(spelling)
        saveSpellings()
    }

    func updateSpelling(_ spelling: CorrectSpelling) {
        if let index = correctSpellings.firstIndex(where: { $0.id == spelling.id }) {
            correctSpellings[index] = spelling
            saveSpellings()
        }
    }

    func deleteSpelling(_ spelling: CorrectSpelling) {
        correctSpellings.removeAll { $0.id == spelling.id }
        saveSpellings()
    }

    func toggleSpelling(_ spelling: CorrectSpelling) {
        if let index = correctSpellings.firstIndex(where: { $0.id == spelling.id }) {
            correctSpellings[index].isEnabled.toggle()
            saveSpellings()
        }
    }

    // Apply correct spellings to text
    func applySpellings(to text: String) -> String {
        var result = text

        for spelling in correctSpellings where spelling.isEnabled {
            for variation in spelling.variations {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: variation))\\b"

                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(result.startIndex..., in: result)
                    result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: spelling.word)
                }
            }
        }

        return result
    }

    // Apply all dictionary transformations
    func process(text: String) -> String {
        var result = text
        result = applySpellings(to: result)
        result = applyReplacements(to: result)
        return result
    }

    // MARK: - Persistence

    private func saveReplacements() {
        if let encoded = try? JSONEncoder().encode(wordReplacements) {
            UserDefaults.standard.set(encoded, forKey: replacementsKey)
        }
    }

    private func saveSpellings() {
        if let encoded = try? JSONEncoder().encode(correctSpellings) {
            UserDefaults.standard.set(encoded, forKey: spellingsKey)
        }
    }

    private func loadDictionary() {
        // Load word replacements
        if let data = UserDefaults.standard.data(forKey: replacementsKey),
           let decoded = try? JSONDecoder().decode([WordReplacement].self, from: data) {
            wordReplacements = decoded
        } else {
            // Add some default replacements
            wordReplacements = [
                WordReplacement(spokenForm: "btw", writtenForm: "by the way"),
                WordReplacement(spokenForm: "fyi", writtenForm: "for your information"),
                WordReplacement(spokenForm: "asap", writtenForm: "as soon as possible")
            ]
            saveReplacements()
        }

        // Load correct spellings
        if let data = UserDefaults.standard.data(forKey: spellingsKey),
           let decoded = try? JSONDecoder().decode([CorrectSpelling].self, from: data) {
            correctSpellings = decoded
        }
    }

    // MARK: - Import/Export (Phase 6C)

    struct DictionaryExport: Codable {
        let version: String
        let exportDate: Date
        let wordReplacements: [WordReplacement]
        let correctSpellings: [CorrectSpelling]
    }

    /// Export dictionary to JSON file
    func exportDictionary() throws -> Data {
        let export = DictionaryExport(
            version: "1.0",
            exportDate: Date(),
            wordReplacements: wordReplacements,
            correctSpellings: correctSpellings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(export)
    }

    /// Import dictionary from JSON file (merges with existing)
    func importDictionary(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let imported = try decoder.decode(DictionaryExport.self, from: data)

        debugLog("📥 Importing dictionary...")
        debugLog("   Version: \(imported.version)")
        debugLog("   Date: \(imported.exportDate)")
        debugLog("   Word Replacements: \(imported.wordReplacements.count)")
        debugLog("   Correct Spellings: \(imported.correctSpellings.count)")

        // Merge word replacements (avoid duplicates)
        var addedReplacements = 0
        for replacement in imported.wordReplacements {
            // Check if this spoken form already exists
            if !wordReplacements.contains(where: { $0.spokenForm.lowercased() == replacement.spokenForm.lowercased() }) {
                wordReplacements.append(replacement)
                addedReplacements += 1
            }
        }

        // Merge correct spellings (avoid duplicates)
        var addedSpellings = 0
        for spelling in imported.correctSpellings {
            // Check if this word already exists
            if !correctSpellings.contains(where: { $0.word.lowercased() == spelling.word.lowercased() }) {
                correctSpellings.append(spelling)
                addedSpellings += 1
            }
        }

        // Save merged data
        saveReplacements()
        saveSpellings()

        debugLog("✅ Import complete!")
        debugLog("   Added \(addedReplacements) word replacements")
        debugLog("   Added \(addedSpellings) correct spellings")
    }

    /// Import dictionary and return merge counts
    func importDictionaryWithCounts(from data: Data) throws -> (replacements: Int, spellings: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let imported = try decoder.decode(DictionaryExport.self, from: data)

        var addedReplacements = 0
        for replacement in imported.wordReplacements {
            if !wordReplacements.contains(where: { $0.spokenForm.lowercased() == replacement.spokenForm.lowercased() }) {
                wordReplacements.append(replacement)
                addedReplacements += 1
            }
        }

        var addedSpellings = 0
        for spelling in imported.correctSpellings {
            if !correctSpellings.contains(where: { $0.word.lowercased() == spelling.word.lowercased() }) {
                correctSpellings.append(spelling)
                addedSpellings += 1
            }
        }

        saveReplacements()
        saveSpellings()

        return (addedReplacements, addedSpellings)
    }

    /// Save dictionary to file
    func saveDictionaryToFile(at url: URL) throws {
        let data = try exportDictionary()
        try data.write(to: url)
        debugLog("💾 Dictionary saved to: \(url.path)")
    }

    /// Load dictionary from file
    func loadDictionaryFromFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        try importDictionary(from: data)
    }

    // MARK: - Helper Methods

    /// Get statistics about the dictionary
    func getStatistics() -> DictionaryStatistics {
        return DictionaryStatistics(
            totalReplacements: wordReplacements.count,
            totalSpellings: correctSpellings.count,
            totalVariations: correctSpellings.reduce(0) { $0 + $1.variations.count }
        )
    }

    /// Clear all dictionary data (with confirmation needed from UI)
    func clearAll() {
        wordReplacements.removeAll()
        correctSpellings.removeAll()
        saveReplacements()
        saveSpellings()
        debugLog("🗑️ Dictionary cleared")
    }

    /// Reset to default word replacements
    func resetToDefaults() {
        wordReplacements = [
            WordReplacement(spokenForm: "btw", writtenForm: "by the way"),
            WordReplacement(spokenForm: "fyi", writtenForm: "for your information"),
            WordReplacement(spokenForm: "asap", writtenForm: "as soon as possible"),
            WordReplacement(spokenForm: "imho", writtenForm: "in my humble opinion"),
            WordReplacement(spokenForm: "imo", writtenForm: "in my opinion"),
            WordReplacement(spokenForm: "lol", writtenForm: "laugh out loud"),
            WordReplacement(spokenForm: "omw", writtenForm: "on my way"),
            WordReplacement(spokenForm: "eta", writtenForm: "estimated time of arrival")
        ]
        saveReplacements()
        debugLog("🔄 Reset to default word replacements")
    }
}

struct DictionaryStatistics {
    let totalReplacements: Int
    let totalSpellings: Int
    let totalVariations: Int
}
