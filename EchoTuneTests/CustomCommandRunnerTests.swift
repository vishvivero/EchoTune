import Foundation
import Testing
@testable import EchoTune

/// ET-768 · post-transcription shell hook.
struct CustomCommandRunnerTests {

    /// Runs a command and waits for its completion (bounded).
    private func runAndWait(
        _ command: String,
        transcript: String,
        timeout: TimeInterval = 5
    ) async -> CustomCommandRunner.Result? {
        await withCheckedContinuation { continuation in
            let box = Box()
            _ = CustomCommandRunner.shared.run(command: command, transcript: transcript, timeout: timeout) { result in
                box.resume(result, continuation)
            }
            // Safety net so a broken runner cannot hang the suite.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout + 5) {
                box.resume(nil, continuation)
            }
        }
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func resume(_ result: CustomCommandRunner.Result?, _ continuation: CheckedContinuation<CustomCommandRunner.Result?, Never>) {
            lock.lock()
            if done { lock.unlock(); return }
            done = true
            lock.unlock()
            continuation.resume(returning: result)
        }
    }

    // MARK: Acceptance criteria

    @Test func transcriptIsAvailableOnStdinAndInTheEnvironment() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("echotune-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let out = dir.appendingPathComponent("out.txt")
        let command = "printf '%s' \"$\(CustomCommandRunner.transcriptEnvKey)\" > '\(out.path)'"

        let result = await runAndWait(command, transcript: "hello from the hook")
        #expect(result?.exitCode == 0)

        let written = try String(contentsOf: out, encoding: .utf8)
        #expect(written == "hello from the hook", "the env var must carry the transcript")
    }

    @Test func stdinCarriesTheTranscriptToo() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("echotune-hook-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let out = dir.appendingPathComponent("stdin.txt")
        let result = await runAndWait("cat > '\(out.path)'", transcript: "piped transcript")
        #expect(result?.exitCode == 0)
        #expect(try String(contentsOf: out, encoding: .utf8) == "piped transcript")
    }

    @Test func returnsImmediatelyInsteadOfBlockingTheCaller() async {
        // A detached runner hands back a Process immediately; the script keeps
        // running in the background. A blocking implementation would not return
        // until the 5-second sleep finished.
        let start = Date()
        let process = CustomCommandRunner.shared.run(command: "sleep 5", transcript: "x", timeout: 20)
        let handoff = Date().timeIntervalSince(start)

        #expect(process != nil)
        #expect(handoff < 1.0, "run() must return before the script completes (took \(handoff)s)")

        process?.terminate()
    }

    @Test func timesOutInsteadOfHanging() async {
        let start = Date()
        let result = await runAndWait("sleep 30", transcript: "x", timeout: 0.5)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 10, "the runner must not wait for the full sleep")
        #expect(result != nil, "a timed-out command must still report a result")
    }

    @Test func nonZeroExitIsReportedWithStderr() async {
        let result = await runAndWait("echo 'boom' >&2; exit 3", transcript: "x")
        #expect(result?.exitCode == 3)
        #expect(result?.standardError.contains("boom") == true)
    }

    @Test func emptyCommandIsIgnored() {
        #expect(CustomCommandRunner.shared.run(command: "   ", transcript: "x") == nil)
    }

    @Test func timeoutDefaultIsFifteenSeconds() {
        #expect(CustomCommandRunner.defaultTimeout == 15)
        #expect(CustomCommandRunner.transcriptEnvKey == "ECHOTUNE_TRANSCRIPT")
    }

    @Test func pipelineWiresTheHook() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/AppCoordinator+Transcription.swift")
        let source = try String(contentsOf: root, encoding: .utf8)
        #expect(source.contains("runPostTranscriptionCommand"))
        #expect(source.contains("runDetached"))
    }
}
