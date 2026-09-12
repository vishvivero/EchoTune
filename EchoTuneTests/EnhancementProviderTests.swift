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

    func testOllamaRoundTripWhenOptedIn() async throws {
        let requested = ProcessInfo.processInfo.environment["ECHOTUNE_OLLAMA_RUNTIME"] == "1"
            || UserDefaults.standard.bool(forKey: "phase10OllamaRuntime")
        try XCTSkipUnless(requested, "Opt-in local Ollama runtime test")
        let provider = LocalCLIEnhancementProvider(modelName: "gemma4:e2b")
        await provider.refreshAvailability()
        XCTAssertTrue(provider.isAvailable)
        let started = Date()
        let output = try await provider.polish(
            "the meeting is on monday at ten",
            prompt: "Correct capitalization and punctuation; return only the polished text."
        )
        XCTAssertFalse(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        print("P10_RUNTIME ollamaModel=gemma4:e2b elapsedSeconds=\(String(format: "%.3f", Date().timeIntervalSince(started)))")
    }
}
