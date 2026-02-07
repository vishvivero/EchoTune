//
//  NotchRecorderView.swift
//  EchoTune
//
//  Notch Recorder: A compact recording UI that hugs the MacBook notch area
//  Inspired by VoiceInk's notch-based recorder
//

import SwiftUI
import AppKit
import Combine

// MARK: - Notch Recorder Window

class NotchRecorderWindow: NSPanel {
    static let shared = NotchRecorderWindow()

    private init() {
        // Position at the top center of the screen (notch area)
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        let windowWidth: CGFloat = 220
        let windowHeight: CGFloat = 44

        // Center horizontally, top of screen (notch area sits just below menu bar)
        let xPos = screenFrame.midX - windowWidth / 2
        let yPos = screenFrame.maxY - windowHeight - 2  // 2pt below top edge, overlapping menu bar

        let contentRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver  // Above menu bar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: NotchRecorderContentView())
        self.contentView = hostingView

        // Reposition on screen changes
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.repositionAtNotch()
        }
    }

    private func repositionAtNotch() {
        guard let screen = NSScreen.main else { return }
        let xPos = screen.frame.midX - self.frame.width / 2
        let yPos = screen.frame.maxY - self.frame.height - 2
        setFrame(NSRect(x: xPos, y: yPos, width: self.frame.width, height: self.frame.height), display: true)
    }

    func show() {
        repositionAtNotch()
        self.setIsVisible(true)
        self.orderFrontRegardless()

        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
}

// MARK: - Notch Recorder Content View

struct NotchRecorderContentView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var phase: Double = 0

    private let barCount = 8

    var body: some View {
        HStack(spacing: 6) {
            // Recording dot
            Circle()
                .fill(isRecording ? Color.red : Color.gray)
                .frame(width: 8, height: 8)
                .opacity(isRecording ? (0.6 + 0.4 * sin(phase * 2)) : 0.5)

            // Waveform bars
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(waveColor)
                        .frame(width: 3, height: barHeight(for: i))
                }
            }
            .frame(height: 20)

            // Status text
            Text(statusText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: 80)

            Spacer(minLength: 4)

            // Stop button
            if isRecording || isProcessing {
                Button(action: { AppCoordinator.shared.toggleDictation() }) {
                    Image(systemName: isProcessing ? "hourglass" : "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .onReceive(Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.linear(duration: 0.06)) {
                phase = (phase + 0.3).truncatingRemainder(dividingBy: .pi * 4)
            }
        }
    }

    private var isRecording: Bool {
        appState.recordingState == .recording
    }

    private var isProcessing: Bool {
        appState.recordingState == .processing
    }

    private var statusText: String {
        switch appState.recordingState {
        case .recording:
            let timeStr = AudioManager.formatDuration(audioManager.recordingDuration)
            return "\(timeStr)"
        case .processing: return "Processing…"
        default: return "Ready"
        }
    }

    private var waveColor: Color {
        if audioManager.isSpeechDetected {
            return .green
        }
        return isRecording ? .white.opacity(0.7) : .gray.opacity(0.4)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(max(0, min(1, (audioManager.audioLevel - 0.0005) / 0.05)))
        let wave = 0.5 + 0.5 * sin(Double(index) * 0.7 + phase)
        let dynamic = isRecording ? max(0.15, min(1.0, Double(level) * 0.8 + wave * 0.5)) : 0.15
        return max(3, CGFloat(dynamic) * 20)
    }
}

#Preview {
    NotchRecorderContentView()
        .frame(width: 220, height: 44)
        .background(Color.black)
}
