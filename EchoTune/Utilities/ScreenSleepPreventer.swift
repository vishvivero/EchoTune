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
    /// Reference count: nested `begin()` calls are paired by `end()` calls, so
    /// the recording lifecycle and any other caller cannot steal the assertion
    /// from each other.
    private var holdCount = 0
    private let lock = NSLock()

    /// Test hook: the current reference count.
    var holdCountForTesting: Int {
        lock.lock(); defer { lock.unlock() }
        return holdCount
    }

    /// True while at least one caller is holding the assertion.
    var isHolding: Bool {
        lock.lock(); defer { lock.unlock() }
        return holdCount > 0
    }

    private init() {}

    /// Takes the display-sleep assertion. Idempotent: a second call while
    /// already holding is a no-op, so a double-start cannot leak an assertion.
    @discardableResult
    func begin() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if holdCount > 0 {
            holdCount += 1
            return true
        }

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
        holdCount = 1
        debugLog("🖥️ Display-sleep assertion held while dictating")
        return true
    }

    /// Releases the assertion. Safe to call when not holding, and safe to call
    /// from teardown paths that may run twice.
    func end() {
        lock.lock(); defer { lock.unlock() }
        guard holdCount > 0 else {
            assertionID = 0
            return
        }

        holdCount -= 1
        guard holdCount == 0 else { return }

        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        debugLog("🖥️ Display-sleep assertion released")
    }

    deinit {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }
}