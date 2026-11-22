//
//  EchoTuneMenuCardView.swift
//  EchoTune
//
//  CodexBar-inspired rich menu card hosted inside NSMenu.
//  Uses AppKit `.eventTracking` first-mouse tap overlays (`MenuTrackingTapView`)
//  so every tab, button, segmented pill, and switch fires on the very first
//  click inside macOS 26's NSMenu tracking loop even while EchoTune is inactive.
//

import AppKit
import Combine
import SwiftUI

// MARK: - AppKit Event-Tracking First-Mouse Click Overlay (CodexBar pattern)

final class FirstMouseMenuTapNSView: NSView {
    var isTapEnabled: Bool = true
    var onTap: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isTapEnabled, bounds.contains(point) else { return nil }
        return self
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isTapEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isTapEnabled, let window = self.window else { return }
        var releasedInside = false

        // Track mouse release explicitly in `.eventTracking` mode because NSMenu's
        // Carbon/Cocoa tracking loop swallows standard mouseUp delivery to SwiftUI controls.
        window.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: NSEvent.foreverDuration,
            mode: .eventTracking
        ) { [weak self] tracked, stop in
            guard let self, let tracked else {
                stop.pointee = true
                return
            }
            let pt = self.convert(tracked.locationInWindow, from: nil)
            if tracked.type == .leftMouseUp {
                releasedInside = self.bounds.contains(pt)
                stop.pointee = true
            }
        }

        if releasedInside {
            onTap?()
        }
    }
}

struct MenuTrackingTapOverlay: NSViewRepresentable {
    var isEnabled: Bool = true
    let action: () -> Void

    func makeNSView(context: Context) -> FirstMouseMenuTapNSView {
        let v = FirstMouseMenuTapNSView()
        v.isTapEnabled = isEnabled
        v.onTap = action
        return v
    }

    func updateNSView(_ nsView: FirstMouseMenuTapNSView, context: Context) {
        nsView.isTapEnabled = isEnabled
        nsView.onTap = action
    }
}

extension View {
    /// Makes any SwiftUI view reliably clickable inside an open `NSMenu` on macOS 14–26.
    func menuTrackingButton(enabled: Bool = true, action: @escaping () -> Void) -> some View {
        self.overlay {
            MenuTrackingTapOverlay(isEnabled: enabled, action: action)
        }
    }
}

// MARK: - Tabs & Presentation State

enum EchoMenuCardTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case controls = "Controls"
    case recent = "Recent"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .controls: return "slider.horizontal.3"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

final class EchoMenuPresentationState: ObservableObject {
    @Published var selectedTab: EchoMenuCardTab = .overview
    @Published var copiedID: String? = nil
    @Published var hoveredDayID: String? = nil
    var onLayoutInvalidated: (() -> Void)?
    var onDismissMenu: (() -> Void)?

    func selectTab(_ tab: EchoMenuCardTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
        DispatchQueue.main.async { [weak self] in
            self?.onLayoutInvalidated?()
        }
    }

    func flashCopied(_ id: String) {
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            if self?.copiedID == id {
                self?.copiedID = nil
            }
        }
    }
}

private enum EchoMenuCardLayout {
    static let width: CGFloat = 320
    static let horizontalPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 11
    static let dailyWordTarget: Double = 1000
}

// MARK: - Single-Canvas Progress Bar

struct EchoMenuProgressBar: View {
    let percent: Double
    let tint: Color
    var markerPercents: [Double] = [50, 80]
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { context, size in
            let scale = max(displayScale, 1)
            let clamped = min(100, max(0, percent))
            let cornerRadius = size.height / 2
            let cornerSize = CGSize(width: cornerRadius, height: cornerRadius)
            let rect = CGRect(origin: .zero, size: size)

            context.clip(to: Path(rect))

            let trackPath = Path { $0.addRoundedRect(in: rect, cornerSize: cornerSize) }
            context.fill(trackPath, with: .color(Color(nsColor: .tertiaryLabelColor).opacity(0.24)))

            if clamped > 0 {
                let minVisible = min(size.width, max(size.height, size.width * clamped / 100.0))
                let fillRect = CGRect(x: 0, y: 0, width: minVisible, height: size.height)
                let fillPath = Path { $0.addRoundedRect(in: fillRect, cornerSize: cornerSize) }
                context.fill(fillPath, with: .color(tint))
            }

            let tickWidth = max(1.0 / scale, 1.0)
            for marker in markerPercents where marker > 0 && marker < 100 {
                let x = round(size.width * marker / 100.0 * scale) / scale
                let tickRect = CGRect(x: x, y: 1, width: tickWidth, height: max(1, size.height - 2))
                context.fill(Path(tickRect), with: .color(Color(nsColor: .separatorColor).opacity(0.45)))
            }
        }
        .frame(height: 7)
        .accessibilityLabel("Daily dictation progress")
    }
}

// MARK: - 7-Day Activity Sparkline Strip

struct EchoDayBucket: Identifiable, Equatable {
    let id: String
    let shortLabel: String
    let fullLabel: String
    let words: Int
    let isToday: Bool
}

struct EchoActivityBarStrip: View {
    let buckets: [EchoDayBucket]
    let tint: Color
    @Binding var hoveredID: String?

    private var maxWords: Int {
        max(buckets.map(\.words).max() ?? 0, 50)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(buckets) { bucket in
                    let fraction = Double(bucket.words) / Double(maxWords)
                    let barHeight = bucket.words == 0 ? 3.0 : max(5.0, CGFloat(fraction) * 28.0)
                    let isHovered = hoveredID == bucket.id

                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.13))
                                .frame(height: 28)

                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(barFill(for: bucket, fraction: fraction, isHovered: isHovered))
                                .frame(height: barHeight)
                                .overlay {
                                    if isHovered || bucket.isToday {
                                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                            .strokeBorder(
                                                isHovered ? Color.primary.opacity(0.55) : tint.opacity(0.55),
                                                lineWidth: 1
                                            )
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onHover { inside in
                            hoveredID = inside ? bucket.id : (hoveredID == bucket.id ? nil : hoveredID)
                        }

                        Text(bucket.shortLabel)
                            .font(.system(size: 9.5, weight: bucket.isToday ? .semibold : .regular))
                            .foregroundStyle(bucket.isToday ? Color.primary : Color(nsColor: .secondaryLabelColor))
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 43)

            Text(captionText)
                .font(.footnote)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)
        }
    }

    private func barFill(for bucket: EchoDayBucket, fraction: Double, isHovered: Bool) -> Color {
        if bucket.words == 0 {
            return Color(nsColor: .tertiaryLabelColor).opacity(0.25)
        }
        let alpha = isHovered ? 1.0 : min(1.0, 0.42 + fraction * 0.58)
        return tint.opacity(alpha)
    }

    private var captionText: String {
        if let hoveredID, let bucket = buckets.first(where: { $0.id == hoveredID }) {
            return "\(bucket.fullLabel): \(bucket.words.formatted()) words"
        }
        let weekTotal = buckets.reduce(0) { $0 + $1.words }
        if let peak = buckets.max(by: { $0.words < $1.words }), peak.words > 0 {
            return "7d: \(weekTotal.formatted()) words · Peak \(peak.fullLabel) (\(peak.words.formatted()))"
        }
        return "7d: 0 words · Hold \(ShortcutManager.shared.getCurrentShortcutString()) anywhere to start"
    }
}

// MARK: - Main Hosted Menu Card View

struct EchoTuneMenuCardView: View {
    @ObservedObject var presentation: EchoMenuPresentationState
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var history = TranscriptionHistoryManager.shared
    @ObservedObject private var stats = TranscriptionStats.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var learner = CorrectionLearner.shared
    @ObservedObject private var commitmentMemory = CommitmentMemoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switcherStrip
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: EchoMenuCardLayout.sectionSpacing) {
                headerSection

                contextualAlertsSection

                Divider()

                switch presentation.selectedTab {
                case .overview:
                    overviewContent
                case .controls:
                    controlsContent
                case .recent:
                    recentContent
                }
            }
            .padding(.horizontal, EchoMenuCardLayout.horizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .frame(width: EchoMenuCardLayout.width, alignment: .leading)
        .onChange(of: learner.suggestions.count) { _, _ in
            presentation.onLayoutInvalidated?()
        }
        .onChange(of: commitmentMemory.pendingProposals.count) { _, _ in
            presentation.onLayoutInvalidated?()
        }
        .onChange(of: history.transcriptions.count) { _, _ in
            presentation.onLayoutInvalidated?()
        }
    }

    // MARK: - Top Tab Switcher

    private var switcherStrip: some View {
        HStack(spacing: 4) {
            ForEach(EchoMenuCardTab.allCases) { tab in
                let isSelected = presentation.selectedTab == tab
                HStack(spacing: 5) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 11, weight: .semibold))
                    Text(tab.rawValue)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? Color.white : Color(nsColor: .secondaryLabelColor))
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color(nsColor: .controlAccentColor) : Color.primary.opacity(0.05))
                )
                .menuTrackingButton {
                    presentation.selectTab(tab)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 7.5, height: 7.5)
                    Text("EchoTune")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text("\(activeModelShortName) · \(shortcutDisplay)")
                    .font(.subheadline)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(liveSubtitleText)
                    .font(.footnote)
                    .foregroundStyle(liveSubtitleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 6)

                Text(planBadgeText)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(planBadgeColor)
                    .lineLimit(1)
                    .padding(.vertical, 2)
                    .menuTrackingButton {
                        presentation.onDismissMenu?()
                        DispatchQueue.main.async {
                            AppDelegate.shared?.showSettings(tab: .license)
                        }
                    }
            }
        }
    }

    // MARK: - Contextual Smart Alerts

    @ViewBuilder
    private var contextualAlertsSection: some View {
        if !permissions.hasMicrophonePermission || !permissions.hasAccessibilityPermission {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(!permissions.hasMicrophonePermission ? "Microphone permission needed" : "Accessibility needed for auto-type")
                    .font(.footnote)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("Grant")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange))
                    .menuTrackingButton {
                        presentation.onDismissMenu?()
                        DispatchQueue.main.async {
                            if !permissions.hasMicrophonePermission {
                                permissions.requestMicrophonePermission { _ in permissions.checkAllPermissions() }
                            } else {
                                permissions.requestAccessibilityPermission()
                            }
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.orange.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        if let suggestion = learner.suggestions.first {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .controlAccentColor))
                VStack(alignment: .leading, spacing: 1) {
                    Text("“\(suggestion.spoken)” → “\(suggestion.written)”")
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    Text("Corrected \(suggestion.count)× · Add to dictionary?")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
                Spacer(minLength: 4)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 15))
                    .frame(width: 22, height: 22)
                    .menuTrackingButton {
                        learner.teach(suggestion)
                    }

                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .font(.system(size: 15))
                    .frame(width: 22, height: 22)
                    .menuTrackingButton {
                        learner.dismiss(suggestion)
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        if !commitmentMemory.pendingProposals.isEmpty {
            let count = commitmentMemory.pendingProposals.count
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .controlAccentColor))
                Text("\(count) commitment\(count == 1 ? "" : "s") ready to review")
                    .font(.footnote)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("Review")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.16)))
                    .menuTrackingButton {
                        presentation.onDismissMenu?()
                        DispatchQueue.main.async {
                            AppDelegate.shared?.showCommitments()
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Tab 1: Overview

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            primaryActionStrip

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Today · \(todayWordCount.formatted()) words")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("Saved \(formattedDuration(todayTimeSaved))")
                        .font(.footnote)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .lineLimit(1)
                }

                EchoMenuProgressBar(
                    percent: min(100, Double(todayWordCount) / EchoMenuCardLayout.dailyWordTarget * 100.0),
                    tint: appState.recordingState == .recording ? .red : Color(nsColor: .controlAccentColor)
                )

                Text(todayMetaLine)
                    .font(.footnote)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }

            Divider()

            EchoActivityBarStrip(
                buckets: sevenDayBuckets,
                tint: Color(nsColor: .controlAccentColor),
                hoveredID: $presentation.hoveredDayID
            )

            VStack(alignment: .leading, spacing: 5) {
                pipelineDetailRow(
                    label: "Engine",
                    value: "\(activeModelFullName) · \(activeModelOriginLabel)"
                )
                pipelineDetailRow(
                    label: "AI Cleanup",
                    value: settings.aiEnhancementEnabled ? "Enabled · \(enhancementModeShort)" : "Off (raw transcript)"
                )
                pipelineDetailRow(
                    label: "Input Mic",
                    value: activeMicrophoneName
                )
                pipelineDetailRow(
                    label: "Lifetime",
                    value: "\(appState.totalWordsTranscribed.formatted()) words · \(formattedDuration(max(0, stats.timeSaved))) saved"
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var primaryActionStrip: some View {
        let isRecording = appState.recordingState == .recording
        let copiedLast = presentation.copiedID == "last"
        let hasHistory = !history.transcriptions.isEmpty

        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                Text(isRecording ? "Stop (\(AudioManager.formatDuration(audioManager.recordingDuration)))" : "Dictate")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(shortcutDisplay)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isRecording ? Color.red : Color(nsColor: .controlAccentColor))
            )
            .menuTrackingButton {
                // Dismiss menu first so focus returns cleanly to the user's active text field!
                presentation.onDismissMenu?()
                DispatchQueue.main.async {
                    coordinator.toggleDictation()
                }
            }

            HStack(spacing: 5) {
                Image(systemName: copiedLast ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                Text(copiedLast ? "Copied" : "Copy Last")
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(copiedLast ? Color.green : Color.primary)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
            .opacity(hasHistory ? 1.0 : 0.45)
            .menuTrackingButton(enabled: hasHistory) {
                if let latest = history.transcriptions.first {
                    copyToPasteboard(latest.text, id: "last")
                }
            }
        }
    }

    private func pipelineDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .frame(width: 68, alignment: .leading)
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Tab 2: Controls (Custom First-Mouse Pills & Switches)

    private var controlsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            pillSelectorRow(
                label: "Trigger",
                icon: "keyboard",
                options: [
                    ("Hold", RecordingMode.pushToTalk),
                    ("Toggle", RecordingMode.toggle)
                ],
                selection: $settings.recordingMode
            )

            pillSelectorRow(
                label: "Recorder UI",
                icon: "pip",
                options: [
                    ("Slim", RecorderStyle.slim),
                    ("Mini", RecorderStyle.mini),
                    ("Notch", RecorderStyle.notch)
                ],
                selection: $settings.recorderStyle
            )

            pillSelectorRow(
                label: "Live Preview",
                icon: "bolt.horizontal",
                options: [
                    ("4s", PreviewTier.classic),
                    ("2s", PreviewTier.balanced),
                    ("1s", PreviewTier.reactive)
                ],
                selection: $settings.previewTier
            )

            Divider()

            compactSwitchRow(
                icon: "sparkles",
                title: "AI Enhancement",
                subtitle: "Polish grammar & strip filler words",
                isOn: $settings.aiEnhancementEnabled
            )
            compactSwitchRow(
                icon: "paperplane.fill",
                title: "Auto-Paste into Active App",
                subtitle: "Insert immediately when dictation finishes",
                isOn: $settings.autoSendEnabled
            )
            compactSwitchRow(
                icon: "text.cursor",
                title: "Smart Punctuation",
                subtitle: "Adjust spacing & case around cursor",
                isOn: $settings.smartPunctuationEnabled
            )
            compactSwitchRow(
                icon: "globe",
                title: "Auto-Detect Language",
                subtitle: "Multilingual automatic speech detection",
                isOn: $settings.autoDetectLanguage
            )
            compactSwitchRow(
                icon: "character.book.closed.fill",
                title: "Apply Custom Vocabulary",
                subtitle: "Use your personal dictionary & phonetics",
                isOn: $settings.vocabularyBiasingEnabled
            )
            compactSwitchRow(
                icon: "speaker.slash.fill",
                title: "Mute System Audio",
                subtitle: "Silence Mac output while mic is open",
                isOn: $settings.muteBackgroundAudio
            )
            compactSwitchRow(
                icon: "speaker.wave.2.fill",
                title: "Dictation Sound Cues",
                subtitle: "Subtle start and stop audio feedback",
                isOn: $settings.playSoundOnStartStop
            )
        }
    }

    private func pillSelectorRow<T: Equatable>(
        label: String,
        icon: String,
        options: [(String, T)],
        selection: Binding<T>
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 6)
            HStack(spacing: 2) {
                ForEach(0..<options.count, id: \.self) { idx in
                    let (title, val) = options[idx]
                    let active = selection.wrappedValue == val
                    Text(title)
                        .font(.system(size: 11, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? Color.white : Color.primary)
                        .padding(.horizontal, 9)
                        .frame(height: 21)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(active ? Color(nsColor: .controlAccentColor) : Color.clear)
                        )
                        .menuTrackingButton {
                            selection.wrappedValue = val
                        }
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
        }
    }

    private func compactSwitchRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)

            // Custom tactile capsule switch driven by MenuTrackingTapOverlay
            ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                Capsule()
                    .fill(isOn.wrappedValue ? Color(nsColor: .controlAccentColor) : Color.secondary.opacity(0.28))
                    .frame(width: 30, height: 17)
                Circle()
                    .fill(Color.white)
                    .frame(width: 13, height: 13)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 0.5)
            }
            .animation(.easeInOut(duration: 0.14), value: isOn.wrappedValue)
        }
        .padding(.vertical, 1)
        .menuTrackingButton {
            isOn.wrappedValue.toggle()
        }
    }

    // MARK: - Tab 3: Recent Dictations

    private var recentContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if history.transcriptions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    Text("No dictations yet")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Hold \(shortcutDisplay) anywhere to dictate — your recent transcripts appear here for 1-click copy.")
                        .font(.footnote)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                ForEach(history.transcriptions.prefix(4)) { item in
                    recentRow(item)
                }

                HStack {
                    Text("\(history.transcriptions.count) saved locally")
                        .font(.footnote)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    Spacer()
                    Text("Open Full History →")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                        .padding(.vertical, 2)
                        .menuTrackingButton {
                            presentation.onDismissMenu?()
                            DispatchQueue.main.async {
                                AppDelegate.shared?.showDashboard(item: .history)
                            }
                        }
                }
                .padding(.top, 2)
            }
        }
    }

    private func recentRow(_ item: TranscriptionHistoryItem) -> some View {
        let itemID = item.id.uuidString
        let isCopied = presentation.copiedID == itemID
        let words = item.text.split(whereSeparator: \.isWhitespace).count

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(relativeTime(item.date)) · \(words) word\(words == 1 ? "" : "s")")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isCopied ? Color.green : Color(nsColor: .secondaryLabelColor))
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .menuTrackingButton {
                    copyToPasteboard(item.text, id: itemID)
                }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Computed Metrics & Helpers

    private var statusDotColor: Color {
        switch appState.recordingState {
        case .idle: return .green
        case .recording: return .red
        case .processing: return .blue
        case .loadingModel: return .orange
        case .error: return .orange
        }
    }

    private var liveSubtitleText: String {
        if modelManager.isDownloading {
            return "Downloading model (\(Int(modelManager.downloadProgress * 100))%)…"
        }
        switch appState.recordingState {
        case .idle:
            return settings.recordingMode == .pushToTalk
                ? "Ready · Hold \(shortcutDisplay) to dictate"
                : "Ready · Press \(shortcutDisplay) to toggle"
        case .recording:
            return "Recording \(AudioManager.formatDuration(audioManager.recordingDuration)) · Speak now"
        case .processing:
            return appState.recordingStatusDetail ?? "Transcribing audio…"
        case .loadingModel(let name):
            return "Warming up \(name)…"
        case .error(let msg):
            return msg
        }
    }

    private var liveSubtitleColor: Color {
        switch appState.recordingState {
        case .recording: return .red
        case .error: return .orange
        default: return Color(nsColor: .secondaryLabelColor)
        }
    }

    private var planBadgeText: String {
        let lm = coordinator.licenseManager
        if lm.isPro {
            return lm.licenseInfo?.tier == .pro ? "Pro · 3 Macs" : "Pro"
        }
        if lm.isTrialExpired {
            return "Unlock Pro →"
        }
        return "Trial · \(lm.trialDaysRemaining)d left"
    }

    private var planBadgeColor: Color {
        let lm = coordinator.licenseManager
        if lm.isPro { return Color(nsColor: .controlAccentColor) }
        return lm.isTrialExpired ? .orange : Color(nsColor: .secondaryLabelColor)
    }

    private var shortcutDisplay: String {
        let s = ShortcutManager.shared.getCurrentShortcutString()
        return s.isEmpty ? "⌥" : s
    }

    private var activeModelFullName: String {
        modelManager.currentModel?.name ?? "Parakeet TDT v3"
    }

    private var activeModelShortName: String {
        guard let model = modelManager.currentModel else { return "Parakeet v3" }
        if model.id.contains("parakeet-tdt-0.6b-v3") { return "Parakeet v3" }
        if model.id.contains("small") { return "Whisper Small" }
        if model.id.contains("turbo") && model.category == .local { return "Large v3 Turbo" }
        if model.id.contains("groq") { return "Groq Cloud" }
        if model.id.contains("deepgram") { return "Deepgram" }
        return model.name
    }

    private var activeModelOriginLabel: String {
        guard let model = modelManager.currentModel else { return "On-device" }
        if model.category == .cloud { return "Cloud API" }
        if model.isBuiltIn { return "macOS Built-in" }
        return "On-device"
    }

    private var enhancementModeShort: String {
        if settings.selectedEnhancementModel == AIEnhancementEngine.EnhancementModel.appleOnDevice.rawValue {
            return "Apple On-Device"
        }
        if !settings.groqAPIKey.isEmpty || !settings.geminiAPIKey.isEmpty || !settings.openaiAPIKey.isEmpty {
            return "BYO Key"
        }
        return "Zero-config Cloud"
    }

    private var activeMicrophoneName: String {
        audioManager.currentInputDevice?.name ?? "System Default Mic"
    }

    private var todayItems: [TranscriptionHistoryItem] {
        let cal = Calendar.current
        return history.transcriptions.filter { cal.isDateInToday($0.date) }
    }

    private var todayWordCount: Int {
        todayItems.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }

    private var todayTimeSaved: TimeInterval {
        let speaking = todayItems.reduce(0.0) { $0 + $1.duration }
        let typing = Double(todayWordCount) / 40.0 * 60.0
        return max(0, typing - speaking)
    }

    private var todayMetaLine: String {
        let sessions = todayItems.count
        let wpm = stats.averageWordsPerMinute > 0 ? "\(Int(stats.averageWordsPerMinute.rounded())) wpm" : "40+ wpm target"
        let streak = appState.currentStreak > 0 ? "🔥 \(appState.currentStreak)d streak" : "Start your streak"
        return "\(sessions) session\(sessions == 1 ? "" : "s") · \(wpm) · \(streak)"
    }

    private var sevenDayBuckets: [EchoDayBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "EEEEE"
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "EEE"

        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let words = history.transcriptions
                .filter { cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
            return EchoDayBucket(
                id: String(offset),
                shortLabel: offset == 0 ? "Now" : shortFormatter.string(from: day),
                fullLabel: offset == 0 ? "Today" : fullFormatter.string(from: day),
                words: words,
                isToday: offset == 0
            )
        }
    }

    private func copyToPasteboard(_ text: String, id: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        presentation.flashCopied(id)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    private func relativeTime(_ date: Date) -> String {
        let delta = Int(max(0, -date.timeIntervalSinceNow))
        if delta < 60 { return "Just now" }
        if delta < 3600 { return "\(delta / 60)m ago" }
        if delta < 86400 { return "\(delta / 3600)h ago" }
        return "\(delta / 86400)d ago"
    }
}
