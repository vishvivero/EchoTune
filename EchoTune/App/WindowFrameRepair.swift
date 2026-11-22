//
//  WindowFrameRepair.swift
//  EchoTune
//
//  Pure decision logic for keeping a standard window where the user can actually grab it.
//

import CoreGraphics

/// Decides how to keep a window reachable and in sync with WindowServer.
///
/// Extracted from `AppDelegate` so it can be unit-tested without a window server: given what
/// AppKit thinks the frame is, what WindowServer says it really is, and the Space's visible
/// area, it returns the one action to take.
///
/// Why WindowServer is the source of truth: `NSWindow.frame` is AppKit's *model*. macOS can
/// relocate a window behind AppKit's back — observed live when a window that had been ordered
/// into another app's full-screen Space was re-laid-out on display wake, ending up at Quartz
/// y=897 on a 956 pt display while `NSWindow.frame` still reported y=54. The window then looks
/// perfectly placed to AppKit, a naive reachability check sees nothing wrong, and the user is
/// left with a window they cannot click or close.
enum WindowFrameRepair {

    /// Frames closer together than this are treated as identical.
    static let tolerance: CGFloat = 1

    /// Minimum sliver of the window that must be inside `visibleFrame`: the whole title bar
    /// plus a wide grab area, so the traffic lights and title-bar drag stay usable.
    static let minimumGrabbableWidth: CGFloat = 260

    enum Action: Equatable {
        /// The window is reachable and AppKit agrees with WindowServer: do nothing.
        case none
        /// AppKit's model has drifted from reality; adopt WindowServer's frame.
        case adoptServerFrame(CGRect)
        /// The window has no usable title bar; put it back in the middle of the Space.
        case recenter(CGRect)
        /// The window has drifted past an edge; pull it back without jumping.
        case clamp(CGRect)
    }

    static func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    static func hasUsableTitleBar(_ frame: CGRect, in visible: CGRect, titleBarHeight: CGFloat) -> Bool {
        let requiredWidth = min(frame.width, minimumGrabbableWidth)
        let requiredHeight = titleBarHeight + 40
        return frame.maxY <= visible.maxY + 0.5
            && frame.maxY >= visible.minY + requiredHeight
            && frame.maxX >= visible.minX + requiredWidth
            && frame.minX <= visible.maxX - requiredWidth
    }

    static func recentered(_ frame: CGRect, in visible: CGRect) -> CGRect {
        let size = CGSize(
            width: min(frame.width, visible.width),
            height: min(frame.height, visible.height)
        )
        return CGRect(
            x: visible.minX + (visible.width - size.width) / 2,
            y: visible.minY + (visible.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    static func clamped(_ frame: CGRect, in visible: CGRect, titleBarHeight: CGFloat) -> CGRect {
        let requiredWidth = min(frame.width, minimumGrabbableWidth)
        let requiredHeight = titleBarHeight + 40
        let x = Swift.min(Swift.max(frame.minX, visible.minX), Swift.max(visible.minX, visible.maxX - requiredWidth))
        let y = Swift.min(Swift.max(frame.minY, visible.minY + requiredHeight - frame.height), visible.maxY - titleBarHeight)
        return CGRect(x: x, y: y, width: frame.width, height: frame.height)
    }

    /// The frame to reason about, and whether AppKit's model had drifted from it.
    static func sourceOfTruth(appKitFrame: CGRect, serverFrame: CGRect?) -> (frame: CGRect, drifted: Bool) {
        guard let serverFrame, !framesMatch(serverFrame, appKitFrame) else {
            return (appKitFrame, false)
        }
        return (serverFrame, true)
    }

    static func plan(
        appKitFrame: CGRect,
        serverFrame: CGRect?,
        visibleFrame: CGRect,
        titleBarHeight: CGFloat,
        recenterIfUnreachable: Bool
    ) -> Action {
        let (truth, drifted) = sourceOfTruth(appKitFrame: appKitFrame, serverFrame: serverFrame)

        if !hasUsableTitleBar(truth, in: visibleFrame, titleBarHeight: titleBarHeight) {
            return recenterIfUnreachable
                ? .recenter(recentered(truth, in: visibleFrame))
                : .clamp(clamped(truth, in: visibleFrame, titleBarHeight: titleBarHeight))
        }

        return drifted ? .adoptServerFrame(truth) : .none
    }
}
