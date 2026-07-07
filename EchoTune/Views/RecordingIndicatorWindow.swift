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
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        let windowWidth: CGFloat = 200
        let windowHeight: CGFloat = 40

        let xPos = screenFrame.midX - windowWidth / 2
        let yPos = screenFrame.minY + 60

        let contentRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

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
        if let screen = NSScreen.main {
            let xPos = screen.frame.midX - self.frame.width / 2
            let yPos = screen.frame.minY + 60
            setFrame(NSRect(x: xPos, y: yPos, width: self.frame.width, height: self.frame.height), display: true)
        }
        self.setIsVisible(true)
        self.orderFrontRegardless()
        self.alphaValue = 1
    }

    func hide() {
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
