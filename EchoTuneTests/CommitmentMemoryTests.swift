//
//  CommitmentMemoryTests.swift
//  EchoTuneTests
//
//  Offline task memory: mining, dedupe, completion matching, and answering
//  "did I do X?" from local memory only.
//

import Foundation
import Testing
@testable import EchoTune

struct CommitmentExtractionTests {

    private func scratchManager() -> CommitmentMemoryManager {
        let suite = "CommitmentMemoryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return CommitmentMemoryManager(defaults: defaults)
    }

    private func fixedDate(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso)!
    }

    // MARK: - Mining

    @Test func minesNeedToPhrasingWithDueWord() {
        let now = fixedDate("2026-09-10T09:00:00Z")
        let mined = CommitmentExtractor.extract(from: "I need to sort Nila's passport this week.", now: now)
        #expect(mined.count == 1)
        #expect(mined.first?.title.lowercased() == "sort nila's passport")
        #expect(mined.first?.dueHint != nil)
    }

    @Test func minesReminderPhrasing() {
        let now = fixedDate("2026-09-10T09:00:00Z")
        let mined = CommitmentExtractor.extract(from: "Remind me to book the dentist tomorrow.", now: now)
        #expect(mined.count == 1)
        #expect(mined.first?.title == "Book the dentist")
        let calendar = Calendar.current
        let expected = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        #expect(mined.first?.dueHint == expected)
    }

    @Test func minesTodoPrefix() {
        let mined = CommitmentExtractor.extract(from: "Todo: chase the accountant about the VAT return.")
        #expect(mined.first?.title == "Chase the accountant about the VAT return")
    }

    @Test func minesDoNotForgetPhrasing() {
        let mined = CommitmentExtractor.extract(from: "Don't forget to renew the car insurance.")
        #expect(mined.first?.title == "Renew the car insurance")
    }

    @Test func ignoresQuestions() {
        #expect(CommitmentExtractor.extract(from: "Should I call the bank?").isEmpty)
        #expect(CommitmentExtractor.extract(from: "Did I send the form?").isEmpty)
    }

    @Test func ignoresFutureStatementsOfFact() {
        #expect(CommitmentExtractor.extract(from: "I'll be there at six.").isEmpty)
        #expect(CommitmentExtractor.extract(from: "I'll let you know.").isEmpty)
        #expect(CommitmentExtractor.extract(from: "I'll be honest with you.").isEmpty)
    }

    @Test func ignoresOtherPeoplesPlans() {
        #expect(CommitmentExtractor.extract(from: "You need to send the form.").isEmpty)
        #expect(CommitmentExtractor.extract(from: "She said I have to move the meeting.").isEmpty)
    }

    @Test func hedgedFirstPersonCommitmentStillMines() {
        let mined = CommitmentExtractor.extract(from: "I think I need to call the plumber.")
        #expect(mined.first?.title == "Call the plumber")
    }

    @Test func multipleCommitmentsInOneBreath() {
        let mined = CommitmentExtractor.extract(from: "I need to email the landlord and don't forget to pay the council tax.")
        #expect(mined.count == 2)
    }

    // MARK: - Token matching

    @Test func stemsPluralsAndPossessives() {
        #expect(CommitmentExtractor.keywords(in: "passports") == ["passport"])
        #expect(CommitmentExtractor.keywords(in: "Nila's passport") == ["nila", "passport"])
        #expect(CommitmentExtractor.stem("sorted") == "sort")
        #expect(CommitmentExtractor.stem("renewed") == "renew")
    }

    @Test func prefixMatchingHandlesInflections() {
        #expect(CommitmentExtractor.tokensMatch("sort", "sorted"))
        #expect(CommitmentExtractor.tokensMatch("book", "booking"))
        #expect(!CommitmentExtractor.tokensMatch("cat", "car"))
    }

    @Test func genericTokensAloneAreNotEvidence() {
        // Matching always runs on stemmed keywords, so "sorted" arrives as "sort".
        #expect(!CommitmentExtractor.hasDistinctiveOverlap(needle: ["sort", "that"], haystack: ["sort", "that"]))
        #expect(CommitmentExtractor.hasDistinctiveOverlap(needle: ["sort", "passport"], haystack: ["sort", "passport"]))
    }

    // MARK: - Ingestion

    @Test func duplicateCommitmentsAreNotStoredTwice() {
        let manager = scratchManager()
        manager.ingest(text: "I need to sort Nila's passport.")
        manager.ingest(text: "I really need to sort Nila's passport.")
        #expect(manager.commitments.count == 1)
    }

    @Test func completionClosesTheMatchingCommitment() {
        let manager = scratchManager()
        let added = fixedDate("2026-09-08T09:00:00Z")
        let done = fixedDate("2026-09-10T09:00:00Z")

        manager.ingest(text: "Don't forget to renew the car insurance.", date: added)
        #expect(manager.openCount == 1)

        let summary = manager.ingest(text: "I renewed the car insurance today.", date: done)
        #expect(summary.completed.count == 1)
        #expect(manager.openCount == 0)
        #expect(manager.completedCommitments.first?.completedAt == done)
        #expect(manager.completedCommitments.first?.completionSentence?.contains("renewed") == true)
    }

    @Test func completionOfSomethingElseChangesNothing() {
        let manager = scratchManager()
        manager.ingest(text: "I need to sort Nila's passport.")
        let summary = manager.ingest(text: "I finished the tax return.")
        #expect(summary.completed.isEmpty)
        #expect(manager.openCount == 1)
        #expect(manager.commitments.first?.title == "Sort Nila's passport")
    }

    @Test func cannotCompleteSomethingSaidInTheSameBreath() {
        let manager = scratchManager()
        let summary = manager.ingest(text: "I need to sort Nila's passport, and I sorted Nila's passport yesterday.")
        #expect(summary.completed.isEmpty)
        #expect(manager.openCount == 1)
    }

    // MARK: - Answering

    @Test func answersCompletedTaskWithYes() {
        let manager = scratchManager()
        manager.ingest(text: "Don't forget to renew the car insurance.", date: fixedDate("2026-09-08T09:00:00Z"))
        manager.ingest(text: "I renewed the car insurance today.", date: fixedDate("2026-09-10T09:00:00Z"))

        let answer = manager.answer("did I renew the car insurance?")
        #expect(answer.verdict == .completed)
        #expect(answer.headline.hasPrefix("Yes"))
        #expect(answer.matches.count == 1)
    }

    @Test func answersOpenTaskWithNotYet() {
        let manager = scratchManager()
        manager.ingest(text: "I need to sort Nila's passport.", date: fixedDate("2026-09-08T09:00:00Z"))
        let answer = manager.answer("did I sort Nila's passport?")
        #expect(answer.verdict == .open)
        #expect(answer.headline.hasPrefix("Not yet"))
    }

    @Test func answersUnknownWhenNothingMatches() {
        let manager = scratchManager()
        manager.ingest(text: "I need to sort Nila's passport.")
        let answer = manager.answer("did I buy a helicopter?")
        #expect(answer.verdict == .unknown)
        #expect(answer.matches.isEmpty)
    }

    @Test func answerStripsQuestionScaffolding() {
        #expect(CommitmentMemoryManager.querySubject(from: "did I sort the passport?") == "sort the passport")
        #expect(CommitmentMemoryManager.querySubject(from: "have we paid the council tax") == "paid the council tax")
    }

    // MARK: - Backfill

    @Test func backfillMinesAlreadyStoredTranscriptions() {
        let manager = scratchManager()
        // EchoMemoryManager stores newest first; backfill must not care.
        let entries = [
            EchoMemoryEntry(
                id: UUID(),
                date: fixedDate("2026-09-10T09:00:00Z"),
                text: "I booked the car in for a service this morning.",
                duration: 3,
                modelID: "local",
                provider: "local",
                wasEdited: false,
                wasAccepted: false,
                wasRejected: false,
                frontmostApp: nil,
                windowTitle: nil
            ),
            EchoMemoryEntry(
                id: UUID(),
                date: fixedDate("2026-09-09T09:00:00Z"),
                text: "I need to book the car in for a service.",
                duration: 3,
                modelID: "local",
                provider: "local",
                wasEdited: false,
                wasAccepted: false,
                wasRejected: false,
                frontmostApp: nil,
                windowTitle: nil
            )
        ]

        manager.backfillIfNeeded(from: entries)
        #expect(manager.commitments.count == 1)
        #expect(manager.completedCommitments.count == 1)
    }

    @Test func backfillOnlyRunsOnce() {
        let manager = scratchManager()
        manager.backfillIfNeeded(from: [])
        let entries = [
            EchoMemoryEntry(
                id: UUID(),
                date: fixedDate("2026-09-09T09:00:00Z"),
                text: "I need to book the car in for a service.",
                duration: 3,
                modelID: nil,
                provider: nil,
                wasEdited: false,
                wasAccepted: false,
                wasRejected: false,
                frontmostApp: nil,
                windowTitle: nil
            )
        ]
        manager.backfillIfNeeded(from: entries)
        #expect(manager.commitments.isEmpty)
    }

    // MARK: - List management

    @Test func deletingAndReopeningBehave() {
        let manager = scratchManager()
        manager.ingest(text: "I need to call the plumber.")
        let id = manager.commitments[0].id

        manager.markDone(id: id)
        #expect(manager.openCount == 0)
        manager.reopen(id: id)
        #expect(manager.openCount == 1)
        manager.delete(id: id)
        #expect(manager.commitments.isEmpty)
    }

    @Test func dueTodayOnlyIncludesDueOrOverdueOpenItems() {
        let manager = scratchManager()
        let now = fixedDate("2026-09-10T09:00:00Z")
        manager.ingest(text: "I need to pay the water bill today.", date: now)
        manager.ingest(text: "I need to renew the passport next year.", date: now)
        #expect(manager.dueToday.count == 1)
    }
}
