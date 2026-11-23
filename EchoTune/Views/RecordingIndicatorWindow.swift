//
//  RecordingIndicatorWindow.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import AppKit

class RecordingIndicatorWindow: NSPanel {
    static let shared = RecordingIndicatorWindow()

    private init() {
        // screens can be empty (clamshell/display reconfigure) — fall back to a
        // fixed frame instead of crashing; the panel is repositioned on show.
        // ET-765 · NSScreen.main is the key-window screen, not the pointer's.
        let screen = RecorderScreenLock.shared.screenForPlacement()
        let contentRect = RecorderScreenResolver.topCenteredFrame(
            size: NSSize(width: 200, height: 40),
            screen: screen
        )

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: RecordingIndicatorContentView())
        self.contentView = hostingView
    }

    func show() {
        // ET-765 · same locked screen the recorder is using.
        let screen = RecorderScreenLock.shared.lock()
        setFrame(
            RecorderScreenResolver.topCenteredFrame(
                size: NSSize(width: self.frame.width, height: self.frame.height),
                screen: screen
            ),
            display: true
        )
        self.setIsVisible(true)
        self.orderFrontRegardless()
        self.alphaValue = 1
    }

    func hide() {
        // ET-765 · the recording is over; let the next one re-resolve the screen.
        RecorderScreenLock.shared.unlock()
        self.orderOut(nil)
    }
}

struct RecordingIndicatorContentView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.recordingState == .recording ? Color.red : Color.gray)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if appState.recordingState == .recording {
                CaptureWaveformView(barCount: 14, barWidth: 2, barSpacing: 1, maxHeight: 14)
            }

            Spacer()

            if appState.recordingState == .recording || appState.recordingState == .processing {
                Button(action: { AppCoordinator.shared.toggleDictation() }) {
                    Image(systemName: appState.recordingState == .processing ? "hourglass" : "stop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private var statusText: String {
        switch appState.recordingState {
        case .recording:
            return AudioManager.formatDuration(audioManager.recordingDuration)
        case .processing:
            return "Processing..."
        default:
            return "Ready"
        }
    }
}
