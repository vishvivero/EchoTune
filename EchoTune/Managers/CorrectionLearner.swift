//
//  CorrectionLearner.swift
//  EchoTune
//
//  Self-learning dictionary (the "Echo remembers" loop):
//  - Watches whenever a dictated text gets corrected (in-app history edits
//    and post-insert read-back in the target app).
//  - Diffs the raw vs. corrected text to find single-word substitutions
//    (e.g. "teem" → "team"), accumulating confidence over repeat corrections.
//  - Surfaces a candidate for one-tap "Teach EchoTune" once it has been seen
//    enough times, persisting it into the existing DictionaryManager so the
//    mistake is never made again — fully offline.
//

import Foundation
import Combine

private let candidatesKey = "correctionCandidatesData"
private let learnedTotalKey = "correctionLearnedTotal"

/// A single candidate word correction waiting to be taught (or dismissed).
struct CorrectionCandidate: Codable, Identifiable, Equatable {
    let id: UUID
    let spoken: String          // what the user said / raw ASR produced
    let written: String         // what they corrected it to
    var count: Int
    var lastSeen: Date

    func matches(_ other: CorrectionCandidate) -> Bool {
        spoken.lowercased() == other.spoken.lowercased()
            && written.lowercased() == other.written.lowercased()
    }
}

class CorrectionLearner: ObservableObject {
    static let shared = CorrectionLearner()

    /// Repeated-correction threshold before we surface a suggestion.
    let suggestionThreshold = 3

    /// Candidates that have crossed the threshold and are ready to teach.
    @Published private(set) var suggestions: [CorrectionCandidate] = []

    /// Running tally of corrections the user has actually taught EchoTune.
    @Published private(set) var learnedTotal: Int = 0

    private var candidates: [CorrectionCandidate] = []
    private var isBusy = false

    private init() {
        load()
    }

    // MARK: - Public API

    /// The main hook: given the text as it existed before a correction, and the
    /// corrected text, extract a single-word substitution and count it.
    func recordCorrection(from oldText: String, to newText: String) {
        guard !isBusy, let pair = diffSingleWordSubstitution(old: oldText, new: newText) else { return }
        // Ignore cosmetic/punctuation-only changes and case-only swaps.
        let spoken = pair.spoken.lowercased()
        let written = pair.written.lowercased()
        guard spoken != written, spoken.count > 1, written.count > 1 else { return }

        // Already in the dictionary? Nothing to learn.
        if alreadyKnown(spoken: spoken, written: written) { return }

        isBusy = true
        defer { isBusy = false }

        let candidate = CorrectionCandidate(id: UUID(), spoken: spoken, written: written, count: 1, lastSeen: Date())
        if let idx = candidates.firstIndex(where: { $0.matches(candidate) }) {
            candidates[idx].count += 1
            candidates[idx].lastSeen = Date()
        } else {
            candidates.append(candidate)
        }
        saveCandidates()
        refreshSuggestions()
    }

    /// Teach a candidate — persist it into the dictionary and forget the hint.
    func teach(_ candidate: CorrectionCandidate) {
        // Best fit: a custom spelling (misspelled variation → correct word).
        DictionaryManager.shared.addSpelling(
            CorrectSpelling(word: candidate.written, variations: [candidate.spoken])
        )
        learnedTotal += 1
        UserDefaults.standard.set(learnedTotal, forKey: learnedTotalKey)
        candidates.removeAll { $0.id == candidate.id }
        saveCandidates()
        refreshSuggestions()
        debugLog("🧠 Learned '\(candidate.spoken)' → '\(candidate.written)' (total \(learnedTotal))")
    }

    /// Dismiss a suggestion without teaching it.
    func dismiss(_ candidate: CorrectionCandidate) {
        candidates.removeAll { $0.id == candidate.id }
        saveCandidates()
        refreshSuggestions()
    }

    // MARK: - Post-Insertion Read-Back

    /// After EchoTune inserts dictated text into another app, wait a few seconds
    /// for the user to fix anything, then read the focused field back and learn
    /// from the correction — the self-improving loop, done silently in-place.
    func scheduleReadBack(afterInserting inserted: String, delay: TimeInterval = 4.0) {
        guard !inserted.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard let current = TextInsertionManager.shared.readFocusedFieldText() else { return }
            // Only learn when the field still plausibly holds our text (the user
            // stayed in the same field and changed something in it).
            let insertedWords = Set(inserted.lowercased().split(whereSeparator: { $0.isWhitespace }))
            let currentWords = Set(current.lowercased().split(whereSeparator: { $0.isWhitespace }))
            guard !insertedWords.isEmpty, !currentWords.isEmpty else { return }
            let overlap = insertedWords.intersection(currentWords).count
            let minCount = min(insertedWords.count, currentWords.count)
            guard Double(overlap) / Double(minCount) >= 0.6 else { return }

            // Only meaningful for short-ish corrections of a similar length.
            let insertedClean = inserted.trimmingCharacters(in: .whitespacesAndNewlines)
            if abs(insertedClean.count - current.count) < max(6, insertedClean.count / 2) {
                self.recordCorrection(from: insertedClean, to: current)
            }
        }
    }

    // MARK: - Diff Engine

    /// Finds a single whole-word substitution between two strings, if one exists.
    /// Forward/backward scan around the common prefix/suffix — sufficient for a
    /// dictation correction ("...the teem project" → "...the team project").
    func diffSingleWordSubstitution(old: String, new: String) -> (spoken: String, written: String)? {
        let a = old.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let b = new.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        var i = 0
        while i < a.count, i < b.count, a[i].lowercased() == b[i].lowercased() {
            i += 1
        }
        var j = a.count
        var k = b.count
        while j > i, k > i, a[j - 1].lowercased() == b[k - 1].lowercased() {
            j -= 1
            k -= 1
        }
        let oldSeg = Array(a[i..<j])
        let newSeg = Array(b[i..<k])
        guard oldSeg.count == 1, newSeg.count == 1 else { return nil }
        var punctuation = CharacterSet.punctuationCharacters
        punctuation.formUnion(.whitespacesAndNewlines)
        let spoken = oldSeg[0].trimmingCharacters(in: punctuation)
        let written = newSeg[0].trimmingCharacters(in: punctuation)
        return (spoken, written)
    }

    // MARK: - Helpers

    private func alreadyKnown(spoken: String, written: String) -> Bool {
        let dict = DictionaryManager.shared
        // Spoken form is a configured replacement shorthand.
        if dict.wordReplacements.contains(where: { $0.spokenForm.lowercased() == spoken }) { return true }
        // Written word is already taught as a spelling with this variation.
        if dict.correctSpellings.contains(where: {
            $0.word.lowercased() == written
                && $0.variations.contains { $0.lowercased() == spoken }
        }) { return true }
        // Already a pending candidate waiting to be taught.
        if candidates.contains(where: {
            $0.spoken.lowercased() == spoken && $0.written.lowercased() == written
        }) { return true }
        return false
    }

    private func refreshSuggestions() {
        let ready = candidates
            .filter { $0.count >= suggestionThreshold }
            .sorted { $0.lastSeen > $1.lastSeen }
        if ready != suggestions {
            suggestions = ready
        }
    }

    // MARK: - Persistence

    private func load() {
        learnedTotal = UserDefaults.standard.integer(forKey: learnedTotalKey)
        if let data = UserDefaults.standard.data(forKey: candidatesKey),
           let decoded = try? JSONDecoder().decode([CorrectionCandidate].self, from: data) {
            candidates = decoded
        }
        refreshSuggestions()
    }

    private func saveCandidates() {
        if let data = try? JSONEncoder().encode(candidates) {
            UserDefaults.standard.set(data, forKey: candidatesKey)
        }
    }
}
