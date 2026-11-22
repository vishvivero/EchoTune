import AppKit
import Foundation
import Testing
@testable import EchoTune

/// Escape hatches only matter for a window the user cannot reach with the mouse, so they are
/// driven directly against the live app delegate in the test host rather than through the
/// menu bar (whose AX surface cannot be scripted reliably).
// Serialized: every test here drives the app's one Dashboard window, so running them
// concurrently would have them closing each other's windows.
@MainActor
@Suite(.serialized)
struct WindowEscapeHatchTests {

    private var appDelegate: AppDelegate? { AppDelegate.shared }

    private func waitUntilWindowIsGone(_ appDelegate: AppDelegate) async throws {
        var attempts = 0
        while appDelegate.hasVisibleStandardWindow && attempts < 30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
    }

    @Test func menuBarEscapeHatchClosesTheDashboardWindow() async throws {
        guard let appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        appDelegate.showDashboard(item: .home)
        #expect(appDelegate.hasVisibleStandardWindow, "showing the Dashboard should put a window on screen")

        // Same call the "Close Dashboard Window" menu-bar item makes.
        appDelegate.closeStandardWindow()
        try await waitUntilWindowIsGone(appDelegate)

        #expect(!appDelegate.hasVisibleStandardWindow, "the menu-bar close item must be able to close the window")
    }

    @Test func escapeClosesTheDashboardWindow() async throws {
        guard let appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        appDelegate.showDashboard(item: .home)
        guard let window = appDelegate.dashboardWindow as? ActivatingStandardWindow else {
            Issue.record("the Dashboard should be an ActivatingStandardWindow")
            return
        }

        // What AppKit sends when Escape is pressed.
        window.cancelOperation(nil)
        try await waitUntilWindowIsGone(appDelegate)

        #expect(!appDelegate.hasVisibleStandardWindow, "Escape should close the window")
    }

    @Test func escapeIsIgnoredWhileEditingText() async throws {
        guard let appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        appDelegate.showDashboard(item: .home)
        guard let window = appDelegate.dashboardWindow as? ActivatingStandardWindow else {
            Issue.record("the Dashboard should be an ActivatingStandardWindow")
            return
        }

        // A field editor in the responder chain treats Escape as "revert this field";
        // closing the window out from under it would discard what the user typed.
        let fieldEditor = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
        window.contentView?.addSubview(fieldEditor)
        defer { fieldEditor.removeFromSuperview() }
        #expect(window.makeFirstResponder(fieldEditor))

        window.cancelOperation(nil)
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(appDelegate.hasVisibleStandardWindow, "Escape must not close the window while text is being edited")
    }

    @Test func closingWithNoWindowOpenIsSafe() async throws {
        guard let appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        appDelegate.closeStandardWindow()
        try await waitUntilWindowIsGone(appDelegate)
        #expect(!appDelegate.hasVisibleStandardWindow)

        // A second call must be a harmless no-op.
        appDelegate.closeStandardWindow()
        #expect(!appDelegate.hasVisibleStandardWindow)
    }
}
