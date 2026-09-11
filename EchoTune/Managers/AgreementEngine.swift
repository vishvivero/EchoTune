//
//  AgreementEngine.swift
//  EchoTune
//
//  Pure state machine for agreement-based live preview. It deliberately has
//  no Whisper, FluidAudio, UI, or singleton dependencies.
//

import Foundation

enum StreamingDisposition: String, Equatable {
    case streamed
    case batchFallback
    case noSpeech
}

struct AgreementWord: Equatable {
    let text: String
    let confidence: Float?
}

struct AgreementUpdate: Equatable {
    var confirmed: [String]
    var hypothesis: [String]
    var newlyConfirmed: [String]
}

final class AgreementEngine {
    /// EchoTune decodes a larger rolling window than the reference streaming
    /// implementation, so two consecutive agreements are the default.
    static let defaultConfirmationPasses = 2
    static let defaultLowConfidenceFloor: Float = 0.15
    static let defaultHighConfidenceFloor: Float = 0.6
    static let minConfirmedSegmentsForStreaming = 3
    /// Full-audio fallback is intentionally bounded so a long dictation does
    /// not turn stop into an unbounded second transcription.
    static let maxBatchFallbackDuration: TimeInterval = 5 * 60

    static func disposition(
        hasAudio: Bool,
        shouldFallback: Bool,
        audioDuration: TimeInterval,
        maxFallbackDuration: TimeInterval = maxBatchFallbackDuration
    ) -> StreamingDisposition {
        guard hasAudio else { return .noSpeech }
        guard shouldFallback, audioDuration <= maxFallbackDuration else { return .streamed }
        return .batchFallback
    }

    private let confirmationPasses: Int
    private let lowConfidenceFloor: Float
    private let highConfidenceFloor: Float

    private(set) var confirmed: [String] = []
    private var previousFrontier: [AgreementWord] = []
    private var agreementRuns: [Int] = []
    private var latestHypothesis: [AgreementWord] = []
    private var receivedWords = false
    private(set) var shouldUseBatchFallback = false

    init(
        confirmationPasses: Int = AgreementEngine.defaultConfirmationPasses,
        lowConfidenceFloor: Float = AgreementEngine.defaultLowConfidenceFloor,
        highConfidenceFloor: Float = AgreementEngine.defaultHighConfidenceFloor
    ) {
        self.confirmationPasses = max(1, confirmationPasses)
        self.lowConfidenceFloor = lowConfidenceFloor
        self.highConfidenceFloor = highConfidenceFloor
    }

    /// Feeds one decoder pass. Matching is positional from the confirmed
    /// frontier; set-based matching would corrupt repeated words such as
    /// "the ... the".
    @discardableResult
    func ingest(_ words: [AgreementWord]) -> AgreementUpdate {
        let filtered = words.compactMap(normalizedWord)
        guard !filtered.isEmpty else {
            return currentUpdate(newlyConfirmed: [])
        }
        receivedWords = true
        shouldUseBatchFallback = false

        // A shorter decode cannot retract already confirmed text. Keep the
        // previous frontier until a pass reaches the confirmed boundary again.
        guard filtered.count >= confirmed.count else {
            latestHypothesis = []
            return currentUpdate(newlyConfirmed: [])
        }

        let frontier = Array(filtered.dropFirst(confirmed.count))
        var nextRuns = frontier.indices.map { index in
            guard index < previousFrontier.count,
                  previousFrontier[index].text == frontier[index].text else {
                return 1
            }
            return agreementRuns[index] + 1
        }

        // Confirmation is sequential. If an earlier frontier word is not
        // eligible, later words cannot jump over it into the committed text.
        var confirmCount = 0
        while confirmCount < frontier.count,
              nextRuns[confirmCount] >= confirmationPasses,
              canConfirm(frontier[confirmCount]) {
            confirmCount += 1
        }

        let newlyConfirmed = frontier.prefix(confirmCount).map(\.text)
        if !newlyConfirmed.isEmpty {
            confirmed.append(contentsOf: newlyConfirmed)
        }

        latestHypothesis = Array(frontier.dropFirst(confirmCount))
        previousFrontier = latestHypothesis
        nextRuns.removeFirst(min(confirmCount, nextRuns.count))
        agreementRuns = nextRuns

        return currentUpdate(newlyConfirmed: newlyConfirmed)
    }

    /// Current display state. Hypothesis text is display-only; callers decide
    /// how to render it differently from `confirmed`.
    var displayText: String {
        let words = confirmed + latestHypothesis.map(\.text)
        return words.joined(separator: " ")
    }

    /// Returns only text that crossed the agreement and confidence gates.
    /// A short or empty session is not considered a batch-fallback failure.
    func finish() -> String {
        shouldUseBatchFallback = receivedWords
            && confirmed.count < Self.minConfirmedSegmentsForStreaming
        return confirmed.joined(separator: " ")
    }

    func reset() {
        confirmed.removeAll(keepingCapacity: true)
        previousFrontier.removeAll(keepingCapacity: true)
        agreementRuns.removeAll(keepingCapacity: true)
        latestHypothesis.removeAll(keepingCapacity: true)
        receivedWords = false
        shouldUseBatchFallback = false
    }

    private func canConfirm(_ word: AgreementWord) -> Bool {
        guard let confidence = word.confidence else { return false }
        return confidence >= highConfidenceFloor
    }

    private func normalizedWord(_ word: AgreementWord) -> AgreementWord? {
        let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let confidence = word.confidence, confidence < lowConfidenceFloor {
            return nil
        }
        return AgreementWord(text: text, confidence: word.confidence)
    }

    private func currentUpdate(newlyConfirmed: [String]) -> AgreementUpdate {
        AgreementUpdate(
            confirmed: confirmed,
            hypothesis: latestHypothesis.map(\.text),
            newlyConfirmed: newlyConfirmed
        )
    }
}
