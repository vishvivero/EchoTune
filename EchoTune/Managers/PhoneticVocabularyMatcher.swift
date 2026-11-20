//
//  PhoneticVocabularyMatcher.swift
//  EchoTune
//
//  Offline phonetic + character n-gram vocabulary matcher inspired by VoiceInk.
//  Catches misheard proper nouns and technical terms (e.g. "echo tune",
//  "ekotune", "katoon" → "EchoTune", "whisper kit" → "WhisperKit") without
//  decoder prompt conditioning, while guarding common English words from
//  false positives.
//

import Foundation

struct PhoneticVocabularyMatcher: Sendable {
    private struct IndexedTerm: Sendable {
        let canonical: String
        let normalizedKey: String
        let phoneticKey: String
        let trigrams: Set<String>
        let wordCount: Int
    }

    private struct TokenSpan {
        let nsRange: NSRange
        let raw: String
        let normalized: String
    }

    private let terms: [IndexedTerm]
    private let exactKnownKeys: Set<String>
    private let maxWordSpan: Int

    /// Common English words that must never be phonetically rewritten as single-word matches.
    private static let protectedStopwords: Set<String> = [
        "about", "above", "after", "again", "against", "almost", "along", "already", "always",
        "another", "around", "because", "before", "behind", "being", "below", "between", "both",
        "bring", "build", "built", "called", "cannot", "change", "check", "children", "close",
        "cloud", "comes", "coming", "could", "course", "create", "current", "different", "doing",
        "during", "early", "either", "enough", "every", "example", "family", "father", "first",
        "found", "friend", "going", "great", "group", "having", "house", "however", "important",
        "include", "inside", "instead", "later", "large", "learn", "leave", "letter", "light",
        "little", "local", "looking", "making", "matter", "maybe", "means", "might", "money",
        "morning", "mother", "music", "never", "night", "nothing", "number", "often", "order",
        "other", "others", "paper", "people", "person", "place", "point", "power", "present",
        "problem", "program", "public", "question", "quick", "quite", "rather", "ready", "really",
        "reason", "right", "running", "school", "second", "several", "should", "since", "small",
        "something", "sometimes", "sound", "start", "state", "still", "story", "study", "system",
        "table", "taken", "taking", "their", "there", "these", "thing", "things", "think",
        "those", "though", "three", "through", "today", "together", "under", "until", "using",
        "value", "voice", "water", "where", "which", "while", "without", "words", "world",
        "would", "write", "years", "young"
    ]

    init(terms rawTerms: [String]) {
        var built: [IndexedTerm] = []
        var exact = Set<String>()
        var longestSpan = 1

        for raw in rawTerms {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = Self.normalizeLettersAndDigits(trimmed)
            guard key.count >= 5, !exact.contains(key) else { continue }
            exact.insert(key)

            let words = trimmed.split(whereSeparator: \.isWhitespace)
            let span = max(1, min(3, words.count + 1)) // e.g. "EchoTune" can match 2-word "echo tune"
            longestSpan = max(longestSpan, span)

            built.append(IndexedTerm(
                canonical: trimmed,
                normalizedKey: key,
                phoneticKey: Self.phoneticCode(for: key),
                trigrams: Self.trigrams(for: key),
                wordCount: max(1, words.count)
            ))
        }

        self.terms = built
        self.exactKnownKeys = exact
        self.maxWordSpan = min(3, longestSpan)
    }

    func apply(to text: String) -> String {
        guard !terms.isEmpty, !text.isEmpty else { return text }

        let tokens = Self.tokenizeWords(in: text)
        guard !tokens.isEmpty else { return text }

        var replacements: [(range: NSRange, text: String)] = []
        var index = 0

        while index < tokens.count {
            var bestMatch: (endIndex: Int, range: NSRange, replacement: String, score: Double)?

            let maxEnd = min(tokens.count - 1, index + maxWordSpan - 1)
            for endIdx in stride(from: maxEnd, through: index, by: -1) {
                let spanCount = endIdx - index + 1
                // Ensure tokens are separated only by plain spaces (not punctuation/newlines)
                if spanCount > 1 && !Self.areContiguousWords(in: text, from: tokens[index].nsRange, to: tokens[endIdx].nsRange) {
                    continue
                }

                let combinedNorm = (index...endIdx).map { tokens[$0].normalized }.joined()
                guard combinedNorm.count >= 5 else { continue }

                if spanCount == 1 && Self.protectedStopwords.contains(combinedNorm) {
                    continue
                }

                let fullRange = NSUnionRange(tokens[index].nsRange, tokens[endIdx].nsRange)
                let originalSlice = (text as NSString).substring(with: fullRange)

                let candidatePhone = Self.phoneticCode(for: combinedNorm)
                let candidateGrams = Self.trigrams(for: combinedNorm)

                for term in terms {
                    // Skip if text already exactly matches canonical casing
                    if originalSlice == term.canonical { continue }

                    // Exact joined letters (e.g. "echo tune" -> "EchoTune" or "echotune" -> "EchoTune")
                    if combinedNorm == term.normalizedKey {
                        bestMatch = (endIdx, fullRange, term.canonical, 0.0)
                        break
                    }

                    // Length ratio guard
                    let maxLen = Double(max(combinedNorm.count, term.normalizedKey.count))
                    let lenDiff = Double(abs(combinedNorm.count - term.normalizedKey.count))
                    if lenDiff / maxLen > 0.34 { continue }

                    let phoneDist = Self.normalizedEditDistance(candidatePhone, term.phoneticKey)
                    guard phoneDist <= 0.30 else { continue }

                    let charDist = Self.normalizedEditDistance(combinedNorm, term.normalizedKey)
                    let gramDist = 1.0 - Self.jaccard(candidateGrams, term.trigrams)
                    let composite = (phoneDist * 0.45) + (charDist * 0.40) + (gramDist * 0.15)

                    let threshold = spanCount > 1 ? 0.25 : 0.24
                    if composite <= threshold {
                        if bestMatch == nil || composite < bestMatch!.score {
                            bestMatch = (endIdx, fullRange, term.canonical, composite)
                        }
                    }
                }

                if let found = bestMatch, found.score == 0.0 {
                    break
                }
            }

            if let winner = bestMatch {
                replacements.append((winner.range, winner.replacement))
                index = winner.endIndex + 1
            } else {
                index += 1
            }
        }

        guard !replacements.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for edit in replacements.reversed() {
            mutable.replaceCharacters(in: edit.range, with: edit.text)
        }
        return mutable as String
    }

    // MARK: - Tokenization & Phonetics

    private static func tokenizeWords(in text: String) -> [TokenSpan] {
        guard let regex = try? NSRegularExpression(pattern: "[\\p{L}\\p{N}]+", options: []) else {
            return []
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.map { match in
            let raw = nsText.substring(with: match.range)
            return TokenSpan(
                nsRange: match.range,
                raw: raw,
                normalized: normalizeLettersAndDigits(raw)
            )
        }
    }

    private static func areContiguousWords(in text: String, from first: NSRange, to last: NSRange) -> Bool {
        let betweenStart = first.location + first.length
        let betweenLength = last.location - betweenStart
        guard betweenLength > 0 && betweenLength <= 3 else { return false }
        let gap = (text as NSString).substring(with: NSRange(location: betweenStart, length: betweenLength))
        return gap.allSatisfy { $0 == " " || $0 == "-" }
    }

    static func normalizeLettersAndDigits(_ input: String) -> String {
        let folded = input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return String(folded.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        })
    }

    /// Lightweight Metaphone-inspired consonant skeleton for English/technical ASR confusions.
    static func phoneticCode(for normalized: String) -> String {
        guard !normalized.isEmpty else { return "" }
        var s = normalized
        let digraphs: [(String, String)] = [
            ("ph", "f"), ("ck", "k"), ("chr", "kr"), ("ech", "ek"),
            ("tech", "tek"), ("ch", "x"), ("sh", "x"),
            ("th", "0"), ("gh", "g"), ("kn", "n"), ("wr", "r"),
            ("wh", "w"), ("qu", "kw"), ("dg", "j"), ("tch", "x")
        ]
        for (src, dst) in digraphs {
            s = s.replacingOccurrences(of: src, with: dst)
        }

        let chars = Array(s)
        var out: [Character] = []
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]

        for (i, ch) in chars.enumerated() {
            let mapped: Character?
            switch ch {
            case "c":
                if i + 1 < chars.count && ["e", "i", "y"].contains(chars[i + 1]) {
                    mapped = "s"
                } else {
                    mapped = "k"
                }
            case "z":
                mapped = "s"
            case "v":
                mapped = "f"
            case "d":
                mapped = "t"
            case "b":
                mapped = "p"
            case _ where vowels.contains(ch):
                // Keep initial vowel marker so vowel-led words stay distinct from consonant-led words
                mapped = (i == 0) ? "a" : nil
            default:
                mapped = ch
            }

            if let m = mapped, out.last != m {
                out.append(m)
            }
        }
        return String(out)
    }

    private static func trigrams(for key: String) -> Set<String> {
        let padded = "^\(key)$"
        let chars = Array(padded)
        guard chars.count >= 3 else { return [padded] }
        var set = Set<String>()
        for i in 0...(chars.count - 3) {
            set.insert(String(chars[i..<(i + 3)]))
        }
        return set
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1.0 }
        let inter = Double(a.intersection(b).count)
        let uni = Double(a.union(b).count)
        return uni > 0 ? inter / uni : 0.0
    }

    private static func normalizedEditDistance(_ a: String, _ b: String) -> Double {
        if a == b { return 0.0 }
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        guard max(m, n) > 0 else { return 0.0 }
        if m == 0 || n == 0 { return 1.0 }

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = (aChars[i - 1] == bChars[j - 1]) ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            swap(&prev, &curr)
        }
        return Double(prev[n]) / Double(max(m, n))
    }
}
