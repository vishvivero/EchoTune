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

    /// Waits for the Dashboard to be gone for good. Scoped to the Dashboard so other windows
    /// cannot make this test pass or fail, and it counts a Dock window as still present.
    private func waitUntilWindowIsGone(_ delegate: AppDelegate) async throws {
        func isStillAround() -> Bool {
            guard let window = delegate.dashboardWindow else { return false }
            return window.isVisible || window.isMiniaturized
        }
        var attempts = 0
        while isStillAround() && attempts < 30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
    }

    @Test func menuBarEscapeHatchClosesTheDashboardWindow() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

        guard let appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        appDelegate.showDashboard(item: .home)
        #expect(appDelegate.hasVisibleStandardWindow, "showing the Dashboard should put a window on screen")

        // Same call the "Close Dashboard Window" menu-bar item makes.
        appDelegate.closeStandardWindow()
        try await waitUntilWindowIsGone(appDelegate)

        if appDelegate.dashboardWindow?.isVisible == true {
            AppWindowTestGate.recordDiagnostics("menu-bar escape hatch close", appDelegate)
        }
        #expect(appDelegate.dashboardWindow?.isVisible != true, "the menu-bar close item must be able to close the window")
    }

    @Test func escapeClosesTheDashboardWindow() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

        guard let delegate = appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        delegate.showDashboard(item: .home)
        guard let window = delegate.dashboardWindow as? ActivatingStandardWindow else {
            Issue.record("the Dashboard should be an ActivatingStandardWindow")
            return
        }

        // What AppKit sends when Escape is pressed.
        window.cancelOperation(nil)
        try await waitUntilWindowIsGone(delegate)

        if delegate.dashboardWindow?.isVisible == true {
            AppWindowTestGate.recordDiagnostics("escape close", delegate)
        }
        #expect(delegate.dashboardWindow?.isVisible != true, "Escape should close the window")
    }

    @Test func escapeIsIgnoredWhileEditingText() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

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

        if appDelegate.dashboardWindow?.isVisible != true {
            AppWindowTestGate.recordDiagnostics("escape while editing (window went away)", appDelegate)
        }
        #expect(appDelegate.dashboardWindow?.isVisible == true, "Escape must not close the window while text is being edited")
    }

    @Test func closingWithNoWindowOpenIsSafe() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

        guard let appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        appDelegate.closeStandardWindow()
        try await waitUntilWindowIsGone(appDelegate)
        #expect(appDelegate.dashboardWindow?.isVisible != true)

        // A second call must be a harmless no-op.
        appDelegate.closeStandardWindow()
        #expect(appDelegate.dashboardWindow?.isVisible != true)
    }

    /// A miniaturized window lives in the Dock, which is somewhere the user can still reach it,
    /// so it must keep the app in `.regular` (the Dock icon is the only way back) and it must
    /// stay closeable from the menu bar.
    @Test func aDockWindowStaysReachableAndClosesFromTheMenuBar() async throws {
        await AppWindowTestGate.acquire()
        defer { AppWindowTestGate.release() }

        guard let delegate = appDelegate else {
            Issue.record("EchoTune is not running its AppDelegate")
            return
        }

        delegate.showDashboard(item: .home)
        try await Task.sleep(nanoseconds: 400_000_000)
        delegate.dashboardWindow?.miniaturize(nil)
        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(delegate.dashboardWindow?.isMiniaturized == true, "precondition: the Dashboard is in the Dock")
        #expect(delegate.hasVisibleStandardWindow, "a window in the Dock is still a window the user can reach")
        // The invariant that matters: a window exists, so the app must not be a background agent
        // (an .accessory app cannot show usable traffic lights and would have no Dock icon).
        #expect(NSApp.activationPolicy() == .regular, "the Dock icon must stay while a window exists")

        delegate.closeStandardWindow()
        try await waitUntilWindowIsGone(delegate)

        #expect(delegate.hasVisibleStandardWindow == false, "the menu bar must be able to close a window sitting in the Dock")
    }
}
