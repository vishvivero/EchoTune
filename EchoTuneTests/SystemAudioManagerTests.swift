import Foundation
import Testing
import CoreAudio
@testable import EchoTune

/// ET-759 · CoreAudio hardware mute.
struct SystemAudioManagerTests {

    @Test func noAppleScriptRemainsInSystemAudioManager() throws {
        // The whole point of the ticket: the slow/brittle AppleScript path is gone.
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Utilities/SystemAudioManager.swift")

        let source = try String(contentsOf: root, encoding: .utf8)
        // Ignore comments — the header documents the old approach by name.
        let code = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("*") && !$0.hasPrefix("/*") && !$0.hasPrefix("*/") }
            .joined(separator: "\n")

        #expect(!code.contains("NSAppleScript"), "NSAppleScript must not be used at all")
        #expect(!code.contains("set volume output volume"))
    }

    /// One stateful, self-healing hardware test.
    ///
    /// The HAL reports property writes a beat late and can drop a write issued
    /// straight after another test touched the same device, so this test:
    ///   · resets every device and waits until the reset is *observed*,
    ///   · exercises mute + restore,
    ///   · always clears every mute again in a `defer`.
    ///
    /// It asserts on system state rather than on the manager's bookkeeping, so a
    /// dropped write shows up as a clear diagnostic instead of a flaky failure.
    @Test(.serialized) func muteAndRestoreRoundTrip() throws {
        let manager = SystemAudioManager.shared

        func hardwareMuteDevices() -> [AudioDeviceID] {
            SystemAudioManager.outputDevices().filter {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )
                return AudioObjectHasProperty($0, &address)
            }
        }

        func unmuteEverythingAndWait() {
            manager.restoreSystemOutput()
            for _ in 0..<10 {
                let muted = hardwareMuteDevices().filter { SystemAudioManager.isMuted($0) }
                if muted.isEmpty { return }
                for device in muted { SystemAudioManager.setMuted(device, false) }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        // Never leave the user's Mac silent, whatever happens below.
        defer { unmuteEverythingAndWait() }

        guard let device = hardwareMuteDevices().first else { return }
        unmuteEverythingAndWait()

        let startMuted = hardwareMuteDevices().filter { SystemAudioManager.isMuted($0) }
        #expect(startMuted.isEmpty, "device still muted after reset: \(startMuted)")

        manager.muteSystemOutput()

        #expect(SystemAudioManager.isMuted(device) == true,
                "device \(device) was not muted by muteSystemOutput()")

        manager.restoreSystemOutput()

        let stillMuted = hardwareMuteDevices().filter { SystemAudioManager.isMuted($0) }
        #expect(stillMuted.isEmpty, "restore left these muted: \(stillMuted)")
    }

    /// A device the user muted before EchoTune ran must stay muted afterwards.
    @Test(.serialized) func userMutedDeviceStaysMuted() throws {
        let manager = SystemAudioManager.shared

        func hardwareMuteDevices() -> [AudioDeviceID] {
            SystemAudioManager.outputDevices().filter {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )
                return AudioObjectHasProperty($0, &address)
            }
        }

        func unmuteEverything() {
            manager.restoreSystemOutput()
            for device in hardwareMuteDevices() { SystemAudioManager.setMuted(device, false) }
        }

        defer { unmuteEverything() }
        guard let device = hardwareMuteDevices().first else { return }
        unmuteEverything()
        Thread.sleep(forTimeInterval: 0.1)

        // The user mutes it themselves.
        SystemAudioManager.setMuted(device, true)
        guard SystemAudioManager.isMuted(device) else { return }

        manager.muteSystemOutput()
        let claimed = manager.mutedDeviceIDsForTesting
        let states = hardwareMuteDevices().map { (device: $0, muted: SystemAudioManager.isMuted($0)) }
        #expect(claimed.contains(device) == false,
                "a device the user muted must not be claimed by EchoTune — claimed=\(claimed) states=\(states)")

        manager.restoreSystemOutput()
        #expect(SystemAudioManager.isMuted(device) == true,
                "a device the user muted must stay muted after restore")
    }

    @Test func deviceNameIsNonEmpty() {
        guard let device = SystemAudioManager.outputDevices().first else { return }
        #expect(!SystemAudioManager.name(of: device).isEmpty)
    }
}