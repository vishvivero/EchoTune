import XCTest
@testable import EchoTune

final class EnhancementProviderTests: XCTestCase {
    func testCommandArgumentsKeepTranscriptOutOfArgumentVector() {
        let transcript = "quote\" $(touch /tmp/should-not-run)"
        let arguments = LocalCLIEnhancementProvider.commandArguments(modelName: "llama3.2:1b")
        XCTAssertEqual(arguments, ["run", "llama3.2:1b"])
        XCTAssertFalse(arguments.joined(separator: " ").contains(transcript))
    }

    func testProviderStartsUnavailableUntilBackgroundDetectionFindsBinary() {
        let provider = LocalCLIEnhancementProvider()
        XCTAssertFalse(provider.isAvailable)
    }

    func testCandidatePathsIncludeStandardLocationsAndPathEntries() {
        let paths = LocalCLIEnhancementProvider.standardCandidatePaths(
            homeDirectory: "/Users/tester",
            path: "/custom/bin:/another/bin"
        )
        XCTAssertTrue(paths.contains("/opt/homebrew/bin/ollama"))
        XCTAssertTrue(paths.contains("/Users/tester/.local/bin/ollama"))
        XCTAssertTrue(paths.contains("/custom/bin/ollama"))
    }

    func testOutputFilterIsSharedByProviderBoundaryContract() {
        let provider: any EnhancementProvider = LocalCLIEnhancementProvider()
        XCTAssertEqual(provider.id, "ollama-local")
        XCTAssertEqual(EnhancementOutputFilter.clean("```text\nclean\n```"), "clean")
    }
}
