//
//  FillerWordManager.swift
//  EchoTune
//
//  Configurable spoken filler-word removal with automatic post-removal
//  punctuation, whitespace, and sentence-capitalization repair.
//

import Combine
import Foundation

final class FillerWordManager: ObservableObject {
    static let shared = FillerWordManager()

    static let defaultFillers: [String] = [
        "uh", "um", "umm", "uhh", "erm", "er", "ah", "hmm", "mhm"
    ]

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: enabledKey) }
    }

    @Published var fillerWords: [String] {
        didSet { saveFillers() }
    }

    private let enabledKey = "fillerRemovalEnabled"
    private let fillersKey = "customFillerWords"

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        } else {
            self.isEnabled = true
        }

        if let saved = UserDefaults.standard.stringArray(forKey: fillersKey), !saved.isEmpty {
            self.fillerWords = saved
        } else {
            self.fillerWords = Self.defaultFillers
        }
    }

    func addFiller(_ raw: String) {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !fillerWords.contains(where: { $0.lowercased() == cleaned }) else { return }
        fillerWords.append(cleaned)
    }

    func removeFiller(_ word: String) {
        fillerWords.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
    }

    func resetToDefaults() {
        fillerWords = Self.defaultFillers
    }

    /// Removes configured filler words and repairs orphaned commas, spaces, and sentence case.
    func clean(_ text: String) -> String {
        guard isEnabled, !fillerWords.isEmpty, !text.isEmpty else { return text }

        let hadSentenceStartCapital = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .first
            .map { $0.isUppercase } ?? false

        var result = text
        // Sort longest phrases first so multi-word fillers match before single words
        let sorted = fillerWords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        for filler in sorted {
            let escaped = NSRegularExpression.escapedPattern(for: filler)
            // First strip parenthetical comma-wrapped fillers (", uh," -> "")
            let wrappedPattern = ",\\s*(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])\\s*,"
            if let wrappedRegex = try? NSRegularExpression(pattern: wrappedPattern, options: [.caseInsensitive]) {
                result = wrappedRegex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
            // Then strip standalone filler + optional trailing comma
            let pattern = "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])(?:\\s*,)?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }

        return Self.repairPunctuationAndCapitalization(result, preserveLeadingCapital: hadSentenceStartCapital)
    }

    static func repairPunctuationAndCapitalization(_ input: String, preserveLeadingCapital: Bool) -> String {
        var s = input

        // Collapse spaces before punctuation: "went , to" -> "went, to"
        if let r = try? NSRegularExpression(pattern: "\\s+([,.;:!?])") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
        }
        // Collapse repeated commas: ", ," -> ","
        if let r = try? NSRegularExpression(pattern: ",(\\s*,)+") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: ",")
        }
        // Remove leading comma/space left behind at start of text or after sentence terminator
        if let r = try? NSRegularExpression(pattern: "^\\s*[,;:]\\s*") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        if let r = try? NSRegularExpression(pattern: "([.!?])\\s*,\\s*") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1 ")
        }
        // Collapse multiple horizontal spaces
        if let r = try? NSRegularExpression(pattern: "[ \\t]{2,}") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }

        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))

        // Re-capitalize sentence starts (e.g. "Um, hello there. Uh, yes." -> "Hello there. Yes.")
        if preserveLeadingCapital, let firstIdx = s.firstIndex(where: { $0.isLetter }) {
            if firstIdx == s.startIndex {
                s.replaceSubrange(firstIdx...firstIdx, with: String(s[firstIdx]).uppercased())
            }
        }

        if let sentenceRegex = try? NSRegularExpression(pattern: "([.!?]\\s+)([a-z])") {
            let ns = s as NSString
            let matches = sentenceRegex.matches(in: s, range: NSRange(location: 0, length: ns.length))
            let mutable = NSMutableString(string: s)
            for match in matches.reversed() where match.numberOfRanges >= 3 {
                let letterRange = match.range(at: 2)
                let upper = mutable.substring(with: letterRange).uppercased()
                mutable.replaceCharacters(in: letterRange, with: upper)
            }
            s = mutable as String
        }

        return s
    }

    private func saveFillers() {
        UserDefaults.standard.set(fillerWords, forKey: fillersKey)
    }
}
