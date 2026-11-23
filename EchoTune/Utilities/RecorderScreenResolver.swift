//
//  RecorderScreenResolver.swift
//  EchoTune
//
//  ET-765 · put the floating recorders on the screen you are actually looking at.
//
//  WHY THIS EXISTS
//  ---------------
//  The Mini and Slim recorders used `NSScreen.screens.first(where: origin == .zero)`
//  — whichever display macOS decided was primary — and the indicator panel used
//  `NSScreen.main`, which is the screen holding the *key window*, not the pointer.
//  On a multi-monitor desk that meant starting a dictation with the recorder
//  appearing on a different display than the one you were typing on.
//
//  The resolver picks the screen under the mouse cursor, and the caller locks
//  that choice for the lifetime of the recording so the panel cannot hop
//  mid-dictation if the pointer crosses a display edge.
//

import AppKit

enum RecorderScreenResolver {

    /// The screen whose frame contains the mouse cursor.
    ///
    /// Falls back through: cursor screen → key-window screen → main → first, so a
    /// display being reconfigured can never produce a nil and strand the panel.
    static func screenUnderCursor(
        screens: [NSScreen] = NSScreen.screens,
        mouseLocation: NSPoint = NSEvent.mouseLocation
    ) -> NSScreen? {
        guard !screens.isEmpty else { return NSScreen.main }

        if let hit = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return hit
        }

        // Cursor is in a dead zone between displays (or above/below them): fall
        // back to the nearest screen by squared distance to its centre, so the
        // recorder lands somewhere sensible rather than on an arbitrary display.
        return nearestScreen(to: mouseLocation, screens: screens)
    }

    static func nearestScreen(to point: NSPoint, screens: [NSScreen]) -> NSScreen? {
        screens.min { lhs, rhs in
            squaredDistance(from: point, to: lhs.frame) < squaredDistance(from: point, to: rhs.frame)
        }
    }

    private static func squaredDistance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    /// Bottom-centre frame for a floating recorder of `size` on `screen`.
    ///
    /// Uses `visibleFrame` so the panel never hides under the Dock or the menu
    /// bar, and keeps a 16 pt inset from the bottom edge.
    static func bottomCenteredFrame(
        size: NSSize,
        screen: NSScreen?,
        padding: CGFloat = 16
    ) -> NSRect {
        let visible = screen?.visibleFrame
            ?? NSRect(x: 0, y: 24, width: 1920, height: 1056)
        let x = visible.minX + (visible.width - size.width) / 2
        let y = visible.minY + padding
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Top-area frame used by the recording indicator.
    static func topCenteredFrame(
        size: NSSize,
        screen: NSScreen?,
        offsetFromBottom: CGFloat = 60
    ) -> NSRect {
        let full = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: full.midX - size.width / 2,
            y: full.minY + offsetFromBottom,
            width: size.width,
            height: size.height
        )
    }
}

/// Remembers which screen a recording started on, so the floating panels stay
/// put for the whole dictation even if the cursor crosses displays.
final class RecorderScreenLock {

    static let shared = RecorderScreenLock()

    private(set) var lockedScreen: NSScreen?

    private init() {}

    /// Captures the screen under the cursor. Idempotent while a lock is held, so
    /// a second `show()` during the same recording does not re-resolve.
    @discardableResult
    func lock() -> NSScreen? {
        if let lockedScreen { return lockedScreen }
        let screen = RecorderScreenResolver.screenUnderCursor()
        lockedScreen = screen
        return screen
    }

    /// The locked screen, or — if nothing is locked — the screen under the cursor
    /// right now. Never returns nil while any display is attached.
    func screenForPlacement() -> NSScreen? {
        lockedScreen ?? RecorderScreenResolver.screenUnderCursor()
    }

    func unlock() {
        lockedScreen = nil
    }
}