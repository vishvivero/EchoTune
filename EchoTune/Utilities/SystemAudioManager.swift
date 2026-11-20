//
//  SystemAudioManager.swift
//  EchoTune
//
//  Fast, race-free CoreAudio output muting during dictation.
//  Uses kAudioDevicePropertyMute directly (<1 ms, preserves user's volume slider,
//  never unmutes a device the user muted manually, and tracks exact muted
//  AudioDeviceIDs across device switches). Falls back to volume=0 only on output
//  devices that lack a hardware/driver mute property.
//

import CoreAudio
import Foundation

final class SystemAudioManager {
    static let shared = SystemAudioManager()

    private var mutedDeviceIDs = Set<AudioDeviceID>()
    private var fallbackSavedVolume: Float32?
    private var fallbackDeviceID: AudioDeviceID?

    private init() {}

    func muteSystemOutput() {
        guard let deviceID = defaultOutputDeviceID() else { return }

        // If the device is already muted by the user, leave ownership with the user.
        if let alreadyMuted = deviceMuteState(deviceID: deviceID) {
            if alreadyMuted { return }
            if setDeviceMuteState(true, deviceID: deviceID) {
                mutedDeviceIDs.insert(deviceID)
                debugLog("🔇 Muted output device \(deviceID) via CoreAudio")
                return
            }
        }

        // Fallback for virtual/HDMI devices without kAudioDevicePropertyMute:
        // read & zero scalar output volume via CoreAudio (no AppleScript spawn).
        if let currentVol = deviceScalarVolume(deviceID: deviceID), currentVol > 0.001 {
            if setDeviceScalarVolume(0.0, deviceID: deviceID) {
                fallbackSavedVolume = currentVol
                fallbackDeviceID = deviceID
                debugLog("🔇 Zeroed scalar volume on output device \(deviceID)")
            }
        }
    }

    func restoreSystemOutput() {
        for deviceID in mutedDeviceIDs {
            _ = setDeviceMuteState(false, deviceID: deviceID)
        }
        mutedDeviceIDs.removeAll()

        if let savedVol = fallbackSavedVolume, let dev = fallbackDeviceID {
            _ = setDeviceScalarVolume(savedVol, deviceID: dev)
            fallbackSavedVolume = nil
            fallbackDeviceID = nil
        }
    }

    // MARK: - CoreAudio Helpers

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private func deviceMuteState(deviceID: AudioDeviceID) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
        guard status == noErr else { return nil }
        return muted != 0
    }

    private func setDeviceMuteState(_ mute: Bool, deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr, settable.boolValue else {
            return false
        }
        var value: UInt32 = mute ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value) == noErr
    }

    private func deviceScalarVolume(deviceID: AudioDeviceID) -> Float32? {
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var vol: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &vol) == noErr {
                return vol
            }
        }
        return nil
    }

    private func setDeviceScalarVolume(_ volume: Float32, deviceID: AudioDeviceID) -> Bool {
        var applied = false
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var val = max(0.0, min(1.0, volume))
            let size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &val) == noErr {
                applied = true
            }
        }
        return applied
    }
}
