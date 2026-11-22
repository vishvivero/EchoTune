import AppKit
import Foundation
import Testing
@testable import EchoTune

/// Every window presentation has to go through the `AppDelegate`. It owns the single Dashboard
/// window, chooses the activation policy, escorts a window out of another app's full-screen
/// Space and re-centres it when WindowServer has moved it. Stray paths guessed a window by
/// title or used deprecated activation, and those are exactly the paths that left a window
/// stranded and unclickable.
@MainActor
@Suite(.serialized)
struct WindowPresentingConsolidationTests {

    private func settle() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    @Test func showMainWindowHotkeyPresentsTheDashboardNotWhateverWindowIsAround() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

        guard let delegate = AppDelegate.shared else {
            Issue.record("no app delegate")
            return
        }

        // The Settings window is titled "EchoTune Settings", so the old
        // `title.contains("EchoTune")` heuristic could raise it instead of the Dashboard.
        delegate.showSettings(tab: .general)
        try await settle()
        #expect(delegate.settingsWindow?.isVisible == true, "precondition: Settings is open")

        MultiHotkeyManager.shared.showMainWindow()
        try await settle()

        #expect(delegate.dashboardWindow?.isVisible == true, "the hotkey must present the Dashboard")
        let frontmost = NSApp.orderedWindows.first { $0.isVisible }
        #expect(frontmost === delegate.dashboardWindow, "the Dashboard must be brought to the front, not Settings")
    }

    /// Source-level guard: `ignoringOtherApps:` has been a no-op since macOS 14, so it only
    /// hides the fact that activation genuinely needs the policy handled (see AppDelegate).
    @Test func noSourceFileUsesTheDeprecatedActivationFlag() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let enumerator = FileManager.default.enumerator(
            at: repoRoot.appendingPathComponent("EchoTune"),
            includingPropertiesForKeys: nil
        )
        let sources = (enumerator?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
        #expect(!sources.isEmpty, "expected to find the app sources")

        for url in sources {
            let contents = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in contents.components(separatedBy: .newlines).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//") else { continue }
                #expect(
                    !code.contains("ignoringOtherApps:"),
                    "\(url.lastPathComponent):\(index + 1) uses the deprecated ignoringOtherApps flag; present the window through the AppDelegate instead"
                )
            }
        }
    }
}
