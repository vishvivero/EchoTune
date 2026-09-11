import Testing
@testable import EchoTune

struct AgreementEngineTests {
    private func word(_ text: String, _ confidence: Float? = 0.9) -> AgreementWord {
        AgreementWord(text: text, confidence: confidence)
    }

    @Test func stableInputConfirmsAfterTwoPasses() {
        let engine = AgreementEngine()

        let first = engine.ingest([word("hello"), word("world")])
        #expect(first.confirmed.isEmpty)
        #expect(first.hypothesis == ["hello", "world"])

        let second = engine.ingest([word("hello"), word("world")])
        #expect(second.confirmed == ["hello", "world"])
        #expect(second.newlyConfirmed == ["hello", "world"])
        #expect(second.hypothesis.isEmpty)
        #expect(engine.displayText == "hello world")
    }

    @Test func changingWordStaysHypothesisThenConfirmsWhenStable() {
        let engine = AgreementEngine()

        _ = engine.ingest([word("hello"), word("old")])
        let changed = engine.ingest([word("hello"), word("new")])
        #expect(changed.confirmed == ["hello"])
        #expect(changed.hypothesis == ["new"])

        let stable = engine.ingest([word("hello"), word("new")])
        #expect(stable.confirmed == ["hello", "new"])
        #expect(stable.newlyConfirmed == ["new"])
    }

    @Test func alternatingWordsNeverConfirm() {
        let engine = AgreementEngine()

        _ = engine.ingest([word("a")])
        _ = engine.ingest([word("b")])
        _ = engine.ingest([word("a")])
        _ = engine.ingest([word("b")])
        _ = engine.ingest([word("a")])

        #expect(engine.confirmed.isEmpty)
        #expect(engine.displayText == "a")
    }

    @Test func lowConfidenceWordIsDropped() {
        let engine = AgreementEngine()

        let update = engine.ingest([word("quiet", 0.1), word("speech", 0.9)])
        #expect(update.confirmed.isEmpty)
        #expect(update.hypothesis == ["speech"])
        #expect(!engine.displayText.contains("quiet"))
    }

    @Test func frontierBelowHighConfidenceFloorNeverConfirms() {
        let engine = AgreementEngine()

        for _ in 0..<5 {
            _ = engine.ingest([word("uncertain", 0.3)])
        }

        #expect(engine.confirmed.isEmpty)
        #expect(engine.displayText == "uncertain")
        #expect(engine.finish().isEmpty)
    }

    @Test func emptyPassDoesNotChangeState() {
        let engine = AgreementEngine()

        _ = engine.ingest([word("hello")])
        let empty = engine.ingest([])
        #expect(empty.confirmed.isEmpty)
        #expect(empty.hypothesis == ["hello"])
        let after = engine.ingest([word("hello")])
        #expect(after.confirmed == ["hello"])
    }

    @Test func duplicateWordsMatchPositionally() {
        let engine = AgreementEngine()
        let sentence = ["the", "cat", "and", "the", "dog"].map { word($0) }

        _ = engine.ingest(sentence)
        let update = engine.ingest(sentence)

        #expect(update.confirmed == ["the", "cat", "and", "the", "dog"])
    }

    @Test func shortConfirmedSessionRequestsBatchFallback() {
        let engine = AgreementEngine()
        _ = engine.ingest([word("one"), word("two")])
        _ = engine.ingest([word("one"), word("two")])

        #expect(engine.finish() == "one two")
        #expect(engine.shouldUseBatchFallback)
    }

    @Test func threeConfirmedWordsAvoidBatchFallback() {
        let engine = AgreementEngine()
        let words = [word("one"), word("two"), word("three")]
        _ = engine.ingest(words)
        _ = engine.ingest(words)

        _ = engine.finish()
        #expect(!engine.shouldUseBatchFallback)
    }

    @Test func emptySessionDoesNotRequestBatchFallback() {
        let engine = AgreementEngine()

        #expect(engine.finish().isEmpty)
        #expect(!engine.shouldUseBatchFallback)
    }

    @Test func resetClearsConfirmedHypothesisAndFallback() {
        let engine = AgreementEngine()
        let words = [word("one"), word("two")]
        _ = engine.ingest(words)
        _ = engine.ingest(words)
        _ = engine.finish()
        #expect(engine.shouldUseBatchFallback)

        engine.reset()
        #expect(engine.confirmed.isEmpty)
        #expect(engine.displayText.isEmpty)
        #expect(!engine.shouldUseBatchFallback)
    }

    @Test func nilConfidencePassesLowFloorButCannotConfirm() {
        let engine = AgreementEngine()

        _ = engine.ingest([word("unknown", nil)])
        let second = engine.ingest([word("unknown", nil)])

        #expect(second.confirmed.isEmpty)
        #expect(second.hypothesis == ["unknown"])
        #expect(engine.finish().isEmpty)
    }
}
