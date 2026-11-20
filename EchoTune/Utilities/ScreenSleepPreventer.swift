//
//  ScreenSleepPreventer.swift
//  EchoTune
//
//  Holds a macOS IOKit display-sleep assertion while recording is active so
//  long dictations never dim or lock the screen mid-thought.
//

import Foundation
import IOKit.pwr_mgt

@MainActor
final class ScreenSleepPreventer {
    static let shared = ScreenSleepPreventer()

    private var assertionID: IOPMAssertionID = 0

    private init() {}

    func beginPreventingDisplaySleep() {
        guard assertionID == 0 else { return }

        var newID: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "EchoTune Active Voice Dictation" as CFString,
            &newID
        )

        if status == kIOReturnSuccess {
            assertionID = newID
            debugLog("🔆 Display sleep prevented during dictation")
        }
    }

    func endPreventingDisplaySleep() {
        guard assertionID != 0 else { return }
        // Clear first so a failed release never wedges future recordings.
        let releasing = assertionID
        assertionID = 0
        _ = IOPMAssertionRelease(releasing)
        debugLog("🌙 Display sleep assertion released")
    }
}
