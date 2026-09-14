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

nonisolated enum CommitmentPriority: String, Codable, CaseIterable {
    case low, normal, high

    var displayName: String { rawValue.capitalized }
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
    /// Optional metadata captured when the user accepted a proposal.
    var person: String?
    var context: String?
    var priority: CommitmentPriority
    var confidence: Double
    /// Links back to the Echo memory entry that produced it.
    var sourceEntryID: UUID?

    private enum CodingKeys: String, CodingKey {
        case id, title, rawSentence, createdAt, lastMentionedAt, dueHint, status, completedAt, completionSentence, keywords, person, context, priority, confidence, sourceEntryID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        rawSentence = try c.decode(String.self, forKey: .rawSentence)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastMentionedAt = try c.decodeIfPresent(Date.self, forKey: .lastMentionedAt) ?? createdAt
        dueHint = try c.decodeIfPresent(Date.self, forKey: .dueHint)
        status = try c.decodeIfPresent(CommitmentStatus.self, forKey: .status) ?? .open
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        completionSentence = try c.decodeIfPresent(String.self, forKey: .completionSentence)
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
        person = try c.decodeIfPresent(String.self, forKey: .person)
        context = try c.decodeIfPresent(String.self, forKey: .context)
        priority = try c.decodeIfPresent(CommitmentPriority.self, forKey: .priority) ?? .normal
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 1
        sourceEntryID = try c.decodeIfPresent(UUID.self, forKey: .sourceEntryID)
    }

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
        person: String? = nil,
        context: String? = nil,
        priority: CommitmentPriority = .normal,
        confidence: Double = 1,
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
        self.person = person
        self.context = context
        self.priority = priority
        self.confidence = confidence
        self.sourceEntryID = sourceEntryID
    }
}

/// What changed when a piece of dictated text was processed.
nonisolated struct CommitmentProposal: Identifiable, Equatable {
    let id: UUID
    var task: String
    var person: String
    var context: String
    var dueDate: Date?
    var priority: CommitmentPriority
    var confidence: Double
    let sourceSentence: String
    let sourceEntryID: UUID?
    let proposedAt: Date

    init(id: UUID = UUID(), task: String, person: String = "", context: String = "", dueDate: Date? = nil, priority: CommitmentPriority = .normal, confidence: Double = 0.9, sourceSentence: String, sourceEntryID: UUID? = nil, proposedAt: Date = Date()) {
        self.id = id
        self.task = task
        self.person = person
        self.context = context
        self.dueDate = dueDate
        self.priority = priority
        self.confidence = confidence
        self.sourceSentence = sourceSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceEntryID = sourceEntryID
        self.proposedAt = proposedAt
    }
}

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
