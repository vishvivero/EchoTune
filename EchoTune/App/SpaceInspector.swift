//
//  SpaceInspector.swift
//  EchoTune
//
//  macOS Spaces (virtual desktops) awareness, used to present a standard window
//  somewhere the user can actually see, click and close it.
//

import AppKit
import os.log

/// Window/Space decisions are logged so a stranded-window report can be diagnosed from
/// a sysdiagnose. Never logs transcripts.
let spaceLog = Logger(subsystem: "com.echotune.EchoTune", category: "WindowSpace")

/// Read/write access to the macOS Spaces (virtual desktop) state that EchoTune needs in
/// order to present a standard window safely.
///
/// EchoTune is a menu-bar (`.accessory`) app that also owns standard windows (Dashboard,
/// Settings, Onboarding, …). Two things go wrong when such a window is presented while
/// another app's **full-screen Space** is active:
///
/// 1. The window is ordered into that foreign Space. It receives no menu bar, WindowServer
///    owns its frame (so `NSWindow.frame` silently drifts out of sync with what is actually
///    on screen) and most clicks land on the app behind it.
/// 2. Promoting `.accessory` → `.regular` and calling `NSApp.activate()` does not make
///    macOS leave that Space or hand EchoTune focus, so the traffic lights stay inert and
///    the window cannot be closed.
///
/// The user-visible symptom is *"the window is there but nothing is clickable and I can't
/// close it"*. This type lets the app detect that situation before presenting, and re-home
/// an already-stuck window onto a Desktop Space when it has already happened.
///
/// AppKit exposes no public Spaces API, so the queries go through the private SkyLight
/// (CoreGraphics Services) entry points that WindowServer serves. Every symbol is resolved
/// lazily and every call degrades to `nil` / `false` / no-op, so EchoTune behaves exactly
/// as it does today if Apple ever removes them.
final class SpaceInspector {

    static let shared = SpaceInspector()

    // MARK: - SkyLight description of a Space

    /// A normal, user-created Desktop Space.
    static let spaceTypeUser: Int32 = 0
    /// A Space owned by a full-screen window.
    static let spaceTypeFullScreen: Int32 = 4
    /// A tiled window arrangement (macOS 15+ window tiling) inside another Space.
    static let spaceTypeTiled: Int32 = 5

    // MARK: - SkyLight bindings

    private typealias CGSConnectionID = UInt32
    private typealias MainConnectionFn = @convention(c) () -> CGSConnectionID
    private typealias ActiveSpaceFn = @convention(c) (CGSConnectionID) -> UInt64
    private typealias SpaceTypeFn = @convention(c) (CGSConnectionID, UInt64) -> Int32
    private typealias SpacesForWindowsFn = @convention(c) (CGSConnectionID, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias ManagedDisplaySpacesFn = @convention(c) (CGSConnectionID) -> Unmanaged<CFArray>?
    private typealias MoveWindowsFn = @convention(c) (CGSConnectionID, CFArray, UInt64) -> Int32
    private typealias SetCurrentSpaceFn = @convention(c) (CGSConnectionID, CFString, UInt64) -> Int32

    /// Mask accepted by `CGSCopySpacesForWindows` for "every Space this window is in".
    private static let allSpaceMask: Int32 = 7

    private let connection: CGSConnectionID
    private let activeSpaceFunction: ActiveSpaceFn?
    private let spaceTypeFunction: SpaceTypeFn?
    private let spacesForWindowsFunction: SpacesForWindowsFn?
    private let managedDisplaySpacesFunction: ManagedDisplaySpacesFn?
    private let moveWindowsFunction: MoveWindowsFn?
    private let setCurrentSpaceFunction: SetCurrentSpaceFn?

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)

        func load<T>(_ name: String) -> T? {
            guard let handle, let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: T.self)
        }

        let mainConnection = load("CGSMainConnectionID") as MainConnectionFn?
        connection = mainConnection?() ?? 0
        activeSpaceFunction = load("CGSGetActiveSpace")
        spaceTypeFunction = load("CGSSpaceGetType")
        spacesForWindowsFunction = load("CGSCopySpacesForWindows")
        managedDisplaySpacesFunction = load("CGSCopyManagedDisplaySpaces")
        moveWindowsFunction = load("CGSMoveWindowsToManagedSpace")
        setCurrentSpaceFunction = load("CGSManagedDisplaySetCurrentSpace")

        spaceLog.debug("SpaceInspector ready: connection=\(self.connection, privacy: .public) symbols=\(self.activeSpaceFunction != nil && self.spaceTypeFunction != nil ? "ok" : "missing", privacy: .public)")
    }

    /// False when SkyLight could not be reached; detection then reports "not fullscreen"
    /// and the app falls back to its previous behaviour.
    var isAvailable: Bool {
        connection != 0 && activeSpaceFunction != nil && spaceTypeFunction != nil
    }

    // MARK: - Queries

    /// The Space the user is currently looking at.
    var activeSpaceID: UInt64? {
        guard let activeSpaceFunction, connection != 0 else { return nil }
        let identifier = activeSpaceFunction(connection)
        return identifier == 0 ? nil : identifier
    }

    /// SkyLight's type code for a Space (`spaceTypeUser`, `spaceTypeFullScreen`, …).
    func type(ofSpace identifier: UInt64) -> Int32? {
        guard let spaceTypeFunction, connection != 0 else { return nil }
        return spaceTypeFunction(connection, identifier)
    }

    /// The Spaces a window number is currently a member of.
    func spaceIDs(forWindowNumber number: Int) -> [UInt64] {
        guard let spacesForWindowsFunction, connection != 0, number > 0 else { return [] }
        let windows = [number] as CFArray
        guard let result = spacesForWindowsFunction(connection, Self.allSpaceMask, windows)?.takeRetainedValue() else { return [] }
        return (result as? [UInt64]) ?? []
    }

    /// True when the Space the user is looking at is a full-screen Space.
    ///
    /// EchoTune keeps its own windows out of full screen (`NSWindow.CollectionBehavior
    /// .fullScreenNone`), so a full-screen active Space always belongs to another app.
    var activeSpaceIsFullScreen: Bool {
        guard let active = activeSpaceID, let type = type(ofSpace: active) else { return false }
        return type == Self.spaceTypeFullScreen
    }

    /// True when the window currently lives on a full-screen Space.
    func isOnFullScreenSpace(_ window: NSWindow) -> Bool {
        spaceIDs(forWindowNumber: window.windowNumber).contains { type(ofSpace: $0) == Self.spaceTypeFullScreen }
    }

    /// The frame WindowServer actually has for the window, in Cocoa screen coordinates.
    ///
    /// `NSWindow.frame` is AppKit's *model* of the window and can drift from reality when
    /// macOS relocates a window itself (see `WindowFrameRepair`). Returns nil when the window
    /// is not registered with WindowServer — one that has never been ordered front, or has
    /// been ordered out.
    func serverFrame(forWindowNumber number: Int) -> CGRect? {
        guard number > 0 else { return nil }
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(number)) as? [[String: Any]],
              let bounds = list.first?["kCGWindowBounds"] as? [String: CGFloat],
              let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
        else { return nil }

        // WindowServer reports Quartz coordinates: origin at the top-left of the primary
        // display with y growing downwards. Convert to Cocoa (bottom-left origin, y upwards).
        let quartz = CGRect(
            x: bounds["X"] ?? 0,
            y: bounds["Y"] ?? 0,
            width: bounds["Width"] ?? 0,
            height: bounds["Height"] ?? 0
        )
        return CGRect(
            x: quartz.minX,
            y: primaryScreen.frame.height - quartz.maxY,
            width: quartz.width,
            height: quartz.height
        )
    }

    // MARK: - Escort

    /// Moves the window onto a Desktop Space and brings that Space to the front, so a
    /// window that would otherwise be stranded inside another app's full-screen Space
    /// becomes visible and interactive.
    ///
    /// - Returns: true when at least one WindowServer operation succeeded.
    @discardableResult
    func escortToDesktopSpace(_ window: NSWindow) -> Bool {
        guard let active = activeSpaceID else { return false }

        // Prefer the display the user is actually looking at (the one showing the active
        // Space); fall back to the first display that has a Desktop Space.
        let displays = managedDisplays()
        let display = displays.first { $0.spaceIDs.contains(active) }
            ?? displays.first { $0.desktopSpaceID != nil }
        guard let display, let desktop = display.desktopSpaceID else {
            spaceLog.notice("escort: no Desktop Space found")
            return false
        }

        let moved = moveWindows([window.windowNumber], toSpace: desktop)
        let switched = setCurrentSpace(desktop, onDisplay: display.uuid)
        spaceLog.notice("escort '\(window.title, privacy: .public)' win=\(window.windowNumber, privacy: .public) -> desktop space \(desktop, privacy: .public) on display \(display.uuid, privacy: .public) (moved=\(moved, privacy: .public) switched=\(switched, privacy: .public))")
        return moved || switched
    }

    // MARK: - SkyLight mutation

    @discardableResult
    private func moveWindows(_ windowNumbers: [Int], toSpace space: UInt64) -> Bool {
        guard let moveWindowsFunction, connection != 0, !windowNumbers.isEmpty else { return false }
        let result = moveWindowsFunction(
            connection,
            windowNumbers as CFArray,
            space
        )
        return result == 0
    }

    @discardableResult
    private func setCurrentSpace(_ space: UInt64, onDisplay uuid: String) -> Bool {
        guard let setCurrentSpaceFunction, connection != 0 else { return false }
        return setCurrentSpaceFunction(connection, uuid as CFString, space) == 0
    }

    // MARK: - Managed display parsing

    private struct ManagedDisplay {
        let uuid: String
        let spaceIDs: [UInt64]

        var desktopSpaceID: UInt64? {
            spaceIDs.first { SpaceInspector.shared.type(ofSpace: $0) == SpaceInspector.spaceTypeUser }
        }
    }

    private func managedDisplays() -> [ManagedDisplay] {
        guard let managedDisplaySpacesFunction, connection != 0,
              let displays = managedDisplaySpacesFunction(connection)?.takeRetainedValue() as? [[String: Any]]
        else { return [] }

        return displays.compactMap { display in
            guard let uuid = display["Display Identifier"] as? String,
                  let spaces = display["Spaces"] as? [[String: Any]]
            else { return nil }
            let identifiers = spaces.compactMap { ($0["id64"] as? NSNumber)?.uint64Value }
            return ManagedDisplay(uuid: uuid, spaceIDs: identifiers)
        }
    }
}
