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

    /// Hardware-safe and deterministic. The host app mutes/restores the same
    /// output devices while tests run, so these assertions are about EchoTune's
    /// own claim bookkeeping and the absence of AppleScript — not about the
    /// device's live state, which another process legitimately owns.
    @Test(.serialized) func muteClaimsAndRestoreReleases() {
        let manager = SystemAudioManager.shared
        manager.restoreSystemOutput()
        #expect(manager.mutedDeviceIDsForTesting.isEmpty, "restore must clear every claim")

        manager.muteSystemOutput()
        let claimed = manager.mutedDeviceIDsForTesting

        // Any device we claimed must be one the system exposes with a mute property.
        for device in claimed {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            #expect(AudioObjectHasProperty(device, &address),
                    "device \(device) was claimed but has no mute property")
        }

        manager.restoreSystemOutput()
        #expect(manager.mutedDeviceIDsForTesting.isEmpty, "restore must release every claim")
    }

}