import XCTest
@testable import EchoTune

final class DictionaryBoundaryTests: XCTestCase {
    func testPlainTermDoesNotMatchInsideLargerWords() {
        let dictionary = DictionaryManager.shared
        let old = dictionary.wordReplacements
        defer { dictionary.wordReplacements = old }
        dictionary.wordReplacements = [WordReplacement(spokenForm: "cat", writtenForm: "feline")]

        XCTAssertEqual(
            dictionary.applyReplacements(to: "cat catalogue scatter cat."),
            "feline catalogue scatter feline."
        )
    }

    func testPunctuationTermMatchesOnlyAsStandaloneTerm() {
        let dictionary = DictionaryManager.shared
        let old = dictionary.wordReplacements
        defer { dictionary.wordReplacements = old }
        dictionary.wordReplacements = [WordReplacement(spokenForm: "C++", writtenForm: "C Plus Plus")]

        XCTAssertEqual(
            dictionary.applyReplacements(to: "I use C++ daily; C++17 is different."),
            "I use C Plus Plus daily; C++17 is different."
        )
    }

    func testHyphenAndAccentedTermBoundaries() {
        let dictionary = DictionaryManager.shared
        let old = dictionary.wordReplacements
        defer { dictionary.wordReplacements = old }
        dictionary.wordReplacements = [
            WordReplacement(spokenForm: "Boötes-", writtenForm: "Boötes constellation")
        ]

        XCTAssertEqual(
            dictionary.applyReplacements(to: "Boötes- is visible; XBoötes- is not."),
            "Boötes constellation is visible; XBoötes- is not."
        )
    }

    func testCorrectSpellingUsesSameUnicodeBoundaries() {
        let dictionary = DictionaryManager.shared
        let old = dictionary.correctSpellings
        defer { dictionary.correctSpellings = old }
        dictionary.correctSpellings = [CorrectSpelling(word: "Boötes", variations: ["booties"])]

        XCTAssertEqual(
            dictionary.applySpellings(to: "booties are here; booties2 is not."),
            "Boötes are here; booties2 is not."
        )
    }
}
