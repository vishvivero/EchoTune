import Foundation
import Testing
@testable import EchoTune

/// ET-758 · spoken filler removal + punctuation repair.
struct FillerWordManagerTests {

    private func clean(_ text: String) -> String {
        FillerWordManager.shared.clean(text)
    }

    // MARK: Acceptance criteria

    @Test func removesFillersAndRepairsPunctuation() {
        // Ticket AC: "I went, uh, to the store. Erm, yes!" → "I went to the store. Yes!"
        #expect(clean("I went, uh, to the store. Erm, yes!") == "I went to the store. Yes!")
    }

    @Test func removesInlineFillers() {
        #expect(clean("So um the plan is uh to ship it.") == "So the plan is to ship it.")
        #expect(clean("That was hmm interesting.") == "That was interesting.")
    }

    @Test func collapsesDoubleSpaces() {
        #expect(clean("Hello  uh   there.") == "Hello there.")
    }

    @Test func capitalizesSentenceStarts() {
        #expect(clean("first sentence. second sentence.") == "First sentence. Second sentence.")
    }

    // MARK: Safety

    @Test func leavesCleanTextUntouched() {
        let sentences = [
            "I went to the store to buy some milk.",
            "Ship the release on Friday.",
            "The quick brown fox jumps over the lazy dog."
        ]
        for sentence in sentences {
            #expect(clean(sentence) == sentence)
        }
    }

    @Test func doesNotRemoveWordsThatMerelyContainAFiller() {
        #expect(clean("I am furious about this.") == "I am furious about this.")
        #expect(clean("The umbrella is here.") == "The umbrella is here.")
        #expect(clean("Hmmming is not a word, but humming is.") == "Hmmming is not a word, but humming is.")
    }

    @Test func fillerOnlyUtteranceIsPreserved() {
        #expect(clean("Uh.") == "Uh.")
        #expect(clean("Um") == "Um")
    }

    @Test func customFillersAreHonoured() {
        let manager = FillerWordManager.shared
        let saved = manager.customFillers
        defer { manager.setCustomFillersForTesting(saved) }

        manager.setCustomFillersForTesting(["like", "y'know"])
        #expect(manager.allFillers.contains("like"))
        #expect(manager.clean("It was, like, really good.") == "It was really good.")

        #expect(manager.addFiller("basically") == true)
        #expect(manager.addFiller("basically") == false, "duplicates rejected")
        #expect(manager.removeFiller("basically") == true)
    }

    @Test func idempotent() {
        let manager = FillerWordManager.shared
        let once = manager.clean("I went, uh, to the store. Erm, yes!")
        let twice = manager.clean(once)
        #expect(once == twice)
    }

    @Test func emptyInputIsSafe() {
        #expect(clean("") == "")
    }

    @Test func capitalizationCanBeDisabled() {
        let manager = FillerWordManager.shared
        #expect(manager.clean("lowercase start.", repairCapitalization: false) == "lowercase start.")
    }
}