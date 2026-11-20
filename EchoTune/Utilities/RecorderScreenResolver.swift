//
//  RecorderScreenResolver.swift
//  EchoTune
//
//  Resolves the NSScreen containing the mouse cursor when recording starts and
//  retains that screen until the recorder panel is dismissed (multi-monitor safe).
//

import AppKit

enum RecorderScreenResolver {
    private static var lockedScreen: NSScreen?

    static func resolveForShow() -> NSScreen? {
        if let locked = lockedScreen, NSScreen.screens.contains(locked) {
            return locked
        }
        let mouse = NSEvent.mouseLocation
        let matched = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        lockedScreen = matched
        return matched
    }

    static func releaseLock() {
        lockedScreen = nil
    }
}
