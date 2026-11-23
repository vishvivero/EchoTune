//
//  ScreenSleepPreventer.swift
//  EchoTune
//
//  ET-760 · keep the display awake while a dictation is actually running.
//
//  WHY THIS EXISTS
//  ---------------
//  Holding the push-to-talk key and watching the live preview is exactly the
//  moment a display decides to sleep — you are not touching the mouse or the
//  keyboard, but you *are* dictating. If the display sleeps mid-recording the
//  preview freezes and the user thinks EchoTune has hung.
//
//  We take a single `kIOPMAssertionTypePreventUserIdleDisplaySleep` assertion
//  for the duration of the recording and release it the moment recording stops.
//  Display sleep — not system sleep — so a long recording still lets the Mac
//  idle down, and no other assertion type is touched.
//

import Foundation
import IOKit.pwr_mgt

final class ScreenSleepPreventer {
    static let shared = ScreenSleepPreventer()

    /// Name shown in `pmset -g assertions`, so the assertion is identifiable.
    static let assertionName = "EchoTune is dictating"

    private var assertionID: IOPMAssertionID = 0
    private(set) var isHolding = false

    private init() {}

    /// Takes the display-sleep assertion. Idempotent: a second call while
    /// already holding is a no-op, so a double-start cannot leak an assertion.
    @discardableResult
    func begin() -> Bool {
        guard !isHolding else { return true }

        var id: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Self.assertionName as CFString,
            &id
        )

        guard status == kIOReturnSuccess else {
            debugLog("⚠️ Could not prevent display sleep (status \(status))")
            return false
        }

        assertionID = id
        isHolding = true
        debugLog("🖥️ Display-sleep assertion held while dictating")
        return true
    }

    /// Releases the assertion. Safe to call when not holding, and safe to call
    /// from teardown paths that may run twice.
    func end() {
        guard isHolding, assertionID != 0 else {
            isHolding = false
            assertionID = 0
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isHolding = false
        debugLog("🖥️ Display-sleep assertion released")
    }

    deinit {
        if isHolding, assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }
}