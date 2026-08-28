//
//  SystemAudioManager.swift
//  EchoTune
//
//  Mute/unmute system output during dictation to avoid capturing app audio.
//

import Foundation
import AppKit

class SystemAudioManager {
    static let shared = SystemAudioManager()

    private var previousOutputVolume: Int?

    private init() {}

    func muteSystemOutput() {
        // Save current volume
        previousOutputVolume = getSystemOutputVolume()
        // Set volume low (0)
        setSystemOutputVolume(0)
    }

    func restoreSystemOutput() {
        if let volume = previousOutputVolume {
            setSystemOutputVolume(volume)
            previousOutputVolume = nil
        }
    }

    private func getSystemOutputVolume() -> Int? {
        let script = "output volume of (get volume settings)"
        if let result = runAppleScript(script)?.stringValue, let value = Int(result) {
            return value
        }
        return nil
    }

    private func setSystemOutputVolume(_ value: Int) {
        let clamped = max(0, min(100, value))
        let script = "set volume output volume \(clamped)"
        _ = runAppleScript(script)
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        let appleScript = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)
        if let errorInfo = errorInfo {
            debugLog("⚠️ AppleScript error: \(errorInfo)")
        }
        return result
    }
}







