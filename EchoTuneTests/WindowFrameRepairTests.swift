import CoreGraphics
import Foundation
import Testing
@testable import EchoTune

/// Deterministic coverage for the frame-repair decisions. `WindowFrameRepair` is pure so
/// these tests pin down the exact behaviour that the live 7.6.7 dashboard stranding
/// exposed, without needing a window server.
struct WindowFrameRepairTests {

    /// The MacBook display the bug was reproduced on: 1470 x 956 with the menu bar and an
    /// always-visible Dock, so the usable area is 1470 x 833 starting at y = 90.
    private let visible = CGRect(x: 0, y: 90, width: 1470, height: 833)
    private let titleBarHeight: CGFloat = 28

    private func plan(_ appKit: CGRect, _ server: CGRect? = nil, recenter: Bool = true) -> WindowFrameRepair.Action {
        WindowFrameRepair.plan(
            appKitFrame: appKit,
            serverFrame: server,
            visibleFrame: visible,
            titleBarHeight: titleBarHeight,
            recenterIfUnreachable: recenter
        )
    }

    @Test func matchingFramesAreConsideredEqualWithinTolerance() {
        let a = CGRect(x: 100, y: 200, width: 800, height: 600)
        #expect(WindowFrameRepair.framesMatch(a, CGRect(x: 100.5, y: 199.5, width: 800.4, height: 600)))
        #expect(!WindowFrameRepair.framesMatch(a, CGRect(x: 102, y: 200, width: 800, height: 600)))
    }

    @Test func aReachableWindowInSyncWithWindowServerIsLeftAlone() {
        let frame = CGRect(x: 255, y: 54, width: 1031, height: 752)
        #expect(plan(frame, frame) == .none)
        #expect(plan(frame) == .none)
    }

    @Test func appKitDriftIsAdoptedWhenTheRealFrameIsStillReachable() {
        let appKit = CGRect(x: 255, y: 54, width: 1031, height: 752)
        let server = CGRect(x: 300, y: 120, width: 1031, height: 752)
        #expect(plan(appKit, server) == .adoptServerFrame(server))
    }

    /// The exact failure captured on 2026-11-21: WindowServer had the window at Quartz
    /// (-228, 897) — below a 956 pt display — while `NSWindow.frame` still reported the
    /// healthy-looking (255, 54). The old reachability check trusted AppKit, saw a usable
    /// title bar and did nothing, so the window stayed out of reach.
    @Test func windowServerTruthWinsWhenAppKitReportsAHealthyButWrongFrame() {
        let appKit = CGRect(x: 255, y: 54, width: 1031, height: 752)
        let serverInCocoa = CGRect(x: -228, y: 956 - 897 - 752, width: 1031, height: 752)

        // AppKit's frame on its own looks perfectly fine …
        #expect(plan(appKit) == .none)
        // … but the real frame is off screen, so it must be recentred.
        #expect(plan(appKit, serverInCocoa) == .recenter(CGRect(x: 219.5, y: 130.5, width: 1031, height: 752)))
    }

    @Test func anUnreachableWindowIsRecentredEvenWithoutAServerFrame() {
        let appKit = CGRect(x: 100, y: -900, width: 800, height: 600)
        #expect(plan(appKit) == .recenter(CGRect(x: 335, y: 206.5, width: 800, height: 600)))
    }

    @Test func draggingPastTheEdgeClampsInsteadOfJumpingWhenAskedTo() {
        // Slid off the right edge: only a sliver of the left edge remains.
        let appKit = CGRect(x: 1400, y: 200, width: 800, height: 600)
        #expect(plan(appKit, nil, recenter: false) == .clamp(CGRect(x: 1210, y: 200, width: 800, height: 600)))
    }

    @Test func clampingNeverLeavesTheTitleBarAboveTheScreen() {
        // Pushed up past the top edge (maxY beyond the visible top): the title bar is pulled
        // back down to the top of the usable area without moving x.
        let appKit = CGRect(x: 100, y: 1200, width: 800, height: 600)
        #expect(plan(appKit, nil, recenter: false) == .clamp(CGRect(x: 100, y: 895, width: 800, height: 600)))
    }

    @Test func aWindowLargerThanTheSpaceIsResizedToFitWhenRecentred() {
        let appKit = CGRect(x: -2000, y: -2000, width: 2000, height: 1200)
        let action = plan(appKit)
        guard case .recenter(let frame) = action else {
            Issue.record("expected a recentre, got \(action)")
            return
        }
        #expect(frame.width <= visible.width)
        #expect(frame.height <= visible.height)
        #expect(WindowFrameRepair.hasUsableTitleBar(frame, in: visible, titleBarHeight: titleBarHeight))
    }

    @Test func aWindowOnASecondaryDisplayToTheLeftIsReachableThere() {
        // Secondary display to the left: visible area in negative x.
        let secondScreenVisible = CGRect(x: -1920, y: -100, width: 1920, height: 1000)
        let frame = CGRect(x: -1500, y: 0, width: 900, height: 700)
        #expect(WindowFrameRepair.hasUsableTitleBar(frame, in: secondScreenVisible, titleBarHeight: titleBarHeight))
        #expect(WindowFrameRepair.plan(
            appKitFrame: frame,
            serverFrame: nil,
            visibleFrame: secondScreenVisible,
            titleBarHeight: titleBarHeight,
            recenterIfUnreachable: true
        ) == .none)
    }
}
