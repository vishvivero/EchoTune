//
//  CommitmentMemoryManager.swift
//  EchoTune
//
//  Echo's offline task memory. Every dictated sentence is scanned locally for
//  two things: something the user committed to doing, and a report that
//  something is now done. Both are matched by keyword, so the user can ask
//  "did I sort Nila's passport?" and get an answer with the receipt attached.
//
//  Storage is a single JSON blob in UserDefaults, matching EchoMemoryManager.
//  Nothing is uploaded and no model is required.
//

import Foundation
import Combine

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private let commitmentsKey = "commitmentMemoryData"
private let backfillKey = "commitmentBackfillVersion"
private let currentBackfillVersion = 1
/// Ceiling on stored commitments; finished ones are pruned first.
private let maximumStoredCommitments = 600

final class CommitmentMemoryManager: ObservableObject {
    static let shared = CommitmentMemoryManager()

    /// Newest first, exactly as stored.
    @Published private(set) var commitments: [Commitment] = []
    /// Set when an ingest produced something worth telling the user about.
    @Published private(set) var lastIngest: CommitmentIngestSummary?
    /// Transient proposals are never encoded. They disappear on dismissal or restart.
    @Published private(set) var pendingProposals: [CommitmentProposal] = []
    var proposals: [CommitmentProposal] { pendingProposals }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Reads

    var openCommitments: [Commitment] {
        commitments.filter { $0.status == .open }
    }

    var completedCommitments: [Commitment] {
        commitments.filter { $0.status == .completed }
    }

    var openCount: Int { openCommitments.count }

    /// Commitments whose due hint is today or already past.
    var dueToday: [Commitment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return openCommitments.filter { commitment in
            guard let due = commitment.dueHint else { return false }
            return calendar.startOfDay(for: due) <= today
        }
    }

    /// The open commitment created most recently — used by the coach and by
    /// "what did I say I'd do?" style prompts.
    var mostRecentOpen: Commitment? {
        openCommitments.max(by: { $0.createdAt < $1.createdAt })
    }

    // MARK: - Proposal flow

    func propose(text: String, sourceEntryID: UUID? = nil, date: Date = Date(), calendar: Calendar = .current) {
        let newProposals = CommitmentExtractor.proposals(from: text, now: date, calendar: calendar).map { p in
            CommitmentProposal(id: p.id, task: p.task, person: p.person, context: p.context,
                               dueDate: p.dueDate, priority: p.priority, confidence: p.confidence,
                               sourceSentence: p.sourceSentence, sourceEntryID: sourceEntryID, proposedAt: date)
        }
        for proposal in newProposals {
            let key = proposalKey(proposal.task)
            guard !key.isEmpty,
                  !pendingProposals.contains(where: { proposalKey($0.task) == key || $0.sourceSentence == proposal.sourceSentence }),
                  !commitments.contains(where: { $0.status == .open && proposalKey($0.title) == key }) else { continue }
            pendingProposals.append(proposal)
        }
    }

    func updateProposal(_ proposal: CommitmentProposal) {
        guard let index = pendingProposals.firstIndex(where: { $0.id == proposal.id }) else { return }
        pendingProposals[index] = proposal
    }

    func dismissProposal(id: UUID) {
        pendingProposals.removeAll { $0.id == id }
    }

    private func proposalKey(_ text: String) -> String {
        CommitmentExtractor.keywords(in: text).joined(separator: " ")
    }

    @discardableResult
    func acceptProposal(_ proposal: CommitmentProposal, date: Date = Date()) -> Commitment? {
        guard pendingProposals.contains(where: { $0.id == proposal.id }) else { return nil }
        let current = proposal
        let cleaned = CommitmentExtractor.normalizedTitle(current.task)
        let keywords = CommitmentExtractor.keywords(in: cleaned)
        guard !cleaned.isEmpty, !keywords.isEmpty else { dismissProposal(id: proposal.id); return nil }
        if let existing = commitments.first(where: { $0.status == .open && proposalKey($0.title) == proposalKey(cleaned) }) {
            dismissProposal(id: current.id)
            return existing
        }
        let commitment = Commitment(title: cleaned, rawSentence: current.sourceSentence, createdAt: date,
                                    lastMentionedAt: date, dueHint: current.dueDate,
                                    keywords: keywords, person: current.person.nilIfEmpty,
                                    context: current.context.nilIfEmpty, priority: current.priority,
                                    confidence: min(max(current.confidence, 0), 1), sourceEntryID: current.sourceEntryID)
        commitments.insert(commitment, at: 0)
        pruneIfNeeded()
        save()
        pendingProposals.removeAll { $0.id == proposal.id }
        lastIngest = CommitmentIngestSummary(added: [commitment])
        return commitment
    }

    // MARK: - Ingest

    @discardableResult
    func ingest(text: String, sourceEntryID: UUID? = nil, date: Date = Date()) -> CommitmentIngestSummary {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return CommitmentIngestSummary() }

        var summary = CommitmentIngestSummary()

        // Snapshot first: a completion can only close something Echo already
        // knew about, never a commitment spoken in the same breath.
        let known = openCommitments

        let extracted = CommitmentExtractor.extract(from: trimmed, now: date)
        let extractedSentences = Set(extracted.map { $0.rawSentence })

        for signal in CommitmentExtractor.completions(in: trimmed) where !extractedSentences.contains(signal.rawSentence) {
            let needle = CommitmentExtractor.keywords(in: signal.target)
            guard !needle.isEmpty,
                  let match = CommitmentExtractor.bestMatch(for: needle, in: known),
                  let index = commitments.firstIndex(where: { $0.id == match.id }),
                  commitments[index].status == .open else { continue }
            commitments[index].status = .completed
            commitments[index].completedAt = date
            commitments[index].completionSentence = signal.rawSentence
            summary.completed.append(commitments[index])
        }

        for item in extracted {
            let needle = CommitmentExtractor.keywords(in: item.title)
            // Same task said twice: refresh the existing record instead of
            // littering the list with duplicates.
            if let existing = CommitmentExtractor.bestMatch(for: needle, in: openCommitments, minimumScore: 0.75),
               let index = commitments.firstIndex(where: { $0.id == existing.id }) {
                commitments[index].lastMentionedAt = date
                if commitments[index].dueHint == nil, let due = item.dueHint {
                    commitments[index].dueHint = due
                }
                continue
            }

            let commitment = Commitment(
                title: item.title,
                rawSentence: item.rawSentence,
                createdAt: date,
                lastMentionedAt: date,
                dueHint: item.dueHint,
                keywords: needle,
                sourceEntryID: sourceEntryID
            )
            commitments.insert(commitment, at: 0)
            summary.added.append(commitment)
        }

        guard !summary.isEmpty else { return summary }

        pruneIfNeeded()
        save()
        lastIngest = summary
        return summary
    }

    /// Mine the transcripts Echo already stored, once, so existing users get
    /// their task memory populated from day one of the upgrade.
    /// Historical transcripts are never mined. This compatibility API is
    /// intentionally side-effect free; only finalized local callbacks propose.
    func backfillIfNeeded(from entries: [EchoMemoryEntry]) {
        // Do not replay history or write migration markers.
    }

    // MARK: - Asking

    /// Answer a question like "did I sort Nila's passport?" from local memory.
    func answer(_ query: String) -> CommitmentAnswer {
        let subject = Self.querySubject(from: query)
        let needle = CommitmentExtractor.keywords(in: subject)

        guard !needle.isEmpty else {
            return CommitmentAnswer(
                query: query,
                verdict: .unknown,
                headline: "Nothing to look up there yet — ask me about a task, like “did I renew the car insurance?”",
                matches: []
            )
        }

        let matches = CommitmentExtractor.rankedMatches(needle: needle, in: commitments, minimumScore: 0.5)
        guard let best = matches.first else {
            return CommitmentAnswer(
                query: query,
                verdict: .unknown,
                headline: "No record of that yet. Tasks show up here once you say something like “I need to…” out loud.",
                matches: []
            )
        }

        let formatter = Self.dayFormatter
        switch best.commitment.status {
        case .completed:
            let when = best.commitment.completedAt.map { " on \(formatter.string(from: $0))" } ?? ""
            return CommitmentAnswer(
                query: query,
                verdict: .completed,
                headline: "Yes — “\(best.commitment.title)” was marked done\(when).",
                matches: matches.map { $0.commitment }
            )
        case .open:
            let when = " (added \(formatter.string(from: best.commitment.createdAt)))"
            let due = best.commitment.dueHint.map { " Due \(formatter.string(from: $0))." } ?? ""
            return CommitmentAnswer(
                query: query,
                verdict: .open,
                headline: "Not yet — “\(best.commitment.title)” is still open\(when).\(due)",
                matches: matches.map { $0.commitment }
            )
        case .dismissed:
            return CommitmentAnswer(
                query: query,
                verdict: .open,
                headline: "“\(best.commitment.title)” was dismissed from your list.",
                matches: matches.map { $0.commitment }
            )
        }
    }

    /// Free-text search for the list UI.
    func search(_ query: String) -> [Commitment] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return commitments }
        let needle = CommitmentExtractor.keywords(in: trimmed)
        guard !needle.isEmpty else { return commitments }
        let ranked = CommitmentExtractor.rankedMatches(needle: needle, in: commitments, minimumScore: 0.34)
        return ranked.map { $0.commitment }
    }

    /// Strip the question scaffolding so "did I sort the passport" becomes
    /// "sort the passport" before matching.
    static func querySubject(from query: String) -> String {
        var text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let openers = ["did i ", "did we ", "have i ", "have we ", "has ", "is ", "are ",
                       "did ", "do i ", "does ", "was ", "were ", "what about ", "how about "]
        var changed = true
        while changed {
            changed = false
            let lower = text.lowercased()
            for opener in openers where lower.hasPrefix(opener) {
                text = String(text.dropFirst(opener.count))
                changed = true
                break
            }
        }
        for suffix in [" yet", " now", " done", "? ", "?"] {
            while text.lowercased().hasSuffix(suffix) {
                text = String(text.dropLast(suffix.count))
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Mutations

    func markDone(id: UUID, date: Date = Date()) {
        guard let index = commitments.firstIndex(where: { $0.id == id }) else { return }
        commitments[index].status = .completed
        commitments[index].completedAt = date
        save()
    }

    func reopen(id: UUID) {
        guard let index = commitments.firstIndex(where: { $0.id == id }) else { return }
        commitments[index].status = .open
        commitments[index].completedAt = nil
        commitments[index].completionSentence = nil
        save()
    }

    func dismiss(id: UUID) {
        guard let index = commitments.firstIndex(where: { $0.id == id }) else { return }
        commitments[index].status = .dismissed
        save()
    }

    func delete(id: UUID) {
        commitments.removeAll { $0.id == id }
        save()
    }

    func add(title: String, dueHint: Date? = nil) {
        let cleaned = CommitmentExtractor.normalizedTitle(title)
        guard !cleaned.isEmpty else { return }
        let needle = CommitmentExtractor.keywords(in: cleaned)
        guard !needle.isEmpty else { return }
        commitments.insert(
            Commitment(title: cleaned, rawSentence: cleaned, dueHint: dueHint, keywords: needle),
            at: 0
        )
        pruneIfNeeded()
        save()
    }

    func clearAll() {
        commitments.removeAll()
        pendingProposals.removeAll()
        lastIngest = nil
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: commitmentsKey) else { return }
        do {
            commitments = try JSONDecoder().decode([Commitment].self, from: data)
        } catch {
            debugLog("❌ CommitmentMemoryManager: failed to decode commitments: \(error)")
            // Never destroy the user's data on a decode failure — park it.
            defaults.set(data, forKey: "\(commitmentsKey)Corrupt-\(Int(Date().timeIntervalSince1970))")
            commitments = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(commitments)
            defaults.set(data, forKey: commitmentsKey)
        } catch {
            debugLog("❌ CommitmentMemoryManager: failed to encode commitments: \(error)")
        }
    }

    /// Keep the list bounded by dropping the oldest finished entries first.
    private func pruneIfNeeded() {
        guard commitments.count > maximumStoredCommitments else { return }
        let overflow = commitments.count - maximumStoredCommitments
        let finishedIDs = commitments
            .filter { $0.status != .open }
            .sorted { ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt) }
            .prefix(overflow)
            .map { $0.id }
        guard !finishedIDs.isEmpty else { return }
        commitments.removeAll { finishedIDs.contains($0.id) }
    }

    // MARK: - Formatting helpers

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
