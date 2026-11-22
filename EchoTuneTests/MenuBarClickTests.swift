import AppKit
import Testing
@testable import EchoTune

/// Regression tests for the menu bar click handling.
///
/// Background: on macOS 26 Control Center owns the status item's window and is
/// supposed to forward the click back into the app. Measured on macOS 26.6 it does
/// not forward for EchoTune (a real click on the icon reaches nothing while the same
/// click opens Tailscale/Ollama/AlDente), so the controller watches the icon's own
/// rect instead. These tests pin the decision logic that makes that safe.
@MainActor
struct MenuBarClickTests {
    private let iconRect = CGRect(x: 900, y: 0, width: 36, height: 24)

    private func toggle(
        at point: CGPoint,
        shown: Bool = false,
        sincelastToggle: TimeInterval = 10,
        sinceClosed: TimeInterval = 10
    ) -> Bool {
        StatusItemClickDecision.shouldToggle(
            clickPoint: point,
            statusItemRect: iconRect,
            popoverIsShown: shown,
            secondsSinceLastToggle: sincelastToggle,
            secondsSincePopoverClosed: sinceClosed
        )
    }

    @Test func clickOnTheIconOpensThePopover() {
        #expect(toggle(at: CGPoint(x: 918, y: 12)))
    }

    @Test func clickOnTheIconClosesAnOpenPopover() {
        #expect(toggle(at: CGPoint(x: 918, y: 12), shown: true))
    }

    @Test func clickAnywhereElseDoesNotToggle() {
        #expect(!toggle(at: CGPoint(x: 500, y: 400)))
        #expect(!toggle(at: CGPoint(x: 918, y: 300)))
        #expect(!toggle(at: CGPoint(x: 850, y: 12)))
    }

    @Test func toleranceAroundTheIconStillCounts() {
        // A couple of points of slack absorbs the difference between the button's
        // frame and where the window server says the click landed.
        #expect(toggle(at: CGPoint(x: iconRect.minX - 2, y: 12)))
        #expect(toggle(at: CGPoint(x: iconRect.maxX + 2, y: 12)))
        #expect(!toggle(at: CGPoint(x: iconRect.maxX + 10, y: 12)))
    }

    @Test func aRepeatClickInsideTheCooldownIsIgnored() {
        // Guards the case where the button action and the monitor both fire for one
        // physical click.
        #expect(!toggle(at: CGPoint(x: 918, y: 12), sincelastToggle: 0.05))
        #expect(toggle(at: CGPoint(x: 918, y: 12), sincelastToggle: 1.0))
    }

    @Test func clickingTheIconDoesNotImmediatelyReopenAfterThePopoverSelfDismissed() {
        // Clicking the icon while the popover is open: the click goes to Control
        // Center, the .transient popover dismisses itself, and the monitor then sees
        // the same click. Without this guard the popover would reopen and the icon
        // would appear to do nothing.
        #expect(!toggle(at: CGPoint(x: 918, y: 12), shown: false, sinceClosed: 0.05))
        #expect(toggle(at: CGPoint(x: 918, y: 12), shown: false, sinceClosed: 5))
    }

    @Test func dismissOnlyAppliesToClicksAwayFromTheIconWhileOpen() {
        #expect(StatusItemClickDecision.shouldDismiss(
            clickPoint: CGPoint(x: 500, y: 400), statusItemRect: iconRect, popoverIsShown: true))
        #expect(!StatusItemClickDecision.shouldDismiss(
            clickPoint: CGPoint(x: 500, y: 400), statusItemRect: iconRect, popoverIsShown: false))
        #expect(!StatusItemClickDecision.shouldDismiss(
            clickPoint: CGPoint(x: 918, y: 12), statusItemRect: iconRect, popoverIsShown: true))
    }
}
