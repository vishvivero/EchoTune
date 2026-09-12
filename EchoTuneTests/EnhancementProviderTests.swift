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

    func testStubProviderFiltersWrapperOutputAtItsBoundary() async throws {
        let executable = try makeStubOllama("""
        #!/bin/sh
        cat > /dev/null
        printf '%s\\n' '```text'
        printf '%s\\n' 'Polished: Hello world.'
        printf '%s\\n' '```'
        """)
        let provider = LocalCLIEnhancementProvider(executablePath: executable, stripsWrappers: { true })
        await provider.refreshAvailability()
        XCTAssertTrue(provider.isAvailable)
        let output = try await provider.polish("hello world", prompt: "polish this")
        XCTAssertEqual(output, "Hello world.")
    }

    func testStubProviderHonorsRawOutputToggle() async throws {
        let executable = try makeStubOllama("""
        #!/bin/sh
        cat > /dev/null
        printf '%s\\n' '```text'
        printf '%s\\n' 'Polished: Hello world.'
        printf '%s\\n' '```'
        """)
        let provider = LocalCLIEnhancementProvider(executablePath: executable, stripsWrappers: { false })
        await provider.refreshAvailability()
        let output = try await provider.polish("hello world", prompt: "polish this")
        XCTAssertEqual(output, "```text\nPolished: Hello world.\n```")
    }

    func testStubProviderTerminatesOnTimeout() async throws {
        let executable = try makeStubOllama("#!/bin/sh\nsleep 30\n")
        let provider = LocalCLIEnhancementProvider(executablePath: executable, timeout: 0.5)
        await provider.refreshAvailability()
        do {
            _ = try await provider.polish("hello", prompt: "polish this")
            XCTFail("Expected the stub provider to time out")
        } catch let error as LocalCLIEnhancementProvider.ProviderError {
            guard case .timedOut = error else {
                return XCTFail("Expected timedOut, got \(error)")
            }
        }
    }

    func testStubProviderSurfacesFailureWithoutFallback() async throws {
        let executable = try makeStubOllama("#!/bin/sh\ncat > /dev/null\necho boom >&2\nexit 3\n")
        let provider = LocalCLIEnhancementProvider(executablePath: executable)
        await provider.refreshAvailability()
        do {
            _ = try await provider.polish("hello", prompt: "polish this")
            XCTFail("Expected the stub provider to fail")
        } catch let error as LocalCLIEnhancementProvider.ProviderError {
            guard case .processFailed(let code, let message) = error else {
                return XCTFail("Expected processFailed, got \(error)")
            }
            XCTAssertEqual(code, 3)
            XCTAssertEqual(message, "boom")
        }
    }

    func testOllamaRoundTripWhenOptedIn() async throws {
        let requested = ProcessInfo.processInfo.environment["ECHOTUNE_OLLAMA_RUNTIME"] == "1"
            || UserDefaults.standard.bool(forKey: "phase10OllamaRuntime")
        try XCTSkipUnless(requested, "Opt-in local Ollama runtime test")
        let override = ProcessInfo.processInfo.environment["ECHOTUNE_OLLAMA_MODEL"]
        let provider = LocalCLIEnhancementProvider()
        if let override, !override.isEmpty {
            provider.updateModelName(override)
        }
        await provider.refreshAvailability()
        XCTAssertTrue(provider.isAvailable)
        let started = Date()
        let output = try await provider.polish(
            "the meeting is on monday at ten",
            prompt: "Correct capitalization and punctuation; return only the polished text."
        )
        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(cleaned.isEmpty)
        XCTAssertFalse(cleaned.contains("```"), "provider boundary must not leak fences")
        XCTAssertFalse(cleaned.lowercased().contains("<think"), "provider boundary must not leak reasoning tags")
        print("P10_RUNTIME ollamaModel=\(provider.modelName) elapsedSeconds=\(String(format: "%.3f", Date().timeIntervalSince(started)))")
    }

    private func makeStubOllama(_ contents: String) throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("echotune-p10-stub-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("ollama")
        try contents.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return executable.path
    }
}
