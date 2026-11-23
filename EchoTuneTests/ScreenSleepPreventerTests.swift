import Foundation
import Testing
@testable import EchoTune

/// ET-760 · display-sleep assertion held only while dictating.
struct ScreenSleepPreventerTests {

    /// Is an EchoTune display-sleep assertion currently registered?
    /// `pmset -g assertions` prints the descriptive name as `named: "<name>"`.
    private func hasDisplaySleepAssertion() -> Bool {
        assertionLines().contains { $0.contains("named: \"\(ScreenSleepPreventer.assertionName)\"") }
    }

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

    /// Kept for diagnostics in failure messages.
    private func assertionNames() -> [String] {
        assertionLines()
            .filter { $0.contains("named:") }
    }

    @Test func assertionIsHeldWhileRecordingAndReleasedAfter() {
        let preventer = ScreenSleepPreventer.shared
        preventer.end()

        #expect(preventer.begin() == true)
        #expect(preventer.isHolding == true)

        // The assertion shows up in the system table under our name.
        #expect(hasDisplaySleepAssertion(),
                "expected an assertion named '\(ScreenSleepPreventer.assertionName)'; saw: \(assertionNames())")

        preventer.end()
        #expect(preventer.isHolding == false)
    }

    @Test func beginIsIdempotent() {
        let preventer = ScreenSleepPreventer.shared
        preventer.end()

        #expect(preventer.begin() == true)
        #expect(preventer.begin() == true, "a second begin() must not leak a second assertion")
        #expect(preventer.isHolding == true)

        preventer.end()
        #expect(preventer.isHolding == false)
    }

    @Test func endWithoutBeginIsSafe() {
        let preventer = ScreenSleepPreventer.shared
        preventer.end()
        preventer.end()
        #expect(preventer.isHolding == false)
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
