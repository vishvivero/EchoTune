//
//  CommitmentExtractor.swift
//  EchoTune
//
//  The offline mining engine behind Echo's task memory.
//
//  Two jobs, both pure functions so they can be unit tested without a UI:
//    1. Mine "I need to X" / "remind me to X" style sentences into commitments.
//    2. Recognise "I sorted X" / "X is done" style sentences as completions of
//       an already-known commitment.
//
//  Matching is token based with light stemming, so "sort" / "sorted" /
//  "sorting" and "passport" / "passports" all compare equal. No embeddings and
//  no model download — this has to work on a plane.
//

import Foundation

/// One commitment mined out of a single sentence.
struct ExtractedCommitment: Equatable {
    let title: String
    let rawSentence: String
    let dueHint: Date?
}

/// A sentence that reports something already being finished.
struct CompletionSignal: Equatable {
    let target: String
    let rawSentence: String
}

enum CommitmentExtractor {

    // MARK: - Sentence splitting

    /// Split dictated text into sentence-ish segments, keeping terminators so a
    /// trailing "?" can rule a segment out as a question.
    static func sentences(in text: String) -> [String] {
        // People chain commitments in one breath: "I need to email the landlord
        // and don't forget to pay the council tax". Break those apart first, but
        // only where a trigger phrase follows the conjunction, so ordinary "and"
        // stays inside the title.
        var prepared = text
        if let splitter = conjunctionSplitter {
            let fullRange = NSRange(prepared.startIndex..<prepared.endIndex, in: prepared)
            prepared = splitter.stringByReplacingMatches(
                in: prepared,
                options: [],
                range: fullRange,
                withTemplate: ". "
            )
        }

        var segments: [String] = []
        var current = ""

        for character in prepared {
            if character == "\n" {
                segments.append(current)
                current = ""
                continue
            }
            current.append(character)
            if character == "." || character == "!" || character == "?" || character == ";" {
                segments.append(current)
                current = ""
            }
        }
        segments.append(current)

        return segments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Mining

    /// Every commitment inside `text`, in the order they were spoken.
    static func extract(from text: String, now: Date = Date(), calendar: Calendar = .current) -> [ExtractedCommitment] {
        var results: [ExtractedCommitment] = []
        var seenTitles = Set<String>()

        for segment in sentences(in: text) {
            guard let mined = extract(fromSentence: segment, now: now, calendar: calendar) else { continue }
            let key = normalizedTitle(mined.title)
            guard !seenTitles.contains(key) else { continue }
            seenTitles.insert(key)
            results.append(mined)
        }
        return results
    }

    /// Mine one sentence, or nil when it isn't a commitment.
    static func extract(fromSentence sentence: String, now: Date = Date(), calendar: Calendar = .current) -> ExtractedCommitment? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return nil }
        // Questions are not commitments.
        guard !trimmed.hasSuffix("?") else { return nil }
        // Quoted speech ("he said I need to go") is somebody else's plan.
        guard !trimmed.hasPrefix("\"") && !trimmed.hasPrefix("'") && !trimmed.hasPrefix("\u{201C}") else { return nil }
        // Second person / interrogative openers.
        guard !startsWithAddressee(trimmed) else { return nil }

        guard var captured = captureTarget(in: trimmed) else { return nil }
        captured = stripFiller(captured)
        guard isActionable(captured) else { return nil }

        let (title, due) = extractDueHint(from: captured, now: now, calendar: calendar)
        let cleaned = normalizedTitle(title)
        guard !cleaned.isEmpty, hasContentToken(cleaned) else { return nil }

        return ExtractedCommitment(title: cleaned, rawSentence: trimmed, dueHint: due)
    }

    /// The action phrase introduced by the sentence, or nil when nothing matched.
    private static func captureTarget(in sentence: String) -> String? {
        for trigger in commitmentTriggers {
            guard let regex = cachedRegex(trigger.pattern) else { continue }
            let range = NSRange(sentence.startIndex..<sentence.endIndex, in: sentence)
            guard let match = regex.firstMatch(in: sentence, options: [], range: range) else { continue }
            // The action phrase is the last capture group.
            let groupIndex = match.numberOfRanges - 1
            guard groupIndex > 0,
                  let groupRange = Range(match.range(at: groupIndex), in: sentence) else { continue }
            let captured = String(sentence[groupRange])
            // Future-tense phrasing doubles as ordinary statements of fact
            // ("I'll be there at six"), so those openers get filtered.
            if trigger.rejectsCopulaOpeners,
               blockedFutureStarts.contains(where: { captured.lowercased().hasPrefix($0) }) {
                continue
            }
            return captured
        }
        return nil
    }

    /// Trim scaffolding that would otherwise end up in the stored title.
    private static func stripFiller(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "-–—:,"))

        var changed = true
        while changed {
            changed = false
            let lower = text.lowercased()
            for prefix in ["to ", "that ", "i ", "we ", "you ", "please ", "just ", "also ", "still ", "now ", "then ", "the ", "my ", "our ", "a ", "an "] {
                if lower.hasPrefix(prefix), text.count > prefix.count {
                    text = String(text.dropFirst(prefix.count))
                    changed = true
                    break
                }
            }
        }

        // Trailing noise that follows the action: "…, please", "… soon", "… at some point".
        for suffix in [" please", " ok", " okay", " at some point", " somehow", " again soon"] {
            while text.lowercased().hasSuffix(suffix) {
                text = String(text.dropLast(suffix.count))
            }
        }

        return text.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-–—"))
    }

    /// Reject fragments that are feelings, opinions or states rather than tasks.
    private static func isActionable(_ text: String) -> Bool {
        let words = tokenize(text)
        guard !words.isEmpty else { return false }
        let lower = text.lowercased()
        for blocked in nonActionPhrases where lower.hasPrefix(blocked) || lower == blocked {
            return false
        }
        let content = words.filter { !stopwords.contains($0) && $0.count > 2 }
        return !content.isEmpty
    }

    // MARK: - Completion signals

    /// Every "I finished X" style signal in `text`.
    static func completions(in text: String) -> [CompletionSignal] {
        var signals: [CompletionSignal] = []
        var seen = Set<String>()

        for segment in sentences(in: text) {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasSuffix("?") else { continue }
            guard !startsWithAddressee(trimmed) else { continue }

            for pattern in completionTriggers {
                guard let regex = cachedRegex(pattern) else { continue }
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else { continue }
                let groupIndex = match.numberOfRanges - 1
                guard groupIndex > 0, let groupRange = Range(match.range(at: groupIndex), in: trimmed) else { continue }
                let target = stripFiller(String(trimmed[groupRange]))
                guard hasContentToken(target) else { continue }
                let key = normalizedTitle(target)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                signals.append(CompletionSignal(target: target, rawSentence: trimmed))
                break
            }
        }
        return signals
    }

    // MARK: - Token matching

    private static let irregularStems: [String: String] = [
        "sent": "send", "paid": "pay", "done": "do", "did": "do", "got": "get",
        "bought": "buy", "made": "make", "wrote": "write", "took": "take",
        "gave": "give", "told": "tell", "sold": "sell", "spent": "spend",
        "found": "find", "left": "leave", "kept": "keep", "held": "hold",
        "sorted": "sort", "renewed": "renew", "booked": "book", "called": "call",
        "submitted": "submit", "cancelled": "cancel", "canceled": "cancel",
        "organised": "organise", "organized": "organize", "arranged": "arrange"
    ]

    /// Normalized matching tokens for a phrase: lowercase, stemmed, deduped,
    /// stopwords dropped. Order is preserved so callers can show the first N.
    static func keywords(in text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tokenize(text) {
            guard !stopwords.contains(raw), raw.count > 1 else { continue }
            let stem = stem(raw)
            guard !stopwords.contains(stem), stem.count > 1 else { continue }
            guard !seen.contains(stem) else { continue }
            seen.insert(stem)
            result.append(stem)
        }
        return result
    }

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Light suffix stripping. Deliberately conservative — prefix matching in
    /// `tokensMatch` carries the rest.
    static func stem(_ word: String) -> String {
        var token = word
        // Possessives: "nila's" -> "nila", "daughters'" -> "daughters"
        while token.hasSuffix("'") || token.hasSuffix("\u{2019}") {
            token = String(token.dropLast())
        }
        if token.hasSuffix("'s") || token.hasSuffix("\u{2019}s") {
            token = String(token.dropLast(2))
        }
        if let mapped = irregularStems[token] { return mapped }
        if token.count > 4, token.hasSuffix("ies") { return String(token.dropLast(3)) + "y" }
        if token.count > 3, token.hasSuffix("es"), !token.hasSuffix("ses") { return String(token.dropLast(2)) }
        if token.count > 4, token.hasSuffix("ing") {
            var base = String(token.dropLast(3))
            if base.count > 2, let last = base.last, let before = base.dropLast().last, last == before, !"aeiou".contains(last) {
                base = String(base.dropLast())
            }
            return base
        }
        if token.count > 3, token.hasSuffix("ed") {
            var base = String(token.dropLast(2))
            if base.count > 2, let last = base.last, let before = base.dropLast().last, last == before, !"aeiou".contains(last) {
                base = String(base.dropLast())
            }
            return base
        }
        if token.count > 3, token.hasSuffix("s"), !token.hasSuffix("ss"), !token.hasSuffix("us"), !token.hasSuffix("is") {
            return String(token.dropLast())
        }
        return token
    }

    /// Equal, or one is a prefix of the other with enough letters to be safe.
    static func tokensMatch(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        let shortest = min(lhs.count, rhs.count)
        guard shortest >= 4 else { return false }
        return lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs)
    }

    /// How much of `needle` is present in `haystack`, 0…1.
    static func overlapScore(needle: [String], haystack: [String]) -> Double {
        guard !needle.isEmpty else { return 0 }
        var matched = 0
        for token in needle {
            if haystack.contains(where: { tokensMatch(token, $0) }) { matched += 1 }
        }
        return Double(matched) / Double(needle.count)
    }

    /// True when at least one matched token is specific enough to be evidence
    /// on its own — "that", "sorted", "next week" alone prove nothing.
    static func hasDistinctiveOverlap(needle: [String], haystack: [String]) -> Bool {
        for token in needle where !genericActionTokens.contains(token) {
            if haystack.contains(where: { tokensMatch(token, $0) }) { return true }
        }
        return false
    }

    /// Best matching commitment for a signal, or nil below the threshold.
    static func bestMatch(for needle: [String], in commitments: [Commitment], minimumScore: Double = 0.6) -> Commitment? {
        rankedMatches(needle: needle, in: commitments, minimumScore: minimumScore).first?.commitment
    }

    /// Commitments that plausibly match `needle`, best first. Ties break on
    /// recency, and a completed match never outranks an open one outright —
    /// the caller decides, this only ranks.
    static func rankedMatches(needle: [String], in commitments: [Commitment], minimumScore: Double = 0.6) -> [(commitment: Commitment, score: Double)] {
        var scored: [(commitment: Commitment, score: Double)] = []

        for commitment in commitments {
            let haystack = commitment.keywords + keywords(in: commitment.title)
            let score = overlapScore(needle: needle, haystack: haystack)
            guard score >= minimumScore, hasDistinctiveOverlap(needle: needle, haystack: haystack) else { continue }
            scored.append((commitment, score))
        }

        return scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.commitment.createdAt > rhs.commitment.createdAt
        }
    }

    // MARK: - Titles

    static func normalizedTitle(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-–—"))
        guard !cleaned.isEmpty else { return "" }
        // Capitalize the first letter, leave the rest of the wording alone.
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private static func hasContentToken(_ text: String) -> Bool {
        keywords(in: text).contains { $0.count > 2 && !genericActionTokens.contains($0) }
    }

    private static func startsWithAddressee(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        for opener in addresseeOpeners where lower.hasPrefix(opener) { return true }
        return false
    }

    // MARK: - Due hints

    /// Pull a time expression out of an action phrase and resolve it to a date.
    /// Returns the phrase with the time words removed plus the resolved day.
    static func extractDueHint(from text: String, now: Date = Date(), calendar: Calendar = .current) -> (title: String, due: Date?) {
        for rule in dueRules {
            guard let regex = cachedRegex(rule.pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  let matchRange = Range(match.range, in: text) else { continue }
            let phrase = String(text[matchRange])
            guard let due = rule.resolve(phrase.lowercased(), now, calendar) else { continue }
            var remainder = text
            remainder.removeSubrange(matchRange)
            remainder = remainder.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            remainder = remainder.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-–—"))
            remainder = remainder.replacingOccurrences(of: "\\s+(by|on|before|due|at|for)$", with: "", options: [.regularExpression, .caseInsensitive])
            return (remainder, due)
        }
        return (text, nil)
    }

    private struct DueRule {
        let pattern: String
        let resolve: (String, Date, Calendar) -> Date?
    }

    private static let weekdayNumbers: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
        "thursday": 5, "friday": 6, "saturday": 7
    ]

    private static let monthNumbers: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12
    ]

    private static let dueRules: [DueRule] = [
        // "by the end of the week", "eod", "eow"
        DueRule(
            pattern: #"\b(?:by|before|on|due|at)?\s*(?:the\s+)?end\s+of\s+(?:the\s+)?(day|week|month)\b|\b(?:eod|eow)\b"#,
            resolve: { phrase, now, calendar in
                if phrase.contains("eod") || phrase.contains("day") { return calendar.startOfDay(for: now) }
                if phrase.contains("eow") || phrase.contains("week") { return endOfWeek(from: now, calendar: calendar) }
                return endOfMonth(from: now, calendar: calendar)
            }
        ),
        // today / tonight / tomorrow
        DueRule(
            pattern: #"\b(?:by|before|on|due|at|for)?\s*(today|tonight|tomorrow|day\s+after\s+tomorrow)\b"#,
            resolve: { phrase, now, calendar in
                if phrase.contains("after tomorrow") { return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 2, to: now) ?? now) }
                if phrase.contains("tomorrow") { return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now) }
                return calendar.startOfDay(for: now)
            }
        ),
        // this / next <unit>
        DueRule(
            pattern: #"\b(?:by|before|on|due|for)?\s*(this|next)\s+(morning|afternoon|evening|week|weekend|month)\b"#,
            resolve: { phrase, now, calendar in
                let isNext = phrase.contains("next")
                if phrase.contains("month") {
                    var anchor = now
                    if isNext, let advanced = calendar.date(byAdding: .month, value: 1, to: now) { anchor = advanced }
                    return endOfMonth(from: anchor, calendar: calendar)
                }
                if phrase.contains("week") {
                    var anchor = now
                    if isNext, let advanced = calendar.date(byAdding: .day, value: 7, to: now) { anchor = advanced }
                    return endOfWeek(from: anchor, calendar: calendar)
                }
                // morning / afternoon / evening — today, or tomorrow when "next" is used
                let base = isNext ? (calendar.date(byAdding: .day, value: 1, to: now) ?? now) : now
                return calendar.startOfDay(for: base)
            }
        ),
        // next Friday / by Monday / on Sunday
        DueRule(
            pattern: #"\b(?:by|before|on|due|next|this|coming)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#,
            resolve: { phrase, now, calendar in
                guard let target = weekdayNumbers.first(where: { phrase.contains($0.key) })?.value else { return nil }
                let forceNext = phrase.contains("next")
                return nextWeekday(target, from: now, forceNextWeek: forceNext, calendar: calendar)
            }
        ),
        // by 12 September
        DueRule(
            pattern: #"\b(?:by|before|on|due)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(january|february|march|april|may|june|july|august|september|october|november|december)\b"#,
            resolve: { phrase, now, calendar in
                var day = 0
                var month = 0
                for token in tokenize(phrase) {
                    if let value = Int(token) { day = value }
                    if let value = monthNumbers[token] { month = value }
                }
                guard day > 0, month > 0 else { return nil }
                var components = calendar.dateComponents([.year], from: now)
                components.month = month
                components.day = day
                guard var date = calendar.date(from: components) else { return nil }
                if date < calendar.startOfDay(for: now), let nextYear = calendar.date(byAdding: .year, value: 1, to: date) {
                    date = nextYear
                }
                return calendar.startOfDay(for: date)
            }
        )
    ]

    static func nextWeekday(_ weekday: Int, from now: Date, forceNextWeek: Bool, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let currentWeekday = calendar.component(.weekday, from: today)
        var delta = (weekday - currentWeekday + 7) % 7
        if forceNextWeek, delta == 0 { delta = 7 }
        guard let target = calendar.date(byAdding: .day, value: delta, to: today) else { return nil }
        return target
    }

    static func endOfWeek(from now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let currentWeekday = calendar.component(.weekday, from: today)
        let delta = (1 - currentWeekday + 7) % 7   // Sunday
        return calendar.date(byAdding: .day, value: delta, to: today) ?? today
    }

    static func endOfMonth(from now: Date, calendar: Calendar = .current) -> Date {
        guard let range = calendar.range(of: .day, in: .month, for: now),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let last = calendar.date(byAdding: .day, value: range.count - 1, to: firstOfMonth) else { return now }
        return calendar.startOfDay(for: last)
    }

    // MARK: - Vocabulary

    private struct Trigger {
        let pattern: String
        var rejectsCopulaOpeners: Bool = false
    }

    /// "… and <trigger phrase>" — the conjunction that joins two commitments.
    private static let conjunctionSplitter: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s+(?:and|plus|,)\s+(?=(?:i\s+(?:really\s+|still\s+|also\s+|just\s+)?(?:need|have|must|should|ought|want|plan|intend)\s+to|i'?ll|i\s+will|remind\s+me|don'?t\s+forget|remember\s+to|make\s+sure|to-?do|add\s+(?:a\s+)?(?:task|reminder)|i\s+need\s|i\s+keep\s+forgetting))"#,
        options: [.caseInsensitive]
    )

    private static let commitmentTriggers: [Trigger] = [
        Trigger(pattern: #"\b(?:i\s+(?:really\s+|still\s+|also\s+|just\s+)?(?:need|have|must|should|ought|want|plan|intend)\s+to)\s+(.+)"#),
        Trigger(pattern: #"\b(?:i\s+keep\s+forgetting\s+to)\s+(.+)"#),
        Trigger(pattern: #"\b(?:i'?ll|i\s+will|i'?m\s+going\s+to|i\s+am\s+going\s+to)\s+(.+)"#, rejectsCopulaOpeners: true),
        Trigger(pattern: #"\bremind\s+me\s+to\s+(.+)"#),
        Trigger(pattern: #"\bdon'?t\s+(?:let\s+me\s+|ever\s+)?forget\s+(?:to\s+)?(.+)"#),
        Trigger(pattern: #"\bremember\s+to\s+(.+)"#),
        Trigger(pattern: #"\bmake\s+sure\s+(?:to\s+|i\s+)?(.+)"#),
        Trigger(pattern: #"\b(?:to-?do|to\s+do|task|action\s+item|reminder)\s*[:\-]\s*(.+)"#),
        Trigger(pattern: #"\badd\s+(?:a\s+)?(?:task|reminder|to-?do)\s+(?:to\s+|for\s+)?(.+)"#),
        Trigger(pattern: #"\bi\s+(?:still\s+)?need\s+(?!to\b)(.{3,})"#)
    ]

    private static let completionTriggers: [String] = [
        #"\b(?:i\s+)?(?:have\s+|i'?ve\s+)?(?:just\s+|already\s+|finally\s+|now\s+)?(?:finished|completed|sorted|sent|paid|booked|submitted|renewed|arranged|organised|organized|updated|cancelled|canceled|picked\s+up|dropped\s+off|took\s+care\s+of|dealt\s+with|wrapped\s+up|checked\s+off|ticked\s+off)\s+(?:with\s+|the\s+|my\s+|our\s+)?(.+)"#,
        #"\b(?:done|finished|completed|sorted|paid|booked|sent|submitted)\s+(?:with\s+)?(?:the\s+|my\s+|our\s+)?(.+)"#,
        #"\b(.+?)\s+(?:is|are|was|were)\s+(?:now\s+|all\s+|finally\s+)?(?:done|finished|sorted|completed|paid|booked|sent|submitted)\b"#,
        #"\bi\s+(?:already\s+)?(?:did|handled|fixed|got)\s+(.+)"#
    ]

    /// Blocked openers for the "I'll …" style triggers, where a future state
    /// ("I'll be there at six") looks like a task and isn't one.
    private static let blockedFutureStarts: [String] = [
        "be ", "be", "have a ", "have an ", "have the ", "see you", "say hi", "miss ",
        "try to be", "let you know if"
    ]

    private static let nonActionPhrases: [String] = [
        "be honest", "be careful", "be nice", "be quiet", "be patient", "be quick",
        "be there", "be back", "be able", "be sure", "be afraid", "be a bit",
        "let you know", "let them know", "let him know", "let her know",
        "let everyone know", "see how it goes", "touch base", "be in touch"
    ]

    /// Openers that mean "somebody else's plan" or "a question", not a commitment.
    private static let addresseeOpeners: [String] = [
        "do you", "did you", "can you", "could you", "would you", "will you",
        "should i", "shall i", "do i", "did i", "have i", "can i", "could i",
        "are you", "is it", "was it", "what if", "how do", "how can", "why did",
        "you need to", "you have to", "you should", "we need to", "we have to",
        "they need to", "he needs to", "she needs to", "he said", "she said",
        "they said"
    ]

    private static let stopwords: Set<String> = [
        "a", "about", "above", "after", "again", "all", "also", "am", "an", "and", "any",
        "are", "as", "at", "be", "because", "been", "before", "being", "below", "between",
        "both", "but", "by", "can", "could", "did", "do", "does", "doing", "don", "down",
        "during", "each", "few", "for", "from", "further", "get", "had", "has", "have",
        "having", "he", "her", "here", "hers", "herself", "him", "himself", "his", "how",
        "i", "if", "in", "into", "is", "it", "its", "itself", "just", "let", "me", "more",
        "most", "must", "my", "myself", "no", "nor", "not", "now", "of", "off", "on",
        "once", "only", "or", "other", "ought", "our", "ours", "ourselves", "out", "over",
        "own", "please", "really", "same", "she", "should", "so", "some", "such", "than",
        "that", "the", "their", "theirs", "them", "themselves", "then", "there", "these",
        "they", "this", "those", "through", "to", "too", "under", "until", "up", "very",
        "was", "we", "were", "what", "when", "where", "which", "while", "who", "whom",
        "why", "will", "with", "would", "you", "your", "yours", "yourself", "yourselves",
        "remind", "need", "needs", "want", "wants", "gonna", "okay", "ok", "yeah", "right"
    ]

    /// Tokens too generic to prove a completion on their own.
    private static let genericActionTokens: Set<String> = [
        "do", "get", "make", "take", "have", "need", "call", "check", "sort", "send",
        "pay", "book", "finish", "complete", "renew", "update", "arrange", "organize",
        "organise", "submit", "cancel", "pick", "drop", "deal", "wrap", "tick", "handle",
        "fix", "thing", "things", "stuff", "something", "anything", "everything",
        "it", "them", "him", "her", "one", "ones", "that", "this", "these", "those",
        "next", "last", "week", "month", "day", "today", "tomorrow", "tonight", "soon",
        "time", "back", "again", "later", "already", "just", "now", "end", "weekend"
    ]

    // MARK: - Regex cache

    private static var regexCache: [String: NSRegularExpression] = [:]
    private static let regexLock = NSLock()

    private static func cachedRegex(_ pattern: String) -> NSRegularExpression? {
        regexLock.lock()
        defer { regexLock.unlock() }
        if let cached = regexCache[pattern] { return cached }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        regexCache[pattern] = regex
        return regex
    }
}
