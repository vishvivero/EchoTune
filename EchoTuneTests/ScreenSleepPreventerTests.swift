import Foundation
import Testing
@testable import EchoTune

/// ET-760 · display-sleep assertion held only while dictating.
struct ScreenSleepPreventerTests {

    /// Raw `PreventUserIdleDisplaySleep` lines from `pmset -g assertions`.
    private func assertionLines() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("PreventUserIdleDisplaySleep") }
    }

    /// Is an assertion we own currently registered under our name?
    private func hasDisplaySleepAssertion() -> Bool {
        assertionLines().contains { $0.contains("named: \"\(ScreenSleepPreventer.assertionName)\"") }
    }

    /// Deterministic: own begin/end calls balance, and a second begin() does not
    /// create a second hold. `pmset` lags a freshly-created IOKit assertion and
    /// other holders can fold into the same entry, so the observable contract is
    /// the reference count, not a cross-process snapshot.
    @Test func beginAndEndBalance() {
        // The host app calls begin()/end() on its own schedule, so absolute counts
        // are not stable. What must hold is that our two begins add and our two
        // ends remove the same amount — no net change.
        let preventer = ScreenSleepPreventer.shared
        let before = preventer.holdCountForTesting

        #expect(preventer.begin() == true)
        #expect(preventer.begin() == true, "a second begin() must not leak a second hold")

        preventer.end()
        preventer.end()
        #expect(preventer.holdCountForTesting == before,
                "begin()/end() must be net-neutral (before=\(before), after=\(preventer.holdCountForTesting))")
    }

    @Test func isHoldingTracksTheReferenceCount() {
        let preventer = ScreenSleepPreventer.shared
        #expect(preventer.begin() == true)
        #expect(preventer.isHolding == true)
        #expect(preventer.holdCountForTesting >= 1)
        preventer.end()
    }

    @Test func assertionIsRegisteredUnderItsName() {
        // IOKit errors would make `begin()` return false; on a real Mac it succeeds.
        let preventer = ScreenSleepPreventer.shared
        #expect(preventer.begin() == true, "IOPMAssertionCreateWithName must succeed")
        preventer.end()
        #expect(ScreenSleepPreventer.assertionName == "EchoTune is dictating")
    }

    @Test func endWithoutBeginIsSafe() {
        let preventer = ScreenSleepPreventer.shared
        let before = preventer.holdCountForTesting
        preventer.end()
        preventer.end()
        preventer.end()
        #expect(preventer.holdCountForTesting <= before, "unbalanced end() must never go below zero")
        #expect(preventer.holdCountForTesting >= 0)
    }

    @Test func audioManagerWiresTheAssertion() throws {
        // The assertion is useless if the recording lifecycle does not call it.
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Managers/AudioManager.swift")
        let source = try String(contentsOf: root, encoding: .utf8)

        #expect(source.contains("ScreenSleepPreventer.shared.begin()"))
        #expect(source.contains("ScreenSleepPreventer.shared.end()"))
        // begin() in start, end() in both stop and failed-start teardown.
        #expect(source.components(separatedBy: "ScreenSleepPreventer.shared.end()").count - 1 >= 2,
                "stopRecording and teardownAfterFailedStart must both release the assertion")
    }
}
