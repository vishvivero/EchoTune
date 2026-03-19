//
//  AudioManager+DeviceSelection.swift
//  EchoTune
//
//  Audio device enumeration and selection via CoreAudio
//  Split from AudioManager.swift
//

import Foundation
import AVFoundation
import CoreAudio

// MARK: - Audio Device Selection

extension AudioManager {

    func getAvailableInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []

        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)

        guard status == noErr else {
            debugLog("❌ Failed to get audio devices size")
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)

        guard status == noErr else {
            debugLog("❌ Failed to get audio devices")
            return devices
        }

        // Get default input device ID
        var defaultInputDeviceID: AudioDeviceID = 0
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &dataSize, &defaultInputDeviceID)

        // Filter for input devices and get their names
        for deviceID in audioDevices {
            // Check if device has input channels
            var inputChannelsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: 0
            )

            status = AudioObjectGetPropertyDataSize(deviceID, &inputChannelsAddress, 0, nil, &dataSize)
            guard status == noErr else { continue }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }

            status = AudioObjectGetPropertyData(deviceID, &inputChannelsAddress, 0, nil, &dataSize, bufferList)
            guard status == noErr, bufferList.pointee.mNumberBuffers > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var name: CFString = "" as CFString
            dataSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &dataSize, &name)

            guard status == noErr else { continue }

            let deviceName = name as String
            let isDefault = (deviceID == defaultInputDeviceID)
            let (deviceType, deviceIcon) = self.getDeviceTypeAndIcon(for: deviceName)

            devices.append(AudioDevice(
                id: String(deviceID),
                name: deviceName,
                type: deviceType,
                icon: deviceIcon,
                isDefault: isDefault
            ))

            if isDefault {
                currentInputDevice = AudioDevice(
                    id: String(deviceID),
                    name: deviceName,
                    type: deviceType,
                    icon: deviceIcon,
                    isDefault: true
                )
            }
        }

        return devices
    }

    func getDeviceTypeAndIcon(for deviceName: String) -> (type: String, icon: String) {
        let lowercasedName = deviceName.lowercased()

        if lowercasedName.contains("built-in") || lowercasedName.contains("internal") {
            return ("Internal", "mic.fill")
        } else if lowercasedName.contains("airpods") {
            return ("Bluetooth", "airpodspro")
        } else if lowercasedName.contains("bluetooth") {
            return ("Bluetooth", "wave.3.right")
        } else if lowercasedName.contains("usb") {
            return ("USB", "mic.badge.plus")
        } else if lowercasedName.contains("external") {
            return ("External", "mic.badge.plus")
        } else if lowercasedName.contains("display") || lowercasedName.contains("hdmi") {
            return ("Display", "display")
        } else {
            return ("External", "mic")
        }
    }

    func selectAudioDevice(id: String) {
        guard let deviceID = AudioDeviceID(id) else {
            debugLog("❌ Invalid device ID")
            return
        }

        // Set as default input device
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceIDValue = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceIDValue
        )

        if status == noErr {
            debugLog("✓ Successfully set audio input device: \(id)")

            // Update current device
            let devices = getAvailableInputDevices()
            currentInputDevice = devices.first(where: { $0.id == id })

            // Restart audio engine if recording
            if isRecording {
                _ = stopRecording()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startRecording()
                }
            }
        } else {
            debugLog("❌ Failed to set audio input device: \(status)")
        }
    }
}
