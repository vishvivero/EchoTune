//
//  MiniRecorderView.swift
//  EchoTune
//
//  Mini Recorder: floating compact panel above the dock
//  Shows live transcription that grows upward
//

import SwiftUI
import AppKit
import Combine

// MARK: - Transparent NSHostingView (no default background)

// Concrete (non-generic) subclass on purpose: a generic NSHostingView
// subclass with recursive helpers sends the Swift optimizer's inliner into
// unbounded recursion and crashes Release builds (swift-frontend segfault
// in EarlyPerfInliner). AnyView erases the generic without changing behavior.
final class TransparentHostingView: NSHostingView<AnyView> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Kill any default background the hosting view adds
        DispatchQueue.main.async {
            self.wantsLayer = true
            self.layer?.backgroundColor = .clear
            self.removeOpaqueBackgrounds()
        }
    }

    /// Iterative subview walk clearing any opaque layer backgrounds.
    private func removeOpaqueBackgrounds() {
        var pending: [NSView] = [self]
        while let view = pending.popLast() {
            if let layer = view.layer,
               layer.backgroundColor != nil,
               layer.backgroundColor != CGColor.clear {
                layer.backgroundColor = .clear
            }
            pending.append(contentsOf: view.subviews)
        }
    }
}

// MARK: - Mini Recorder Window

class MiniRecorderWindow: NSPanel {
    static let shared = MiniRecorderWindow()

    private let panelWidth: CGFloat = 360
    private let maxHeight: CGFloat = 320
    private let dockPadding: CGFloat = 16
    /// The y-coordinate of the bottom edge of the panel (fixed anchor point)
    private var anchorY: CGFloat = 0

    private init() {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 24, width: 1920, height: 1056)

        let xPos = screenFrame.minX + (screenFrame.width - 360) / 2
        let yPos = screenFrame.minY + 16

        // Start with minimal height — content will resize it
        let contentRect = NSRect(x: xPos, y: yPos, width: 360, height: 52)

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false  // We draw our own shadow via SwiftUI
        self.isMovableByWindowBackground = true
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.anchorY = yPos

        let swiftUIView = MiniRecorderContentView(onHeightChange: { [weak self] newHeight in
            self?.resizeToFitContent(newHeight)
        })
        let hostingView = TransparentHostingView(rootView: AnyView(swiftUIView))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView
    }

    /// Resize window to exactly fit content. Bottom edge stays anchored.
    private func resizeToFitContent(_ contentHeight: CGFloat) {
        let newHeight = min(max(contentHeight, 52), maxHeight)

        // In macOS coordinates: origin.y is bottom of window.
        // To keep bottom edge fixed and grow upward: origin.y stays the same, height changes.
        // BUT — this only works if origin.y is already at our anchor point.
        var frame = self.frame
        frame.origin.y = anchorY  // Always anchor bottom edge
        frame.size.height = newHeight
        frame.size.width = panelWidth

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(frame, display: true)
        }
    }

    func show() {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 24, width: 1920, height: 1056)
        let xPos = screenFrame.minX + (screenFrame.width - panelWidth) / 2
        let yPos = screenFrame.minY + dockPadding

        anchorY = yPos
        self.setFrame(NSRect(x: xPos, y: yPos, width: panelWidth, height: 52), display: false)
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

// MARK: - Content View

struct MiniRecorderContentView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var appState = AppState.shared
    @State private var phase: Double = 0
    @State private var liveText: String = ""
    @State private var textContentHeight: CGFloat = 0

    var onHeightChange: ((CGFloat) -> Void)?
    private let barCount = 20
    /// Max height for the transcript scroll area before it locks and scrolls
    private let transcriptMaxHeight: CGFloat = 200
    /// Height of the controls bar (waveform + button row)
    private let controlsBarHeight: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            // Transcript — grows upward to a max height, then becomes scrollable
            if !liveText.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(liveText)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                            .id("transcriptBottom")
                            .background(
                                GeometryReader { textGeo in
                                    Color.clear
                                        .preference(key: TextHeightKey.self, value: textGeo.size.height)
                                }
                            )
                    }
                    .onPreferenceChange(TextHeightKey.self) { height in
                        textContentHeight = height
                        let scrollHeight = min(height, transcriptMaxHeight)
                        let totalHeight = scrollHeight + controlsBarHeight + 8 // 8 for padding + divider
                        onHeightChange?(totalHeight)
                    }
                    .onChange(of: liveText) { _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("transcriptBottom", anchor: .bottom)
                        }
                    }
                }
                .frame(height: min(textContentHeight, transcriptMaxHeight))

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
            }

            // Controls bar
            HStack(spacing: 8) {
                // Waveform bars
                HStack(alignment: .center, spacing: 1.5) {
                    ForEach(0..<barCount, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(barGradient)
                            .frame(width: 3, height: barHeight(for: i, in: 20))
                    }
                }
                .frame(height: 20)

                Spacer()

                if isRecording {
                    Text(formatTime(audioManager.recordingDuration))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Record/Stop button
                Button(action: { AppCoordinator.shared.toggleDictation() }) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                            .frame(width: 32, height: 32)
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .tint(.white)
                        } else {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isRecording ? .red : .green)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            Color(nsColor: NSColor.black.withAlphaComponent(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .onAppear {
            onHeightChange?(controlsBarHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .padding(4) // Breathing room so shadow isn't clipped by window edge
        // Notifications
        .onReceive(Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()) { _ in
            if isRecording {
                withAnimation(.linear(duration: 0.06)) {
                    phase = (phase + 0.3).truncatingRemainder(dividingBy: .pi * 4)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LiveTranscriptionUpdate"))) { n in
            if let text = n.userInfo?["text"] as? String {
                liveText = text
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TranscriptionComplete"))) { n in
            if let text = n.userInfo?["text"] as? String {
                liveText = text
            }
        }
        .onChange(of: appState.recordingState) { _, newState in
            if newState == .idle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if appState.recordingState == .idle {
                        withAnimation {
                            liveText = ""
                        }
                    }
                }
            }
        }
    }

    private var isRecording: Bool { appState.recordingState == .recording }
    private var isProcessing: Bool { appState.recordingState == .processing }

    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60, s = Int(time) % 60, t = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", m, s, t)
    }

    private var barGradient: LinearGradient {
        if !isRecording {
            return LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.15)], startPoint: .bottom, endPoint: .top)
        } else if audioManager.isSpeechDetected {
            return LinearGradient(colors: [Color.green.opacity(0.9), Color.green.opacity(0.5)], startPoint: .bottom, endPoint: .top)
        } else {
            return LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.2)], startPoint: .bottom, endPoint: .top)
        }
    }

    private func barHeight(for index: Int, in maxHeight: CGFloat) -> CGFloat {
        guard isRecording else { return 2 }
        let level = CGFloat(max(0, min(1, (audioManager.audioLevel - 0.0005) / 0.05)))
        let wave = 0.5 + 0.5 * sin(Double(index) * 0.5 + phase)
        let dynamic = max(0.1, min(1.0, Double(level) * 0.85 + wave * 0.4))
        return max(2, CGFloat(dynamic) * maxHeight)
    }
}

// MARK: - Preference Key for measuring text content height

private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
