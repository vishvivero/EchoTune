import AppKit
import Foundation
@testable import EchoTune

/// Serializes the tests that drive the app's real windows.
///
/// swift-testing runs suites in parallel (and `@Suite(.serialized)` only serializes within one
/// suite), while these tests all present and close the app's single Dashboard window in the
/// running test host. Without a shared gate they close each other's windows and fail
/// intermittently. Acquire it for the whole test body:
///
/// ```swift
/// await AppWindowTestGate.acquire()
/// defer { AppWindowTestGate.release() }
/// ```
@MainActor
enum AppWindowTestGate {
    private static var isBusy = false

    /// Waits until no other window-driving test is running, then takes the gate.
    static func acquire() async {
        while isBusy {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        isBusy = true
    }

    static func release() {
        isBusy = false
    }
}

extension AppWindowTestGate {
    /// Records the app's window state so an intermittent failure explains itself.
    /// Appends to /tmp/et-window-test-diag.txt.
    @MainActor
    static func recordDiagnostics(_ label: String, _ delegate: AppDelegate) {
        func describe(_ name: String, _ window: NSWindow?) -> String {
            guard let window else { return "\(name)=nil" }
            return "\(name)=[visible:\(window.isVisible) key:\(window.isKeyWindow) main:\(window.isMainWindow) mini:\(window.isMiniaturized)]"
        }
        var out = "== \(label) (pid \(ProcessInfo.processInfo.processIdentifier))\n"
        out += "  " + [
            describe("dashboard", delegate.dashboardWindow),
            describe("settings", delegate.settingsWindow),
            describe("onboarding", delegate.onboardingWindow),
            describe("profile", delegate.echoProfileWindowController?.window),
            describe("tasks", delegate.commitmentsWindowController?.window)
        ].joined(separator: " ") + "\n"
        out += "  hasVisibleStandardWindow=\(delegate.hasVisibleStandardWindow) keyWindow=\(NSApp.keyWindow?.title ?? "nil") mainWindow=\(NSApp.mainWindow?.title ?? "nil")\n"
        out += "  NSApp.windows: " + NSApp.windows.map { "'\($0.title)'[visible:\($0.isVisible)]" }.joined(separator: " ") + "\n"

        let url = URL(fileURLWithPath: "/tmp/et-window-test-diag.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(out.utf8))
            try? handle.close()
        } else {
            try? out.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
