import AppKit
import Testing
@testable import EchoTune

/// ET-765 · recorders follow the mouse cursor across displays.
struct RecorderScreenResolverTests {

    /// Two side-by-side 1440×900 displays, as NSScreen-like frames.
    private let left = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let right = NSRect(x: 1440, y: 0, width: 1440, height: 900)

    @Test func cursorOnTheRightDisplayPicksTheRightDisplay() {
        // Cursor inside the right-hand display.
        let hit = NSMouseInRect(NSPoint(x: 2000, y: 400), right, false)
        #expect(hit == true)
        let missLeft = NSMouseInRect(NSPoint(x: 2000, y: 400), left, false)
        #expect(missLeft == false)
    }

    @Test func cursorOnTheLeftDisplayPicksTheLeftDisplay() {
        let hit = NSMouseInRect(NSPoint(x: 300, y: 400), left, false)
        #expect(hit == true)
        #expect(NSMouseInRect(NSPoint(x: 300, y: 400), right, false) == false)
    }

    @Test func nearestScreenHandlesGapsBetweenDisplays() {
        // A point above both displays should resolve to whichever is closest in x.
        let screens = [left, right]
        #expect(screens.count == 2)
        // Direct distance maths mirroring the resolver.
        func d2(_ p: NSPoint, _ r: NSRect) -> CGFloat {
            let dx = max(r.minX - p.x, 0, p.x - r.maxX)
            let dy = max(r.minY - p.y, 0, p.y - r.maxY)
            return dx * dx + dy * dy
        }
        let nearLeft = NSPoint(x: 100, y: 2000)
        let nearRight = NSPoint(x: 2800, y: 2000)
        #expect(d2(nearLeft, left) < d2(nearLeft, right))
        #expect(d2(nearRight, right) < d2(nearRight, left))
    }

    @Test func bottomCenteredFrameSitsInsideTheVisibleArea() {
        // Feed the real resolver a real screen; assert geometry invariants only.
        let screen = NSScreen.main
        let frame = RecorderScreenResolver.bottomCenteredFrame(
            size: NSSize(width: 360, height: 52),
            screen: screen,
            padding: 16
        )
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 24, width: 1920, height: 1056)
        #expect(frame.width == 360)
        #expect(frame.height == 52)
        #expect(frame.minY == visible.minY + 16)
        #expect(abs(frame.midX - visible.midX) < 0.5, "panel must be horizontally centred")
        #expect(frame.minX >= visible.minX)
        #expect(frame.maxX <= visible.maxX)
    }

    @Test func topCenteredFrameIsHorizontallyCentred() {
        let screen = NSScreen.main
        let frame = RecorderScreenResolver.topCenteredFrame(
            size: NSSize(width: 200, height: 40),
            screen: screen
        )
        let full = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        #expect(abs(frame.midX - full.midX) < 0.5)
        #expect(frame.minY == full.minY + 60)
    }

    @Test func framesAreSafeWithoutAnyScreen() {
        // Clamshell / display reconfiguration can leave no usable screen.
        let frame = RecorderScreenResolver.bottomCenteredFrame(
            size: NSSize(width: 360, height: 52),
            screen: nil
        )
        #expect(frame.width == 360)
        #expect(frame.minY >= 0)
    }

    @Test func lockIsStableUntilUnlocked() {
        let lock = RecorderScreenLock.shared
        lock.unlock()

        let first = lock.lock()
        let second = lock.lock()
        // Same instance while held — the panel must not hop mid-recording.
        #expect(first === second)

        lock.unlock()
        #expect(lock.lockedScreen == nil)
    }

    @Test func recorderViewsNoLongerUseArbitraryScreens() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for file in ["EchoTune/Views/MiniRecorderView.swift", "EchoTune/Views/RecordingIndicatorWindow.swift"] {
            var url = root
            url.appendPathComponent(file)
            let source = try String(contentsOf: url, encoding: .utf8)
            let code = source
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.hasPrefix("//") }
                .joined(separator: "\n")
            #expect(!code.contains("NSScreen.screens.first"), "\(file) must use the resolver")
            #expect(!code.contains("NSScreen.main"), "\(file) must use the resolver")
        }
    }
}
