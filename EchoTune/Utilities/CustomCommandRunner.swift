//
//  CustomCommandRunner.swift
//  EchoTune
//
//  Executes an optional user-configured shell command on finalized transcripts
//  (per Power Mode or global post-transcription hook). Passes the transcript
//  via stdin and `ECHOTUNE_TRANSCRIPT` / `ECHOTUNE_RAW_TRANSCRIPT` /
//  `ECHOTUNE_APP_BUNDLE_ID` environment variables, with a 15-second timeout.
//

import AppKit
import Foundation

enum CustomCommandRunner {
    static let globalCommandDefaultsKey = "globalPostTranscriptionCommand"

    static func runIfConfigured(
        command rawCommand: String?,
        transcript: String,
        rawTranscript: String
    ) {
        let cmd = (rawCommand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty, !transcript.isEmpty else { return }

        let appBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""

        Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", cmd]

            var env = ProcessInfo.processInfo.environment
            env["ECHOTUNE_TRANSCRIPT"] = transcript
            env["ECHOTUNE_RAW_TRANSCRIPT"] = rawTranscript
            env["ECHOTUNE_APP_BUNDLE_ID"] = appBundleID
            process.environment = env

            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                if let inputData = transcript.data(using: .utf8) {
                    try? stdinPipe.fileHandleForWriting.write(contentsOf: inputData)
                }
                try? stdinPipe.fileHandleForWriting.close()

                // Enforce 15s wall-clock timeout
                let deadline = Date().addingTimeInterval(15.0)
                while process.isRunning && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                if process.isRunning {
                    process.terminate()
                    debugLog("⚠️ Custom shell command timed out after 15s")
                } else {
                    debugLog("✓ Custom shell command exited (\(process.terminationStatus))")
                }
            } catch {
                debugLog("❌ Custom shell command failed to launch: \(error.localizedDescription)")
            }
        }
    }
}
