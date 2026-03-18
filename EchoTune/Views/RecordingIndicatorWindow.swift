//
//  RecordingIndicatorWindow.swift
//  EchoTune
//
//  Floating recording indicator that appears at bottom of screen
//

import SwiftUI
import Combine
import AppKit

class RecordingIndicatorWindow: NSPanel {
    static let shared = RecordingIndicatorWindow()

    private init() {
        // Always anchor on the primary (built-in) display's visible frame (never external)
        let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first ?? NSScreen.main
        let screenRect = primaryScreen?.visibleFrame ?? NSRect(x: 0, y: 24, width: 1920, height: 1056)
        // Ultra-slim dimensions
        let windowWidth: CGFloat = 160
        let windowHeight: CGFloat = 28
        let xPos = screenRect.minX + (screenRect.width - windowWidth) / 2
        // 12pt above Dock edge
        let yPos: CGFloat = screenRect.minY + 12

        let contentRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Window configuration
        // Ensure we render above the Dock overlays
        self.level = .statusBar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Set up the content view
        let hostingView = NSHostingView(rootView: RecordingIndicatorView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView

        // Reposition when screens change so we stay on the primary display
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.repositionOnPrimaryScreen()
        }
    }

    // Keep the window on the primary display and above the Dock
    fileprivate func repositionOnPrimaryScreen() {
        let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first ?? NSScreen.main
        guard let screen = primaryScreen else { return }
        let xPos = screen.visibleFrame.minX + (screen.visibleFrame.width - self.frame.width) / 2
        let yPos = screen.visibleFrame.minY + 12
        setFrame(NSRect(x: xPos, y: yPos, width: self.frame.width, height: self.frame.height), display: true)
    }

    func show() {
        // Always reposition on show to the primary display
        repositionOnPrimaryScreen()
        // Show without trying to become key (non-activating panel cannot become key)
        self.setIsVisible(true)
        self.orderFrontRegardless()

        // Animate in
        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1
        }
    }

    func hide() {
        // Animate out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
}

// MARK: - Recording Indicator View (Slim, minimal, interactive)

struct RecordingIndicatorView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var isSpeaking = false
    @State private var lastSpeechTime: Date? = nil
    @State private var phase: Double = 0

    private let barCount: Int = 10

    // VAD: Determine indicator color based on speech detection
    private var indicatorColor: Color {
        if !VADManager.shared.config.enabled {
            return Color.blue  // Blue when VAD disabled (classic mode)
        }

        let probability = audioManager.speechProbability

        if audioManager.isSpeechDetected {
            return Color.green  // Green: Speech detected
        } else if probability > 0.3 {
            return Color.yellow  // Yellow: Uncertain/borderline
        } else {
            return Color.gray  // Gray: Silence detected
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Mic pill with VAD-based color
            ZStack {
                Circle()
                    .fill(indicatorColor.opacity(0.2))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(indicatorColor.opacity(0.6), lineWidth: 1)
                    )

                Image(systemName: appState.recordingState == .processing ? "hourglass" : "mic.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
            .animation(.easeInOut(duration: 0.2), value: indicatorColor)

            // Slim interactive meter
            VStack(alignment: .leading, spacing: 2) {
                Text(displayText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)

                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(0..<barCount, id: \.self) { i in
                            Capsule()
                                .fill(LinearGradient(colors: meterColors(for: i), startPoint: .bottom, endPoint: .top))
                                .frame(width: max(1.5, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount)),
                                       height: meterHeight(for: i, in: geo.size.height))
                        }
                    }
                }
                .frame(height: 12)
            }

            // Stop button (compact)
            Button(action: { AppCoordinator.shared.stopDictation() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Stop Recording")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.9))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
        )
        .onChange(of: audioManager.audioLevel) { _, _ in updateSpeakingState() }
        .onAppear { updateSpeakingState() }
        .onReceive(Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.linear(duration: 0.06)) { phase = (phase + 0.35).truncatingRemainder(dividingBy: .pi * 2) }
        }
    }

    // Speaking detection threshold (tuned low for responsiveness)
    private var shouldPulse: Bool { isSpeaking }

    private var displayText: String {
        switch appState.recordingState {
        case .processing: return "Transcribing…"
        default:
            // Always show duration timer during recording
            let duration = audioManager.recordingDuration
            let timeStr = AudioManager.formatDuration(duration)

            if VADManager.shared.config.enabled {
                if audioManager.isSpeechDetected {
                    return "\(timeStr) • Speech"
                } else {
                    return "\(timeStr) • Listening"
                }
            } else {
                return "\(timeStr) • Listening"
            }
        }
    }

    private func meterHeight(for index: Int, in availableHeight: CGFloat) -> CGFloat {
        let level = normalizedLevel(from: audioManager.audioLevel)
        // Animated wave for interactivity + live level for responsiveness
        let wave = 0.5 + 0.5 * sin(Double(index) * 0.6 + phase)
        let dynamic = max(0.18, min(1.0, (Double(level) * 0.9 + wave * 0.6)))
        return max(3, CGFloat(dynamic) * availableHeight)
    }

    private func meterColors(for index: Int) -> [Color] {
        // VAD: Use speech detection to color the meter
        if VADManager.shared.config.enabled {
            if audioManager.isSpeechDetected {
                // Green: Speech detected
                return [Color.green.opacity(0.9), Color.green.opacity(0.55)]
            } else if audioManager.speechProbability > 0.3 {
                // Yellow: Uncertain
                return [Color.yellow.opacity(0.9), Color.yellow.opacity(0.55)]
            } else {
                // Gray: Silence
                return [Color.gray.opacity(0.7), Color.gray.opacity(0.35)]
            }
        } else {
            // Classic mode: Use audio level
            let level = normalizedLevel(from: audioManager.audioLevel)
            if level > 0.7 { return [Color.green.opacity(0.9), Color.green.opacity(0.55)] }
            if level > 0.35 { return [Color.blue.opacity(0.9), Color.blue.opacity(0.55)] }
            return [Color.white.opacity(0.8), Color.white.opacity(0.35)]
        }
    }

    // Track speaking state based on VAD or audio level
    private func updateSpeakingState() {
        // Use VAD speech detection if enabled
        if VADManager.shared.config.enabled {
            isSpeaking = audioManager.isSpeechDetected
            if isSpeaking {
                lastSpeechTime = Date()
            }
        } else {
            // Fallback to audio level-based detection
            let level = normalizedLevel(from: audioManager.audioLevel)
            let speakThreshold: CGFloat = 0.08

            if level > speakThreshold {
                isSpeaking = true
                lastSpeechTime = Date()
            } else {
                // Consider silent if no speech for 450ms
                if let t = lastSpeechTime, Date().timeIntervalSince(t) > 0.45 {
                    isSpeaking = false
                }
            }
        }
    }

    // Normalize raw RMS (very small floats) into 0...1 for UI
    private func normalizedLevel(from rms: Float) -> CGFloat {
        let minRMS: Float = 0.0005
        let maxRMS: Float = 0.05
        let clamped = max(0, min(1, (rms - minRMS) / (maxRMS - minRMS)))
        return CGFloat(clamped)
    }
}

#Preview {
    RecordingIndicatorView()
        .frame(width: 160, height: 28)
}
