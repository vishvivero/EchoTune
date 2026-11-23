//
//  CustomCommandRunner.swift
//  EchoTune
//
//  ET-768 · run a shell command after each transcription.
//
//  WHY THIS EXISTS
//  ---------------
//  "Dictate, then automatically…" is the last mile of a dictation workflow:
//  append the note to Obsidian, POST it to a webhook, push it to a task tracker.
//  The transcript is the input; the user's own script decides what happens next.
//
//  SAFETY AND BEHAVIOUR
//  --------------------
//  · Runs fully detached, off the main thread — dictation never waits on it.
//  · The transcript is passed BOTH as stdin and as `$ECHOTUNE_TRANSCRIPT`, so a
//    script can `cat` it or reference it directly.
//  · Hard 15-second timeout, then SIGTERM followed by SIGKILL, so a wedged
//    script cannot accumulate one process per dictation.
//  · Never inherits the app's file descriptors it does not need.
//

import Foundation

final class CustomCommandRunner {

    static let shared = CustomCommandRunner()

    /// Environment variable carrying the transcript.
    static let transcriptEnvKey = "ECHOTUNE_TRANSCRIPT"
    /// Default hard timeout.
    static let defaultTimeout: TimeInterval = 15

    private init() {}

    struct Result: Equatable {
        let exitCode: Int32
        let timedOut: Bool
        let standardError: String
    }

    /// Runs `command` with `/bin/zsh -lc`, detached from the caller.
    ///
    /// The completion runs on a background queue; callers that touch UI must hop
    /// to the main actor themselves.
    @discardableResult
    func run(
        command: String,
        transcript: String,
        timeout: TimeInterval = CustomCommandRunner.defaultTimeout,
        completion: ((Result) -> Void)? = nil
    ) -> Process? {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", trimmedCommand]

        var environment = ProcessInfo.processInfo.environment
        environment[Self.transcriptEnvKey] = transcript
        // Keep the child's view of the world predictable.
        environment["ECHOTUNE_HOOK"] = "post-transcription"
        process.environment = environment

        let stdinPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            debugLog("🔗 Post-transcription hook failed to launch: \(error.localizedDescription)")
            return nil
        }

        // Feed the transcript on stdin, then close it so the script sees EOF.
        if let data = transcript.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
        try? stdinPipe.fileHandleForWriting.close()

        // Hard timeout: SIGTERM, then SIGKILL if it ignores that.
        let deadline = DispatchTime.now() + timeout
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline) {
            guard process.isRunning else { return }
            debugLog("⏱️ Post-transcription hook timed out after \(Int(timeout))s — terminating")
            process.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }

        process.terminationHandler = { finished in
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let timedOut = finished.terminationReason == .uncaughtSignal
            let result = Result(exitCode: finished.terminationStatus, timedOut: timedOut, standardError: stderr)
            if result.exitCode != 0 {
                debugLog("⚠️ Post-transcription hook exited \(result.exitCode): \(stderr.prefix(200))")
            }
            completion?(result)
        }

        return process
    }

    /// Fire-and-forget variant used by the transcription pipeline.
    func runDetached(command: String, transcript: String, timeout: TimeInterval = CustomCommandRunner.defaultTimeout) {
        run(command: command, transcript: transcript, timeout: timeout, completion: nil)
    }
}