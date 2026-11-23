//
//  FillerWordManager.swift
//  EchoTune
//
//  ET-758 · Configurable spoken filler removal + punctuation repair.
//
//  WHY THIS EXISTS
//  ---------------
//  Nobody wants "I went, uh, to the store. Erm, yes!" in their Slack message.
//  Whisper-class models transcribe fillers faithfully (that's a feature of the
//  model, not a bug), so the cleanup has to happen on the finished transcript.
//
//  Two passes:
//    1. Filler removal  — uh, um, erm, ah, hmm, er, mm, uhh... plus anything the
//                         user adds in Settings → Speech.
//    2. Repair          — orphaned commas ("I went, to the store"), double
//                         spaces, doubled punctuation, and a capital letter to
//                         start every sentence.
//
//  Conservative by design: only fillers bounded by word boundaries are removed,
//  and "ah"/"er"/"mm" are never removed when they are the entire utterance.
//

import Foundation

final class FillerWordManager {

    static let shared = FillerWordManager()

    /// Fillers every user gets. Matched case-insensitively as whole words.
    static let builtInFillers: [String] = [
        "uh", "uhh", "uhhh", "um", "umm", "ummm", "erm", "er", "ermm",
        "ah", "ahh", "hmm", "hmmm", "mm", "mmm", "uh-huh", "ehm"
    ]

    private let defaultsKey = "customFillerWords"

    private(set) var customFillers: [String] = []

    private init() {
        load()
    }

    // MARK: - Configuration

    var allFillers: [String] {
        Self.builtInFillers + customFillers
    }

    func load() {
        let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        customFillers = stored.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Adds a user-defined filler. Duplicates and built-ins are ignored.
    @discardableResult
    func addFiller(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        guard !Self.builtInFillers.contains(trimmed) else { return false }
        guard !customFillers.contains(trimmed) else { return false }
        customFillers.append(trimmed)
        persist()
        return true
    }

    @discardableResult
    func removeFiller(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let before = customFillers.count
        customFillers.removeAll { $0 == trimmed }
        guard customFillers.count != before else { return false }
        persist()
        return true
    }

    /// Test hook: replace the user list wholesale.
    func setCustomFillersForTesting(_ words: [String]) {
        customFillers = words.map { $0.lowercased() }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(customFillers, forKey: defaultsKey)
    }

    // MARK: - Cleaning

    /// Removes fillers and repairs the punctuation they leave behind.
    /// - Parameter repairCapitalization: when false the text's capitalization is
    ///   left exactly as the model produced it.
    func clean(_ text: String, repairCapitalization: Bool = true) -> String {
        guard !text.isEmpty else { return text }
        var result = removeFillers(in: text)
        result = repairPunctuation(result)
        if repairCapitalization {
            result = repairCapitalizationCase(result)
        }
        return result
    }

    // MARK: - Filler removal

    /// Removes fillers together with whatever comma decoration surrounds them.
    ///
    /// Pass order matters, and each pass is anchored so it can only ever consume
    /// a filler plus its own comma — never the surrounding words:
    ///
    ///   ", uh,"  → ", "     both commas present: keep one separator
    ///   "store, erm." → "store."   comma on the left only
    ///   "So um, the" → "So the"    comma on the right only
    ///   "So um the"  → "So the"    bare filler becomes a single space
    ///
    /// NOTE: the negative lookbehind `(?<![\p{L}\p{N}_])` is deliberately *not*
    /// used here — ICU fails to match it when the preceding characters are the
    /// whitespace a leading `\s*` just consumed. The surrounding punctuation is
    /// enough of a boundary for fillers.
    private func removeFillers(in text: String) -> String {
        var result = text

        // Longest fillers first so "uhh" is not eaten by "uh" + leftover "h".
        let fillers = allFillers
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        // Never strip a transcript that *is* just a filler ("Uh.").
        let stripped = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        if allFillers.contains(where: { $0.caseInsensitiveCompare(stripped) == .orderedSame }) {
            return text
        }

        // Build one alternation so every filler is handled in a single pass —
        // repeated per-filler passes were fragile and re-scanned already-fixed text.
        let alternation = fillers
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        // 1. ", uh," → ", "
        result = replacing(#"\s*,\s*(?:\#(alternation))\s*,\s*"#, with: ", ", in: result, caseInsensitive: true)

        // 2. "store, erm." → "store."  (comma on the left only)
        result = replacing(#",\s*(?:\#(alternation))\b"#, with: "", in: result, caseInsensitive: true)

        // 3. "So um, the" → "So the"  (comma on the right only)
        result = replacing(#"\b(?:\#(alternation))\s*,\s*"#, with: "", in: result, caseInsensitive: true)

        // 4. Bare filler → a single space so neighbours never fuse.
        //    `\b` on both sides keeps "umbrella", "humming" and "furious" intact.
        result = replacing(#"\b(?:\#(alternation))\b"#, with: " ", in: result, caseInsensitive: true)

        // 5. Fillers are gone; a comma-dangling comma is debris. Only drop the
        //    comma when removal is what left it dangling — i.e. the result no
        //    longer contains any comma that survived pass 1–3 untouched.
        //    "I went, uh, to the store" → "I went, to the store" → "I went to the store"
        //    "Hmmming is not a word, but humming is" is untouched because its comma
        //    was never adjacent to a filler.
        if commaHadFillerNeighbour(in: text) {
            result = replacing(#",\s+(?=[\p{L}\p{N}])"#, with: " ", in: result)
        }

        return result
    }

    /// True when some comma in `text` has a filler immediately before or after it.
    /// Used to decide whether a dangling comma is debris worth removing.
    private func commaHadFillerNeighbour(in text: String) -> Bool {
        let fillers = allFillers
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        guard !fillers.isEmpty else { return false }
        let alternation = fillers
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let pattern = #"\b(?:\#(alternation))\b\s*,|,\s*\b(?:\#(alternation))\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        return regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: - Punctuation repair

    /// Fixes the debris left behind by filler removal.
    func repairPunctuation(_ text: String) -> String {
        var s = text

        // Collapse doubled punctuation produced by adjacent comma surgery.
        s = replacing(#"\s*,\s*,"#, with: ",", in: s)
        s = replacing(#",\s*(?=[.!?])"#, with: "", in: s)      // "store., yes" → "store, yes"
        s = replacing(#"\s+([,.;:!?])"#, with: "$1", in: s)     // "store ," → "store,"
        s = replacing(#"([.!?])\1{1,}"#, with: "$1", in: s)     // "yes!!" → "yes!"
        s = replacing(#"\s{2,}"#, with: " ", in: s)             // double spaces
        s = replacing(#"^[\s,;:]+"#, with: "", in: s)           // leading debris
        s = replacing(#"\.\s*,"#, with: ".", in: s)             // "yes.," → "yes."

        // Trailing debris ("I went to, ") — strip a dangling comma.
        s = replacing(#",\s*$"#, with: "", in: s)

        return s
    }

    // MARK: - Capitalization repair

    /// Capitalizes the first letter of the text and of every sentence.
    /// Explicitly lowercase-only so it never touches acronyms mid-sentence.
    func repairCapitalizationCase(_ text: String) -> String {
        var s = text
        // Sentence-openers: start of text, or after . ! ? (plus following space).
        guard let regex = try? NSRegularExpression(
            pattern: #"(^|[.!?]\s+)([a-z])"#,
            options: []
        ) else { return s }

        let range = NSRange(s.startIndex..., in: s)
        let matches = regex.matches(in: s, range: range)

        // Rewrite back-to-front so earlier ranges stay valid.
        for match in matches.reversed() {
            guard let letterRange = Range(match.range(at: 2), in: s) else { continue }
            let letter = s[letterRange]
            s.replaceSubrange(letterRange, with: letter.uppercased())
        }
        return s
    }
}

// MARK: - Regex helper

private func replacing(
    _ pattern: String,
    with template: String,
    in text: String,
    caseInsensitive: Bool = false,
    allowSubsequence: Bool = false
) -> String {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
}