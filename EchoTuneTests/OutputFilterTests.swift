import XCTest
@testable import EchoTune

final class OutputFilterTests: XCTestCase {
    func testRequiredFenceFixture() {
        let raw = "```markdown\n**Meeting summary**\n```\n\n- Point"
        XCTAssertEqual(EnhancementOutputFilter.clean(raw), "**Meeting summary**\n\n- Point")
    }

    func testReasoningBlocksAreRemovedButNormalTextRemains() {
        let raw = "<deep-thinking>private chain of thought</deep-thinking>\nAnswer <note>keep this</note>"
        XCTAssertEqual(EnhancementOutputFilter.clean(raw), "Answer <note>keep this</note>")
    }

    func testLabelsOnlyAtStartAreRemoved() {
        XCTAssertEqual(EnhancementOutputFilter.clean("Polished: Hello\nOutput: stays"), "Hello\nOutput: stays")
        XCTAssertEqual(EnhancementOutputFilter.clean("Here is the polished text: Hello"), "Hello")
        XCTAssertEqual(EnhancementOutputFilter.clean("A sentence: stays"), "A sentence: stays")
    }

    func testQuotesOnlyStripWhenTheyWrapEntireResult() {
        XCTAssertEqual(EnhancementOutputFilter.clean("\"Hello\nworld\""), "Hello\nworld")
        XCTAssertEqual(EnhancementOutputFilter.clean("He said \"hello\"."), "He said \"hello\".")
        XCTAssertEqual(EnhancementOutputFilter.clean("“Hello”"), "Hello")
    }

    func testFencesInMiddleAndUnterminatedOpening() {
        XCTAssertEqual(EnhancementOutputFilter.clean("Before\n```swift\nlet x = 1\n```\nAfter"), "Before\nlet x = 1\nAfter")
        XCTAssertEqual(EnhancementOutputFilter.clean("```text\ncontent"), "content")
        XCTAssertEqual(EnhancementOutputFilter.clean("```text```"), "text")
    }

    func testWhitespaceEmptyAndIdempotence() {
        XCTAssertEqual(EnhancementOutputFilter.clean("   \n\n"), "")
        XCTAssertEqual(EnhancementOutputFilter.clean("Plain text"), "Plain text")
        let value = "\n\nOutput: ```markdown\n\"Hello\"\n```\n"
        let cleaned = EnhancementOutputFilter.clean(value)
        XCTAssertEqual(EnhancementOutputFilter.clean(cleaned), cleaned)
    }

    func testToggleCanPreserveRawOutput() {
        let raw = "```markdown\ntext\n```"
        XCTAssertEqual(EnhancementOutputFilter.clean(raw, stripMarkdownFences: false), raw)
    }
}
