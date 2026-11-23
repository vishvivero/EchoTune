//
//  SystemAudioManager.swift
//  EchoTune
//
//  Mute/unmute system output during dictation to avoid capturing app audio.
//
//  ET-759 · CoreAudio hardware mute
//  -------------------------------
//  The old implementation shelled out to `NSAppleScript` ("set volume output
//  volume 0"), which costs 50–300 ms on the main thread, pops a TCC prompt on
//  some machines, and *destroys* the user's volume level instead of muting it.
//
//  This version talks to CoreAudio directly: one synchronous property read to
//  learn whether the device is already muted, one property write to mute. Both
//  are sub-millisecond. The user's volume slider is never touched, and we only
//  unmute a device we are the ones who muted — a device the user muted manually
//  stays muted.
//

import Foundation
import AppKit
import CoreAudio

final class SystemAudioManager {
    static let shared = SystemAudioManager()

    /// Set when *we* muted the device, so restore only ever undoes our own mute.
    private var mutedDeviceIDs: Set<AudioDeviceID> = []


    private init() {}

    // MARK: - Public API

    /// Mutes every output device that was unmuted. Devices the user muted
    /// manually are recorded as "not ours" and left alone on restore.
    func muteSystemOutput() {
        for device in Self.outputDevices() {
            guard Self.hasMuteControl(device) else {
                // No hardware mute (rare, e.g. some aggregate devices) — fall back
                // to the software volume property, still without AppleScript.
                if let volume = Self.outputVolume(device) {
                    Self.setOutputVolume(device, 0)
                    debugLog("🔇 Muted \(Self.name(of: device)) via CoreAudio volume (no mute property)")
                    _ = volume
                }
                continue
            }

            if Self.isMuted(device) {
                // User muted this themselves — do not claim it, do not touch it.
                debugLog("🔇 \(Self.name(of: device)) was already muted — leaving it to the user")
                continue
            }

            if Self.setMuted(device, true) {
                mutedDeviceIDs.insert(device)
                debugLog("🔇 Muted \(Self.name(of: device)) via CoreAudio")
            }
        }
    }

    /// Unmutes only the devices `muteSystemOutput()` muted. Sub-millisecond.
    func restoreSystemOutput() {
        guard !mutedDeviceIDs.isEmpty else { return }
        for device in mutedDeviceIDs {
            if Self.setMuted(device, false) {
                debugLog("🔊 Unmuted \(Self.name(of: device)) via CoreAudio")
            }
        }
        mutedDeviceIDs.removeAll()
    }

    /// Test hook: which devices do we currently consider ours?
    var mutedDeviceIDsForTesting: Set<AudioDeviceID> { mutedDeviceIDs }

    // MARK: - CoreAudio plumbing

    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    /// All devices that can play audio out.
    static func outputDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr,
              size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &devices) == noErr else {
            return []
        }
        return devices.filter { hasOutputStreams($0) }
    }

    private static func hasOutputStreams(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    private static func hasMuteControl(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectHasProperty(device, &address)
    }

    static func isMuted(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr else {
            return false
        }
        return muted != 0
    }

    @discardableResult
    static func setMuted(_ device: AudioDeviceID, _ muted: Bool) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    /// Software output volume in 0...1, used only when a device exposes no
    /// hardware mute property.
    static func outputVolume(_ device: AudioDeviceID) -> Float32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr else {
            return nil
        }
        return volume
    }

    @discardableResult
    static func setOutputVolume(_ device: AudioDeviceID, _ volume: Float32) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    static func name(of device: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else {
            return "device \(device)"
        }
        return name as String
    }
}