import AppKit
import Foundation
import Testing
@testable import EchoTune

/// SwiftUI owns a lifecycle app's `NSApp.delegate` (it is SwiftUI's own wrapper object), so
/// `NSApp.delegate as? AppDelegate` compiles but is always nil. Every menu-bar item and
/// status-icon update in EchoTune used to go through that cast, which turned them into
/// silent no-ops: the status icon never reflected the recording state, and clicking
/// "Open EchoTune Dashboard", "Settings…", "Tasks", "Echo Profile" and the menu card's own
/// buttons did nothing at all.
// Serialized: every test here drives the app's one Dashboard window, so running them
// concurrently would have them closing each other's windows.
@MainActor
@Suite(.serialized)
struct AppDelegateReachabilityTests {

    private func settle() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    @Test func theDelegateIsReachableThroughItsOwnRegistry() {
        #expect(AppDelegate.shared != nil, "the app delegate must publish itself, since SwiftUI keeps NSApp.delegate")
    }

    @Test func theStatusBarControllerIsReachableSoIconUpdatesApply() {
        #expect(AppDelegate.shared?.statusBarController != nil, "status icon updates go through the delegate")
    }

    /// Source-level guard: this cast looks correct and silently does nothing.
    @Test func noSourceFileCastsTheSwiftUIAppDelegateWrapper() throws {
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
                    !code.contains("NSApp.delegate as? AppDelegate"),
                    "\(url.lastPathComponent):\(index + 1) casts SwiftUI's delegate wrapper, which is never our AppDelegate — use AppDelegate.shared"
                )
            }
        }
    }

    /// The menu-bar openers were the most user-visible casualty, so drive them for real.
    @Test func menuBarOpenersPresentTheirWindows() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

        guard let delegate = AppDelegate.shared else {
            Issue.record("no app delegate")
            return
        }

        delegate.showSettings(tab: .general)
        try await settle()
        #expect(delegate.settingsWindow?.isVisible == true, "Settings… should open the Settings window")
        delegate.settingsWindow?.close()
        try await settle()

        delegate.showEchoProfile()
        try await settle()
        #expect(delegate.echoProfileWindowController?.window?.isVisible == true, "Echo Profile should open its window")
        delegate.echoProfileWindowController?.close()
        try await settle()

        delegate.showCommitments()
        try await settle()
        #expect(delegate.commitmentsWindowController?.window?.isVisible == true, "Tasks & Commitments should open its window")
        delegate.commitmentsWindowController?.close()
        try await settle()
    }

    /// The Dashboard opener is the one a user reaches for from the menu bar.
    @Test func dashboardOpenerPresentsTheDashboard() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

        guard let delegate = AppDelegate.shared else {
            Issue.record("no app delegate")
            return
        }

        delegate.showDashboard(item: .home)
        try await settle()
        #expect(delegate.dashboardWindow?.isVisible == true, "Open EchoTune Dashboard should present the Dashboard")

        delegate.closeStandardWindow()
        var attempts = 0
        while delegate.dashboardWindow?.isVisible == true && attempts < 30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        #expect(delegate.dashboardWindow?.isVisible != true)
    }
}
