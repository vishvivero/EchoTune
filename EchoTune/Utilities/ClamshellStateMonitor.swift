//
//  ClamshellStateMonitor.swift
//  EchoTune
//
//  Detects whether a MacBook lid is closed (clamshell mode) via IOKit's
//  IOPMrootDomain `AppleClamshellState`. Used to route away from a muffled/muted
//  built-in microphone when docked to an external display.
//

import Foundation
import IOKit

final class ClamshellStateMonitor {
    static let shared = ClamshellStateMonitor()

    private init() {}

    /// Queries IOKit directly for `AppleClamshellState` (fast, zero allocations).
    var isLidClosed: Bool {
        let rootDomain = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard rootDomain != 0 else { return false }
        defer { IOObjectRelease(rootDomain) }

        guard let prop = IORegistryEntryCreateCFProperty(
            rootDomain,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool else {
            return false
        }
        return prop
    }
}
