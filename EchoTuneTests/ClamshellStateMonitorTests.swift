import Foundation
import Testing
@testable import EchoTune

/// ET-761 · closed-lid microphone fallback.
struct ClamshellStateMonitorTests {

    private let internalMic = (id: "90", name: "MacBook Air Microphone")
    private let usbMic = (id: "77", name: "Shure MV7 USB Microphone")
    private let airPods = (id: "66", name: "Vish's AirPods Pro")

    // MARK: Acceptance criteria

    @Test func lidOpenLeavesTheMicrophoneUntouched() {
        let chosen = ClamshellStateMonitor.preferredInputDevice(
            defaultDevice: internalMic,
            allDevices: [internalMic, usbMic],
            lidClosed: false
        )
        #expect(chosen == nil, "an open lid must never reroute the microphone")
    }

    @Test func lidClosedRoutesOffTheInternalMic() {
        let chosen = ClamshellStateMonitor.preferredInputDevice(
            defaultDevice: internalMic,
            allDevices: [internalMic, usbMic, airPods],
            lidClosed: true
        )
        #expect(chosen?.name == usbMic.name, "the first non-internal microphone should win")
    }

    @Test func lidClosedWithExternalDefaultIsLeftAlone() {
        let chosen = ClamshellStateMonitor.preferredInputDevice(
            defaultDevice: usbMic,
            allDevices: [internalMic, usbMic],
            lidClosed: true
        )
        #expect(chosen == nil, "an already-external default must not be overridden")
    }

    @Test func lidClosedWithNoExternalMicKeepsInternal() {
        let chosen = ClamshellStateMonitor.preferredInputDevice(
            defaultDevice: internalMic,
            allDevices: [internalMic],
            lidClosed: true
        )
        #expect(chosen == nil, "with nothing else available, stay on the internal mic")
    }

    @Test func noDefaultDeviceIsSafe() {
        let chosen = ClamshellStateMonitor.preferredInputDevice(
            defaultDevice: nil,
            allDevices: [usbMic],
            lidClosed: true
        )
        #expect(chosen == nil)
    }

    // MARK: Detection helpers

    @Test func recognisesInternalMicrophones() {
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "MacBook Air Microphone"))
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "MacBook Pro Microphone"))
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "Built-in Microphone"))
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "iMac Microphone"))
    }

    @Test func doesNotMistakeExternalMicrophonesForInternal() {
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "Shure MV7 USB Microphone") == false)
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "Vish's AirPods Pro") == false)
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "Scarlett 2i2 USB") == false)
        #expect(ClamshellStateMonitor.isInternalMicrophone(name: "Studio Display Microphone") == false)
    }

    @Test func lidStateIsReadableWithoutCrashing() {
        // On a laptop this reflects the physical lid; on a desktop it is false.
        // Either way the read must succeed and not trap.
        _ = ClamshellStateMonitor.isLidClosed
        #expect(true)
    }

    @Test func startRecordingAppliesTheFallbackBeforeTheEngineStarts() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Managers/AudioManager.swift")
        let source = try String(contentsOf: root, encoding: .utf8)

        let fallbackIndex = try #require(source.range(of: "applyClamshellInputFallback()")?.lowerBound)
        let engineIndex = try #require(source.range(of: "AVAudioEngine()")?.lowerBound)
        #expect(fallbackIndex < engineIndex, "the fallback must run before the engine is built")
    }
}
