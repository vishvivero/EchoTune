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

class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Kill any default background the hosting view adds
        DispatchQueue.main.async {
            self.wantsLayer = true
            self.layer?.backgroundColor = .clear
            // Walk subviews and remove any opaque layers
            self.removeOpaqueBackgrounds(from: self)
        }
    }

    private func removeOpaqueBackgrounds(from view: NSView) {
        if let layer = view.layer {
            if layer.backgroundColor != nil && layer.backgroundColor != CGColor.clear {
                layer.backgroundColor = .clear
            }
        }
        for subview in view.subviews {
            removeOpaqueBackgrounds(from: subview)
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
        let hostingView = TransparentHostingView(rootView: swiftUIView)
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
    @ObservedObject private var settings = AppSettings.shared
    @State private var phase: Double = 0
    @State private var liveText: String = ""
    @State private var textContentHeight: CGFloat = 0
    @State private var completedMetadata: TranscriptionProcessingMetadata?

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

                if isRecording || statusDetailText != nil || !metadataBadges.isEmpty || diagnosticsSummaryText != nil {
                    VStack(alignment: .trailing, spacing: 4) {
                        if !metadataBadges.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(metadataBadges) { badge in
                                        MiniRecorderMetadataBadge(title: badge.title, color: badge.color, icon: badge.icon)
                                    }
                                }
                            }
                            .frame(maxWidth: 190, alignment: .trailing)
                        }

                        if isRecording {
                            Text(formatTime(audioManager.recordingDuration))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        if let statusDetailText {
                            Text(statusDetailText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }

                        if settings.showTranscriptionDiagnostics, let diagnosticsSummaryText {
                            Text(diagnosticsSummaryText)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
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
            if isRecording || isProcessing {
                completedMetadata = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TranscriptionComplete"))) { n in
            if let text = n.userInfo?["text"] as? String {
                liveText = text
            }
            completedMetadata = metadata(from: n.userInfo)
        }
        .onChange(of: appState.recordingState) { _, newState in
            if newState == .idle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if appState.recordingState == .idle {
                        withAnimation {
                            liveText = ""
                            completedMetadata = nil
                        }
                    }
                }
            } else if newState == .recording || newState == .processing {
                completedMetadata = nil
            }
        }
    }

    private var isRecording: Bool { appState.recordingState == .recording }
    private var isProcessing: Bool { appState.recordingState == .processing }
    private var statusDetailText: String? {
        guard let detail = appState.recordingStatusDetail, !detail.isEmpty else { return nil }
        return detail
    }

    private var activeMetadata: TranscriptionProcessingMetadata? {
        if isRecording || isProcessing {
            let metadata = AppCoordinator.shared.currentProcessingMetadata
            let hasContent = metadata.hasEnhancement ||
                metadata.transcriptionProvider != nil ||
                metadata.transcriptionModel != nil ||
                metadata.transcriptionLatency != nil ||
                metadata.enhancementLatency != nil ||
                metadata.totalLatency != nil ||
                metadata.usedFallback
            return hasContent ? metadata : nil
        }
        return completedMetadata
    }

    private var metadataBadges: [MiniRecorderBadgeItem] {
        guard let metadata = activeMetadata else { return [] }
        var badges: [MiniRecorderBadgeItem] = []
        if let provider = metadata.transcriptionProvider {
            badges.append(MiniRecorderBadgeItem(title: provider, color: .blue, icon: "waveform.badge.mic"))
        }
        if let model = metadata.transcriptionModel {
            badges.append(MiniRecorderBadgeItem(title: model, color: .gray, icon: "cpu"))
        }
        if let enhancementProvider = metadata.enhancementProvider {
            badges.append(MiniRecorderBadgeItem(title: "Enhanced • \(enhancementProvider)", color: .purple, icon: "sparkles"))
        }
        if metadata.usedFallback {
            badges.append(MiniRecorderBadgeItem(title: "Fallback", color: .orange, icon: "arrow.uturn.backward.circle"))
        }
        return badges
    }

    private var diagnosticsSummaryText: String? {
        guard let metadata = activeMetadata else { return nil }
        var parts: [String] = []
        if let totalLatency = metadata.totalLatency, totalLatency > 0 {
            parts.append(String(format: "%.1fs total", totalLatency))
        }
        if let transcriptionLatency = metadata.transcriptionLatency, transcriptionLatency > 0 {
            parts.append(String(format: "%.1fs transcribe", transcriptionLatency))
        }
        if let enhancementLatency = metadata.enhancementLatency, enhancementLatency > 0 {
            parts.append(String(format: "%.1fs enhance", enhancementLatency))
        }
        if metadata.usedFallback {
            parts.append(metadata.fallbackReason.map { "fallback: \($0)" } ?? "fallback")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func metadata(from userInfo: [AnyHashable: Any]?) -> TranscriptionProcessingMetadata? {
        guard let userInfo else { return nil }

        var metadata = TranscriptionProcessingMetadata()

        if let provider = userInfo["transcriptionProvider"] as? String, !provider.isEmpty {
            metadata.transcriptionProvider = provider
        }
        if let model = userInfo["transcriptionModel"] as? String, !model.isEmpty {
            metadata.transcriptionModel = model
        }
        if let enhancementProvider = userInfo["enhancementProvider"] as? String, !enhancementProvider.isEmpty {
            metadata.enhancementProvider = enhancementProvider
        }
        if let enhancementModel = userInfo["enhancementModel"] as? String, !enhancementModel.isEmpty {
            metadata.enhancementModel = enhancementModel
        }
        if let transcriptionLatency = userInfo["transcriptionLatency"] as? Double, transcriptionLatency > 0 {
            metadata.transcriptionLatency = transcriptionLatency
        }
        if let enhancementLatency = userInfo["enhancementLatency"] as? Double, enhancementLatency > 0 {
            metadata.enhancementLatency = enhancementLatency
        }
        if let totalLatency = userInfo["totalLatency"] as? Double, totalLatency > 0 {
            metadata.totalLatency = totalLatency
        }
        if let usedFallback = userInfo["usedFallback"] as? Bool {
            metadata.usedFallback = usedFallback
        }
        if let fallbackReason = userInfo["fallbackReason"] as? String, !fallbackReason.isEmpty {
            metadata.fallbackReason = fallbackReason
        }

        return metadata == TranscriptionProcessingMetadata() ? nil : metadata
    }

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

private struct MiniRecorderBadgeItem: Identifiable {
    let title: String
    let color: Color
    let icon: String?

    var id: String { title + (icon ?? "") }
}

private struct MiniRecorderMetadataBadge: View {
    let title: String
    let color: Color
    let icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(color.opacity(0.95))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.18)))
    }
}

// MARK: - Preference Key for measuring text content height

private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
