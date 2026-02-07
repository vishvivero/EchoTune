//
//  MiniRecorderView.swift
//  EchoTune
//
//  Mini Recorder: A floating compact panel that can be positioned anywhere
//  Alternative to the bottom-center RecordingIndicatorWindow
//

import SwiftUI
import AppKit
import Combine

// MARK: - Mini Recorder Window

class MiniRecorderWindow: NSPanel {
    static let shared = MiniRecorderWindow()

    private init() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 72

        // Position at top-right of screen by default
        let xPos = screenFrame.maxX - windowWidth - 16
        let yPos = screenFrame.maxY - windowHeight - 16

        let contentRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true  // Allow dragging
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: MiniRecorderContentView())
        self.contentView = hostingView
    }

    func show() {
        self.setIsVisible(true)
        self.orderFrontRegardless()

        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
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

// MARK: - Mini Recorder Content View

struct MiniRecorderContentView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var powerModeManager = PowerModeManager.shared
    @State private var phase: Double = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    private let barCount = 14

    var body: some View {
        VStack(spacing: 6) {
            // Top row: mode indicator + timer + controls
            HStack(spacing: 8) {
                // Power Mode badge
                if let mode = powerModeManager.currentPowerMode {
                    HStack(spacing: 4) {
                        Text(mode.emoji)
                            .font(.system(size: 12))
                        Text(mode.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                } else {
                    Text("EchoTune")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Timer (uses centralized AudioManager duration)
                if isRecording {
                    Text(formatTime(audioManager.recordingDuration))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(audioManager.recordingDuration > AudioManager.maxRecordingDuration * 0.9 && AudioManager.maxRecordingDuration > 0 ? .orange : .red)
                }

                // Stop / Record button
                Button(action: { AppCoordinator.shared.toggleDictation() }) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                            .frame(width: 28, height: 28)

                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .tint(.white)
                        } else {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isRecording ? .red : .green)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // Waveform
            GeometryReader { geo in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(barGradient(for: i))
                            .frame(
                                width: max(2, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount)),
                                height: barHeight(for: i, in: geo.size.height)
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 24)

            // Status text
            Text(statusText)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .onReceive(Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.linear(duration: 0.06)) {
                phase = (phase + 0.3).truncatingRemainder(dividingBy: .pi * 4)
            }
        }
        .onChange(of: appState.recordingState) { _, newState in
            if newState == .recording {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    // MARK: - State

    private var isRecording: Bool { appState.recordingState == .recording }
    private var isProcessing: Bool { appState.recordingState == .processing }

    private var statusText: String {
        switch appState.recordingState {
        case .recording:
            if let mode = powerModeManager.currentPowerMode {
                return "\(mode.emoji) \(mode.name) • Recording"
            }
            return "Recording… speak now"
        case .processing:
            return "Transcribing…"
        default:
            return "Press shortcut or click mic to start"
        }
    }

    // MARK: - Timer

    private func startTimer() {
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    // MARK: - Waveform

    private func barGradient(for index: Int) -> LinearGradient {
        let colors: [Color]
        if !isRecording {
            colors = [Color.gray.opacity(0.3), Color.gray.opacity(0.15)]
        } else if audioManager.isSpeechDetected {
            colors = [Color.green.opacity(0.9), Color.green.opacity(0.5)]
        } else {
            colors = [Color.white.opacity(0.6), Color.white.opacity(0.3)]
        }
        return LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top)
    }

    private func barHeight(for index: Int, in maxHeight: CGFloat) -> CGFloat {
        guard isRecording else { return 3 }
        let level = CGFloat(max(0, min(1, (audioManager.audioLevel - 0.0005) / 0.05)))
        let wave = 0.5 + 0.5 * sin(Double(index) * 0.5 + phase)
        let dynamic = max(0.12, min(1.0, Double(level) * 0.85 + wave * 0.4))
        return max(3, CGFloat(dynamic) * maxHeight)
    }
}

#Preview {
    MiniRecorderContentView()
        .frame(width: 280, height: 72)
        .background(Color.black)
}
