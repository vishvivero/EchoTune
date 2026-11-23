import Foundation
import Testing
@testable import EchoTune

/// ET-757 · offline phonetic vocabulary matcher.
struct PhoneticVocabularyMatcherTests {

    private func matcher(
        _ words: [String],
        minimumScore: Double = 0.72
    ) -> PhoneticVocabularyMatcher {
        let spellings = words.map { CorrectSpelling(word: $0) }
        return PhoneticVocabularyMatcher(correctSpellings: spellings, minimumScore: minimumScore)
    }

    // MARK: Acceptance criteria

    @Test func splitsCompoundProductName() {
        let m = matcher(["EchoTune", "WhisperKit", "Kubernetes"])
        #expect(m.apply(to: "Open echo tune now.") == "Open EchoTune now.")
    }

    @Test func fixesPhoneticMishearing() {
        let m = matcher(["EchoTune", "WhisperKit", "Kubernetes"])
        #expect(m.apply(to: "Check ekotune settings.") == "Check EchoTune settings.")
    }

    @Test func fixesTechnicalJargonMishearing() {
        let m = matcher(["EchoTune", "WhisperKit", "Kubernetes"])
        #expect(m.apply(to: "Deploy to kubernetis cluster.") == "Deploy to Kubernetes cluster.")
    }

    @Test func fixesSplitLibraryName() {
        let m = matcher(["EchoTune", "WhisperKit", "Kubernetes"])
        #expect(m.apply(to: "Load whisper kit first.") == "Load WhisperKit first.")
    }

    // MARK: Safety

    @Test func leavesOrdinaryProseUntouched() {
        let m = matcher(["EchoTune", "WhisperKit", "Kubernetes"])
        let prose = [
            "I went to the store to buy some milk for my coffee.",
            "Please send the report to the team before the meeting.",
            "The quick brown fox jumps over the lazy dog.",
            "We should probably review this tomorrow morning."
        ]
        for sentence in prose {
            #expect(m.apply(to: sentence) == sentence)
        }
    }

    @Test func stopwordsAreNeverRewritten() {
        let m = matcher(["The", "And", "For"])
        #expect(m.apply(to: "the end and for the rest") == "the end and for the rest")
    }

    @Test func punctuationAndSpacingSurvive() {
        let m = matcher(["EchoTune"])
        #expect(m.apply(to: "Hello,  ekotune!\nNext line.") == "Hello,  EchoTune!\nNext line.")
    }

    @Test func alreadyCorrectTextIsIdempotent() {
        let m = matcher(["EchoTune", "Kubernetes"])
        let once = m.apply(to: "Open echo tune and deploy to kubernetes.")
        let twice = m.apply(to: once)
        #expect(once == "Open EchoTune and deploy to kubernetes.")
        #expect(twice == once)
    }

    @Test func emptyInputsAreSafe() {
        #expect(matcher([]).apply(to: "anything") == "anything")
        #expect(matcher(["EchoTune"]).apply(to: "") == "")
        #expect(matcher(["EchoTune"]).apply(to: "   ") == "   ")
    }

    // MARK: Encoding + metrics

    @Test func skeletonCollapsesCommonVariants() {
        let a = PhoneticEncoder.skeleton("echo")
        let b = PhoneticEncoder.skeleton("eko")
        #expect(a == b)
        #expect(PhoneticEncoder.skeleton("whisper") == PhoneticEncoder.skeleton("wisper"))
        #expect(PhoneticEncoder.skeleton("phone") == PhoneticEncoder.skeleton("fone"))
    }

    @Test func similarityMetricsAreSane() {
        #expect(StringSimilarity.normalizedLevenshtein("abc", "abc") == 1)
        #expect(StringSimilarity.normalizedLevenshtein("abc", "xyz") < 0.2)
        #expect(StringSimilarity.trigramJaccard("echotune", "echotune") == 1)
        #expect(StringSimilarity.trigramJaccard("echotune", "") == 0)
    }

    @Test func defaultDictionarySeedsProducts() {
        let manager = DictionaryManager.shared
        let words = manager.correctSpellings.map(\.word)
        #expect(words.contains("EchoTune"))
        #expect(words.contains("WhisperKit"))
        #expect(words.contains("Parakeet"))
    }
}