import XCTest
@testable import EchoTune

final class VocabularyBiasingTests: XCTestCase {
    func testEmptyTermsProduceNoPrompt() {
        let tokens = VocabularyBiasing.promptTokens(for: [], language: "en", encode: { _ in [1, 2] })
        XCTAssertEqual(tokens, [])
    }

    func testTermsDeduplicateCaseAndDiacriticsKeepingFirstSpelling() {
        let dictionary = DictionaryManager.shared
        let learner = CorrectionLearner.shared
        let oldReplacements = dictionary.wordReplacements
        let oldSpellings = dictionary.correctSpellings
        defer {
            dictionary.wordReplacements = oldReplacements
            dictionary.correctSpellings = oldSpellings
        }
        dictionary.wordReplacements = [
            WordReplacement(spokenForm: "bootees", writtenForm: "Boötes"),
            WordReplacement(spokenForm: "bootes", writtenForm: "Bootes")
        ]
        dictionary.correctSpellings = []

        let terms = VocabularyBiasing.terms(dictionary: dictionary, learner: learner, appTerms: [])
        XCTAssertEqual(terms, ["Boötes"])
    }

    func testPromptBudgetTrimsDeterministically() {
        let terms = (0..<60).map { "term\($0)" }
        let tokens = VocabularyBiasing.promptTokens(
            for: terms,
            language: "en",
            encode: { _ in [1, 2, 3, 4, 5] }
        )
        XCTAssertLessThanOrEqual(tokens.count, VocabularyBiasing.maxPromptTokens)
        XCTAssertEqual(tokens.count, 220)
    }

    func testLanguageFilterNeverDropsEveryTerm() {
        let terms = ["Boötes", "EchoTune"]
        XCTAssertEqual(VocabularyBiasing.filterByLanguage(terms, language: "en"), terms)
        XCTAssertEqual(VocabularyBiasing.filterByLanguage(["Привет"], language: "en"), ["Привет"])
    }

    func testCorrectSpellingProvidesCanonicalTermAndAlias() {
        let dictionary = DictionaryManager.shared
        let learner = CorrectionLearner.shared
        let oldReplacements = dictionary.wordReplacements
        let oldSpellings = dictionary.correctSpellings
        defer {
            dictionary.wordReplacements = oldReplacements
            dictionary.correctSpellings = oldSpellings
        }
        dictionary.wordReplacements = []
        dictionary.correctSpellings = [
            CorrectSpelling(word: "Khoob", variations: ["coop"])
        ]
        let entries = VocabularyBiasing.entries(dictionary: dictionary, learner: learner, appTerms: [])
        XCTAssertEqual(entries.first?.term, "Khoob")
        XCTAssertEqual(entries.first?.aliases, ["coop"])
    }
}
