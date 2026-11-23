//
//  ClamshellStateMonitor.swift
//  EchoTune
//
//  ET-761 · detect a closed lid so the internal microphone can be avoided.
//
//  WHY THIS EXISTS
//  ---------------
//  Closed-lid (clamshell) mode with an external display is a normal way to work,
//  but the internal microphone is physically muffled by the lid. CoreAudio keeps
//  reporting "MacBook Air Microphone" as available, so the default input device
//  becomes a microphone that only records a dull nothing.
//
//  `IOPMrootDomain` publishes "AppleClamshellState" = 1 when the lid is shut.
//  We read that once per recording start — no polling, no run loop source,
//  nothing to tear down.
//

import Foundation
import IOKit

enum ClamshellStateMonitor {

    /// True when the lid is closed. Returns false on hardware without a lid
    /// (Mac mini, Studio, Mac Pro) and on any IOKit failure, so a read error can
    /// never make us reroute away from a perfectly good microphone.
    static var isLidClosed: Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }

        let key = "AppleClamshellState" as CFString
        guard let value = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool else {
            return false
        }
        return value
    }

    /// Names that identify the built-in microphone across Apple silicon and Intel
    /// Macs. Compared case-insensitively against the CoreAudio device name.
    static let internalMicNameHints = [
        "built-in",
        "internal",
        "macbook",
        "imac",
        "built in"
    ]

    /// True when `name` looks like the machine's own microphone.
    static func isInternalMicrophone(name: String) -> Bool {
        let lowercased = name.lowercased()
        return internalMicNameHints.contains { lowercased.contains($0) }
    }

    /// Picks the microphone to use, given the current lid state.
    ///
    /// - Lid open: the default input device is used, untouched.
    /// - Lid closed and the default is the internal mic: the first microphone that
    ///   is not internal is chosen (USB / AirPods / audio interface / external
    ///   display mic).
    /// - Lid closed but the default is already external, or nothing external
    ///   exists: the default is left alone.
    ///
    /// - Parameters:
    ///   - defaultDevice: the system default input, as enumerated.
    ///   - allDevices: every available input device.
    ///   - lidClosed: injectable for tests.
    /// - Returns: the device that should be used, or `nil` to keep the default.
    static func preferredInputDevice(
        defaultDevice: (id: String, name: String)?,
        allDevices: [(id: String, name: String)],
        lidClosed: Bool
    ) -> (id: String, name: String)? {
        guard lidClosed else { return nil }
        guard let current = defaultDevice else { return nil }
        guard isInternalMicrophone(name: current.name) else { return nil }

        return allDevices.first { !isInternalMicrophone(name: $0.name) && $0.id != current.id }
    }
}