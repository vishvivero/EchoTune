//
//  PhoneticVocabularyMatcher.swift
//  EchoTune
//
//  ET-757 · Offline phonetic vocabulary matching for ASR mishearings.
//
//  WHY THIS EXISTS
//  ---------------
//  Whisper-class models mishear rare proper nouns ("EchoTune" → "echo tune" /
//  "ekotune" / "eco tune"), and passing vocabulary into the decoder's
//  `promptTokens` is forbidden — it produced empty transcripts (fixed in 7.4.7).
//  So correction has to happen *after* transcription, on the text itself:
//
//    1. Exact / variation matching .......... DictionaryManager.applySpellings
//    2. Phonetic + fuzzy span matching ...... this file
//
//  Matching operates on 1–3 word contiguous spans, scored by
//    · consonant-skeleton equality (echo tune → ekotun == EchoTune → ektun)?
//    · character trigram Jaccard similarity
//    · normalized Levenshtein distance
//  and is refused when the span is (or overlaps) an English stopword, so ordinary
//  prose is never rewritten.
//

import Foundation

// MARK: - Phonetic encoding

enum PhoneticEncoder {
    /// Collapses English spelling into a consonant-ish skeleton so that
    /// "echo" / "eco" / "ekho" and "whisper" / "wisper" land on the same string.
    static func skeleton(_ word: String) -> String {
        var s = word.lowercased()
        guard !s.isEmpty else { return "" }

        // Diacritics and folding first so "Kübérnetes" folds cleanly.
        s = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))

        // Multi-letter digraphs, longest first.
        let digraphs: [(String, String)] = [
            ("tch", "ch"),
            ("sch", "sk"),
            ("ph", "f"),
            ("ck", "k"),
            ("qu", "k"),
            ("kn", "n"),
            ("gn", "n"),
            ("wr", "r"),
            ("wh", "w"),
            ("gh", "g"),
            ("th", "t"),
            ("sh", "s"),
            ("ch", "c"),
            ("zh", "j"),
            ("ee", "i"),
            ("ea", "i"),
            ("ie", "i"),
            ("oa", "o"),
            ("oo", "u"),
            ("ou", "u"),
            ("ow", "o"),
            ("au", "o"),
            ("aw", "o"),
            ("ai", "e"),
            ("ay", "e")
        ]
        for (from, to) in digraphs {
            s = s.replacingOccurrences(of: from, with: to)
        }

        // Single-letter normalization.
        var mapped = ""
        for ch in s {
            switch ch {
            case "c": mapped.append("k")   // echo → eko, cat → kat
            case "x": mapped.append("ks")
            case "z": mapped.append("s")
            case "y": mapped.append("i")
            case "v": mapped.append("f")
            case "a", "e", "i", "o", "u", "h", "w", "y": mapped.append(ch)
            default:
                if ch.isLetter || ch.isNumber { mapped.append(ch) }
            }
        }

        // Drop vowels after the first character — consonants carry the identity,
        // the leading vowel keeps "eco"/"iko" distinct from "ku".
        var out = ""
        for (idx, ch) in mapped.enumerated() {
            let isVowelLike = (ch == "a" || ch == "e" || ch == "i" || ch == "o" || ch == "u")
            if idx > 0 && isVowelLike { continue }
            out.append(ch)
        }

        // Collapse runs of identical consonants ("tt" → "t", "ss" → "s").
        var collapsed = ""
        for ch in out where collapsed.last != ch { collapsed.append(ch) }
        return collapsed
    }
}

extension PhoneticEncoder {
    /// Compact ("Echo Tune" → "echotune") skeleton with compound vowels reduced.
    /// Used only when matching multi-word spans against multi-word terms, where
    /// over-reduction cannot collide with ordinary single words.
    static func compactReducedKey(_ term: String) -> String {
        var s = term.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber }
        for (from, to) in [("oo", "u"), ("ou", "u"), ("ue", "u"), ("ew", "u"), ("oa", "o"),
                           ("ee", "i"), ("ea", "i"), ("ie", "i"), ("ay", "e"), ("ai", "e")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return s
    }
}

// MARK: - Similarity metrics

enum StringSimilarity {
    /// Character-trigram Jaccard similarity in 0...1.
    static func trigramJaccard(_ a: String, _ b: String) -> Double {
        let ta = trigrams(a), tb = trigrams(b)
        if ta.isEmpty || tb.isEmpty { return a == b ? 1 : 0 }
        let inter = Double(ta.intersection(tb).count)
        let union = Double(ta.union(tb).count)
        guard union > 0 else { return 0 }
        return inter / union
    }

    static func trigrams(_ s: String) -> Set<String> {
        let chars = Array(s.lowercased())
        guard chars.count >= 3 else { return chars.isEmpty ? [] : [String(chars)] }
        var set = Set<String>()
        for i in 0...(chars.count - 3) {
            set.insert(String(chars[i...i + 2]))
        }
        return set
    }

    /// Normalized Levenshtein distance in 0...1 (1 = identical).
    static func normalizedLevenshtein(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty && y.isEmpty { return 1 }
        if x.isEmpty || y.isEmpty { return 0 }
        var prev = Array(0...y.count)
        var cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        let dist = Double(prev[y.count])
        return 1 - (dist / Double(max(x.count, y.count)))
    }
}

// MARK: - Matcher

/// Post-transcription corrector for phonetically misheard proper nouns.
///
/// Pure `Sendable` value type: rebuild it whenever the dictionary changes and
/// call `apply(to:)` under the same lock/actor that owns the transcript.
struct PhoneticVocabularyMatcher {

    struct Term {
        let replacement: String
        let skeleton: String
        let wordCount: Int
        /// Pre-lowered written form, used to avoid re-replacing inside itself.
        let lowercasedReplacement: String
        /// Space-free skeleton with compound vowels reduced, so ASR variants of
        /// the same sound ("tune"/"toon", "kit"/"keet") compare equal.
        let compactReduced: String
        /// True when the written form is a multi-word compound ("EchoTune",
        /// "WhisperKit", "Kubernetes"), i.e. ASR may emit it as 2–3 words.
        let isCompound: Bool
    }

    /// Splits a bare-infix camel compound into its words ("EchoTune" → ["Echo",
    /// "Tune"]). Explicit space/hyphen separated terms split on those.
    static func words(of term: String) -> [String] {
        var parts: [String] = []
        for chunk in term.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" }) {
            parts.append(contentsOf: splitCamel(String(chunk)))
        }
        return parts
    }

    private static func splitCamel(_ s: String) -> [String] {
        var out: [String] = []
        var current = ""
        let chars = Array(s)
        for (i, ch) in chars.enumerated() {
            if i > 0, ch.isUppercase, chars[i - 1].isLowercase {
                if !current.isEmpty { out.append(current) }
                current = ""
            }
            current.append(ch)
        }
        if !current.isEmpty { out.append(current) }
        return out.isEmpty ? [s] : out
    }

    /// Words we never rewrite, and never let a fuzzy span swallow.
    static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "if", "then", "than", "so", "as", "at",
        "by", "for", "from", "in", "into", "of", "on", "onto", "to", "with", "without",
        "is", "are", "was", "were", "be", "been", "being", "am", "do", "does", "did",
        "have", "has", "had", "will", "would", "can", "could", "should", "may", "might",
        "must", "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us",
        "them", "my", "your", "his", "its", "our", "their", "this", "that", "these",
        "those", "there", "here", "not", "no", "yes", "just", "very", "also", "all",
        "any", "some", "more", "most", "other", "such", "only", "own", "same", "too",
        "now", "how", "what", "when", "where", "who", "why", "which", "up", "down",
        "out", "off", "over", "under", "again", "once", "about", "after", "before",
        "because", "while", "during", "through", "between", "against", "above", "below"
    ]

    /// Minimum combined score required for a fuzzy replacement.
    /// Measured against the AC set: "ekotune"→EchoTune scores 0.76 (accepted),
    /// the best ordinary-prose false positive ("tune" vs EchoTune) scores 0.37.
    var minimumScore: Double = 0.70
    /// Minimum Levenshtein similarity, so phonetics alone can't rewrite nonsense.
    var minimumLevenshtein: Double = 0.62
    let terms: [Term]

    init(correctSpellings: [CorrectSpelling], minimumScore: Double = 0.70) {
        self.minimumScore = minimumScore
        self.terms = correctSpellings
            .filter { $0.isEnabled && $0.word.count >= 3 }
            .map { spelling in
                Term(
                    replacement: spelling.word,
                    skeleton: PhoneticEncoder.skeleton(spelling.word),
                    wordCount: max(1, Self.words(of: spelling.word).count),
                    lowercasedReplacement: spelling.word.lowercased(),
                    compactReduced: PhoneticEncoder.compactReducedKey(spelling.word),
                    isCompound: Self.words(of: spelling.word).count > 1
                )
            }
    }

    var isEmpty: Bool { terms.isEmpty }

    // MARK: Application

    /// Rewrites phonetically-similar spans in `text`. Ordinary prose is untouched.
    func apply(to text: String) -> String {
        guard !terms.isEmpty, !text.isEmpty else { return text }

        // Tokenize into word runs and the separators between them:
        //   separators.count == tokens.count + 1
        // (leading separator, then one per token, plus the trailing remainder).
        var tokens: [String] = []
        var separators: [String] = []
        var i = text.startIndex
        var pending = ""
        tokenize: while i < text.endIndex {
            var j = i
            while j < text.endIndex, !isWordChar(text[j]) { j = text.index(after: j) }
            pending += String(text[i..<j])
            if j >= text.endIndex {
                i = j
                break tokenize
            }
            var k = j
            while k < text.endIndex, isWordChar(text[k]) { k = text.index(after: k) }
            separators.append(pending)
            pending = ""
            tokens.append(String(text[j..<k]))
            i = k
        }
        separators.append(pending)

        guard !tokens.isEmpty else { return text }
        guard separators.count == tokens.count + 1 else { return text }

        let lowered = tokens.map { $0.lowercased() }

        // Does this word already look like one of our target terms?
        func isAlreadyCorrect(_ idx: Int) -> Bool {
            let w = lowered[idx]
            // "echotune" or the word inside a multi-word term like "kubernetes".
            if terms.contains(where: { $0.lowercasedReplacement.contains(w) && w.count >= 4 }) {
                return true
            }
            return false
        }

        var result = separators[0]
        var idx = 0

        while idx < lowered.count {
            var matched = false

            // Try the longest span first (3 → 1 words).
            for span in stride(from: min(3, lowered.count - idx), through: 1, by: -1) {
                let words = Array(lowered[idx..<(idx + span)])

                // Never touch stopword-only spans.
                if words.allSatisfy({ Self.stopwords.contains($0) }) { continue }
                // A span must contain at least one substantial word.
                guard words.contains(where: { $0.count >= 3 }) else { continue }
                // Never let a span *end* on a stopword: "echo tune now" must stop
                // at "tune", otherwise the trailing "now" is silently deleted.
                if span > 1, let last = words.last, Self.stopwords.contains(last) { continue }
                // A span must not begin on a stopword either.
                if span > 1, let first = words.first, Self.stopwords.contains(first) { continue }
                // Skip spans already spelled correctly.
                if span == 1 && isAlreadyCorrect(idx) { continue }

                // Join with a single space so multi-token spans stay word-shaped
                // ("echo tune"); compact keys strip it again where needed.
                let joined = words.joined(separator: " ")
                let joinedSkeleton = PhoneticEncoder.skeleton(words.joined())

                let best = bestTerm(for: joined, skeleton: joinedSkeleton, words: words)
                guard let best else { continue }

                // Rebuild: separator before the span, then the fix.
                result += separators[idx]
                result += best.replacement
                idx += span
                matched = true
                break
            }

            if !matched {
                // No replacement — replay the original token verbatim.
                result += separators[idx] + tokens[idx]
                idx += 1
            }
        }

        // Trailing separator after the last token.
        result += separators[tokens.count]
        return result
    }

    private func bestTerm(for joined: String, skeleton: String, words: [String]) -> Term? {
        var best: (Term, Double)?
        for term in terms {
            // Reject a rewrite that is a no-op (already correct).
            if term.lowercasedReplacement == joined { continue }

            // A span of N words may only replace a term of N±1 words, and a
            // 1-word term must not swallow 3 words of ordinary prose.
            if abs(term.wordCount - words.count) > 1 { continue }

            // "echo tune" → "EchoTune": ASR split a compound proper noun. Spaces
            // and compound-vowel spelling are the only difference, so compare the
            // reduced compact keys and require a near-exact match. This path is
            // deliberately strict — it exists for compounds, not for fuzzy prose.
            let spanCompact = PhoneticEncoder.compactReducedKey(joined)
            if term.isCompound, words.count >= 2, words.count == term.wordCount,
               !spanCompact.isEmpty,
               spanCompact == term.compactReduced {
                let score = 1.0
                if let current = best, current.1 >= score { continue }
                best = (term, score)
                continue
            }

            // Fuzzy path: a single misheard word ("ekotune", "kubernetis").
            let compactTerm = term.lowercasedReplacement.replacingOccurrences(of: " ", with: "")
            let compactSpan = joined.replacingOccurrences(of: " ", with: "")
            guard !compactTerm.isEmpty, !compactSpan.isEmpty else { continue }

            // Length guard: refuse rewrites where one side is less than half the
            // other, which is what stops short fragments rewriting real words.
            let shorter = Double(min(compactTerm.count, compactSpan.count))
            let longer = Double(max(compactTerm.count, compactSpan.count))
            guard longer > 0, (shorter / longer) >= 0.6 else { continue }

            let lev = StringSimilarity.normalizedLevenshtein(compactSpan, compactTerm)
            let tri = StringSimilarity.trigramJaccard(compactSpan, compactTerm)
            let skelBonus = (skeleton == term.skeleton && !term.skeleton.isEmpty) ? 0.25 : 0.0
            let score = (lev * 0.5) + (tri * 0.35) + skelBonus

            guard lev >= minimumLevenshtein, score >= minimumScore else { continue }
            if let current = best, current.1 >= score { continue }
            best = (term, score)
        }
        return best?.0
    }

    private func isWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_" || c == "'" || c == "-" || c == "’"
    }
}

// MARK: - Tokenizer helper shared with tests

extension PhoneticVocabularyMatcher {
    /// Exposed for tests: the consonant skeleton for a word.
    static func skeleton(_ word: String) -> String { PhoneticEncoder.skeleton(word) }
}