//
//  Commitment.swift
//  EchoTune
//
//  Offline task/commitment memory: things the user said out loud that they
//  meant to do later ("I need to sort Nila's passport"), plus whether they
//  later said it was done. Everything is stored locally and matched with
//  keyword logic — no network, no model download.
//

import Foundation

/// Where a commitment stands.
nonisolated enum CommitmentStatus: String, Codable {
    case open
    case completed
    case dismissed
}

/// A single thing the user committed to doing, mined from their own dictation.
nonisolated struct Commitment: Codable, Identifiable, Equatable {
    let id: UUID
    /// Normalized action phrase, e.g. "sort Nila's passport".
    var title: String
    /// The sentence it was mined from, kept for trust and context.
    var rawSentence: String
    var createdAt: Date
    var lastMentionedAt: Date
    /// Resolved from phrasing like "tomorrow" / "by Friday", when present.
    var dueHint: Date?
    var status: CommitmentStatus
    var completedAt: Date?
    /// The sentence that reported it as done, when Echo heard one.
    var completionSentence: String?
    /// Normalized matching tokens.
    var keywords: [String]
    /// Links back to the Echo memory entry that produced it.
    var sourceEntryID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        rawSentence: String,
        createdAt: Date = Date(),
        lastMentionedAt: Date = Date(),
        dueHint: Date? = nil,
        status: CommitmentStatus = .open,
        completedAt: Date? = nil,
        completionSentence: String? = nil,
        keywords: [String] = [],
        sourceEntryID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.rawSentence = rawSentence
        self.createdAt = createdAt
        self.lastMentionedAt = lastMentionedAt
        self.dueHint = dueHint
        self.status = status
        self.completedAt = completedAt
        self.completionSentence = completionSentence
        self.keywords = keywords
        self.sourceEntryID = sourceEntryID
    }
}

/// What changed when a piece of dictated text was processed.
nonisolated struct CommitmentIngestSummary: Equatable {
    var added: [Commitment] = []
    var completed: [Commitment] = []

    var isEmpty: Bool { added.isEmpty && completed.isEmpty }

    /// Short user-facing line, or nil when nothing happened.
    var notificationLine: String? {
        switch (added.count, completed.count) {
        case (0, 0): return nil
        case (let a, 0): return a == 1 ? "Task saved" : "\(a) tasks saved"
        case (0, let c): return c == 1 ? "Task marked done" : "\(c) tasks marked done"
        case (let a, let c): return "\(a) saved · \(c) done"
        }
    }
}

/// The answer to a question like "did I sort Nila's passport?".
nonisolated struct CommitmentAnswer: Equatable {
    nonisolated enum Verdict: Equatable {
        case completed
        case open
        case unknown
    }

    let query: String
    let verdict: Verdict
    let headline: String
    /// Every commitment that plausibly matches, best first.
    let matches: [Commitment]
}
