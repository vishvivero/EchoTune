//
//  EchoTuneMenuCardView.swift
//  EchoTune
//
//  CodexBar-designed menu bar interface hosted inside NSPopover.
//  Because it runs inside NSPopover (NSDefaultRunLoopMode) rather than NSMenu's
//  modal Carbon tracking loop, every SwiftUI Button, Toggle, Menu picker, and
//  hover highlight works natively on the very first click.
//

import AppKit
import Combine
import SwiftUI

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
    @Published var availableMics: [AudioDevice] = []
    var onLayoutInvalidated: (() -> Void)?
    var onDismissMenu: (() -> Void)?

    func selectTab(_ tab: EchoMenuCardTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
        onLayoutInvalidated?()
    }

    func refreshHardware() {
        availableMics = AudioManager.shared.getAvailableInputDevices()
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
    static let width: CGFloat = 328
    static let horizontalPadding: CGFloat = 16
    static let dailyWordTarget: Double = 1000
}

// MARK: - Single-Canvas Progress Bar (CodexBar UsageProgressBar style)

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
    }
}

// MARK: - 7-Day Activity Sparkline Strip (CodexBar MenuUsageBarStrip style)

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
                    let barHeight = bucket.words == 0 ? 3.0 : max(5.0, CGFloat(fraction) * 26.0)
                    let isHovered = hoveredID == bucket.id

                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.13))
                                .frame(height: 26)

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
            .frame(height: 40)

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

// MARK: - Native-Feeling Menu Action Row

private struct CodexMenuActionRow: View {
    let icon: String
    let title: String
    var trailingText: String? = nil
    var tint: Color = .primary
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isHovered ? Color.white : (tint == .primary ? Color.secondary : tint))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(isHovered ? Color.white : tint)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 11))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.85) : Color.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 25)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color(nsColor: .controlAccentColor) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Complete CodexBar-Style Popover View

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
            // Top Pill Switcher (Overview / Controls / Recent)
            switcherStrip
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()

            // Card Content
            VStack(alignment: .leading, spacing: 10) {
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
            .padding(.vertical, 10)

            Divider()

            // Quick Pipeline Pickers & App Actions (CodexBar bottom menu section)
            VStack(spacing: 2) {
                pipelineMenusStrip
                    .padding(.bottom, 4)

                Divider()
                    .padding(.vertical, 3)

                CodexMenuActionRow(
                    icon: "magnifyingglass",
                    title: "Quick History Search…",
                    trailingText: "⌘⇧H"
                ) {
                    presentation.onDismissMenu?()
                    QuickHistoryPanelController.shared.toggle()
                }

                CodexMenuActionRow(
                    icon: "plus.bubble",
                    title: "Quick-Add to Dictionary…",
                    trailingText: "⌘⇧D"
                ) {
                    presentation.onDismissMenu?()
                    DictionaryQuickAddPanelController.shared.show()
                }

                CodexMenuActionRow(
                    icon: "rectangle.grid.1x2",
                    title: "Open EchoTune Dashboard"
                ) {
                    presentation.onDismissMenu?()
                    (NSApp.delegate as? AppDelegate)?.showDashboard(item: .home)
                }

                let openTasks = commitmentMemory.commitments.filter { $0.status == .open }.count
                CodexMenuActionRow(
                    icon: "checklist",
                    title: "Tasks & Commitments",
                    trailingText: openTasks > 0 ? "\(openTasks) open" : nil
                ) {
                    presentation.onDismissMenu?()
                    (NSApp.delegate as? AppDelegate)?.showCommitments()
                }

                CodexMenuActionRow(
                    icon: "brain.head.profile",
                    title: "Echo Profile"
                ) {
                    presentation.onDismissMenu?()
                    (NSApp.delegate as? AppDelegate)?.showEchoProfile()
                }

                Divider()
                    .padding(.vertical, 3)

                CodexMenuActionRow(
                    icon: "arrow.triangle.2.circlepath.circle",
                    title: "Check for Updates…"
                ) {
                    presentation.onDismissMenu?()
                    UpdateManager.shared.checkForUpdates()
                }

                CodexMenuActionRow(
                    icon: "gearshape",
                    title: "Settings…",
                    trailingText: "⌘,"
                ) {
                    presentation.onDismissMenu?()
                    (NSApp.delegate as? AppDelegate)?.showSettings(tab: .general)
                }

                CodexMenuActionRow(
                    icon: "info.circle",
                    title: "About EchoTune",
                    trailingText: "v\(Bundle.main.appVersionString)"
                ) {
                    presentation.onDismissMenu?()
                    (NSApp.delegate as? AppDelegate)?.showSettings(tab: .license)
                }

                CodexMenuActionRow(
                    icon: "xmark.rectangle",
                    title: "Quit EchoTune",
                    trailingText: "⌘Q",
                    tint: .red
                ) {
                    presentation.onDismissMenu?()
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(width: EchoMenuCardLayout.width)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Top Tab Switcher

    private var switcherStrip: some View {
        HStack(spacing: 4) {
            ForEach(EchoMenuCardTab.allCases) { tab in
                let isSelected = presentation.selectedTab == tab
                Button {
                    presentation.selectTab(tab)
                } label: {
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
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Inline Pipeline Dropdown Menus (Model, Mic, Paste, Language)

    private var pipelineMenusStrip: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Menu {
                    Section("On-Device Models") {
                        ForEach(modelManager.availableModels.filter { $0.category == .local }) { model in
                            Button {
                                selectModel(model)
                            } label: {
                                let active = modelManager.currentModel?.id == model.id
                                let tag = model.isBuiltIn ? "Built-in" : (modelManager.isInstalledAndUsable(model) ? "Ready" : "Download")
                                Text("\(active ? "✓ " : "")\(model.name) (\(tag))")
                            }
                        }
                    }
                    Section("Cloud Models") {
                        ForEach(modelManager.availableModels.filter { $0.category == .cloud }) { model in
                            Button {
                                selectModel(model)
                            } label: {
                                let active = modelManager.currentModel?.id == model.id
                                Text("\(active ? "✓ " : "")\(model.name)")
                            }
                        }
                    }
                    Divider()
                    Button("Manage AI Models & Keys…") {
                        presentation.onDismissMenu?()
                        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .aiModels)
                    }
                } label: {
                    Label(activeModelShortName, systemImage: "cpu")
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)

                Menu {
                    if presentation.availableMics.isEmpty {
                        Text("System Default Microphone")
                    } else {
                        ForEach(presentation.availableMics) { dev in
                            Button {
                                AudioManager.shared.selectAudioDevice(id: dev.id)
                                presentation.refreshHardware()
                            } label: {
                                let currentID = audioManager.currentInputDevice?.id
                                let active = (dev.id == currentID) || (currentID == nil && dev.isDefault)
                                Text("\(active ? "✓ " : "")\(dev.name)")
                            }
                        }
                    }
                } label: {
                    Label(shortMicName, systemImage: "mic")
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                Menu {
                    Button {
                        settings.autoDetectLanguage = true
                    } label: {
                        Text("\(settings.autoDetectLanguage ? "✓ " : "")Auto-Detect Multilingual")
                    }
                    Divider()
                    ForEach([
                        ("en-US", "English (US)"),
                        ("en-GB", "English (UK)"),
                        ("es-ES", "Spanish"),
                        ("fr-FR", "French"),
                        ("de-DE", "German"),
                        ("ja-JP", "Japanese"),
                        ("zh-CN", "Chinese"),
                        ("hi-IN", "Hindi")
                    ], id: \.0) { code, label in
                        Button {
                            settings.autoDetectLanguage = false
                            settings.preferredLanguage = code
                        } label: {
                            let active = !settings.autoDetectLanguage && settings.preferredLanguage == code
                            Text("\(active ? "✓ " : "")\(label)")
                        }
                    }
                } label: {
                    Label(settings.autoDetectLanguage ? "Auto Language" : settings.preferredLanguage, systemImage: "globe")
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)

                Menu {
                    ForEach(PasteMethod.allCases) { method in
                        Button {
                            settings.pasteMethod = method
                        } label: {
                            Text("\(settings.pasteMethod == method ? "✓ " : "")\(method.displayName)")
                        }
                    }
                } label: {
                    Label(settings.pasteMethod.shortName, systemImage: "keyboard.badge.ellipsis")
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    private func selectModel(_ target: AIModel) {
        if target.category == .local && !target.isBuiltIn && !modelManager.isInstalledAndUsable(target) {
            modelManager.downloadModel(target) { result in
                if case .success(let installed) = result {
                    _ = modelManager.setCurrentModel(installed)
                }
            }
        } else {
            _ = modelManager.setCurrentModel(target)
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
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(liveSubtitleText)
                    .font(.footnote)
                    .foregroundStyle(liveSubtitleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 6)

                Button {
                    presentation.onDismissMenu?()
                    (NSApp.delegate as? AppDelegate)?.showSettings(tab: .license)
                } label: {
                    Text(planBadgeText)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(planBadgeColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
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
                Button("Grant") {
                    presentation.onDismissMenu?()
                    if !permissions.hasMicrophonePermission {
                        permissions.requestMicrophonePermission { _ in permissions.checkAllPermissions() }
                    } else {
                        permissions.requestAccessibilityPermission()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.mini)
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
                Button { learner.teach(suggestion) } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                Button { learner.dismiss(suggestion) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Tab 1: Overview

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            primaryActionStrip

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Today · \(todayWordCount.formatted()) words")
                        .font(.subheadline)
                        .fontWeight(.semibold)
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

            EchoActivityBarStrip(
                buckets: sevenDayBuckets,
                tint: Color(nsColor: .controlAccentColor),
                hoveredID: $presentation.hoveredDayID
            )

            VStack(alignment: .leading, spacing: 4) {
                pipelineDetailRow(label: "Engine", value: "\(activeModelFullName) · \(activeModelOriginLabel)")
                pipelineDetailRow(label: "AI Cleanup", value: settings.aiEnhancementEnabled ? "On · \(enhancementModeShort)" : "Off")
                pipelineDetailRow(label: "Lifetime", value: "\(appState.totalWordsTranscribed.formatted()) words · \(formattedDuration(max(0, stats.timeSaved))) saved")
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private var primaryActionStrip: some View {
        let isRecording = appState.recordingState == .recording
        let copiedLast = presentation.copiedID == "last"

        return HStack(spacing: 8) {
            Button {
                presentation.onDismissMenu?()
                DispatchQueue.main.async {
                    coordinator.toggleDictation()
                }
            } label: {
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
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                if let latest = history.transcriptions.first {
                    copyToPasteboard(latest.text, id: "last")
                }
            } label: {
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
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(history.transcriptions.isEmpty)
            .opacity(history.transcriptions.isEmpty ? 0.45 : 1.0)
        }
    }

    private func pipelineDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Tab 2: Controls

    private var controlsContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Trigger", systemImage: "keyboard")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $settings.recordingMode) {
                    Text("Hold").tag(RecordingMode.pushToTalk)
                    Text("Toggle").tag(RecordingMode.toggle)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 132)
            }

            HStack {
                Label("Recorder UI", systemImage: "pip")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $settings.recorderStyle) {
                    Text("Slim").tag(RecorderStyle.slim)
                    Text("Mini").tag(RecorderStyle.mini)
                    Text("Notch").tag(RecorderStyle.notch)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 156)
            }

            HStack {
                Label("Live Preview", systemImage: "bolt.horizontal")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $settings.previewTier) {
                    Text("4s").tag(PreviewTier.classic)
                    Text("2s").tag(PreviewTier.balanced)
                    Text("1s").tag(PreviewTier.reactive)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 132)
            }

            Divider()

            compactSwitchRow(icon: "sparkles", title: "AI Enhancement", isOn: $settings.aiEnhancementEnabled)
            compactSwitchRow(icon: "paperplane.fill", title: "Auto-Paste into App", isOn: $settings.autoSendEnabled)
            compactSwitchRow(icon: "text.cursor", title: "Smart Punctuation", isOn: $settings.smartPunctuationEnabled)
            compactSwitchRow(icon: "globe", title: "Auto-Detect Language", isOn: $settings.autoDetectLanguage)
            compactSwitchRow(icon: "character.book.closed.fill", title: "Custom Vocabulary", isOn: $settings.vocabularyBiasingEnabled)
            compactSwitchRow(icon: "speaker.slash.fill", title: "Mute System Audio", isOn: $settings.muteBackgroundAudio)
        }
    }

    private func compactSwitchRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    // MARK: - Tab 3: Recent Dictations

    private var recentContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            if history.transcriptions.isEmpty {
                Text("No dictations yet — hold \(shortcutDisplay) anywhere to start.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(history.transcriptions.prefix(4)) { item in
                    recentRow(item)
                }

                HStack {
                    Text("\(history.transcriptions.count) saved")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Full History →") {
                        presentation.onDismissMenu?()
                        (NSApp.delegate as? AppDelegate)?.showDashboard(item: .history)
                    }
                    .buttonStyle(.plain)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(nsColor: .controlAccentColor))
                }
            }
        }
    }

    private func recentRow(_ item: TranscriptionHistoryItem) -> some View {
        let itemID = item.id.uuidString
        let isCopied = presentation.copiedID == itemID
        let words = item.text.split(whereSeparator: \.isWhitespace).count

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(size: 11.5))
                    .lineLimit(2)
                Text("\(relativeTime(item.date)) · \(words) words")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button {
                copyToPasteboard(item.text, id: itemID)
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCopied ? Color.green : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Helpers

    private var statusDotColor: Color {
        switch appState.recordingState {
        case .idle: return .green
        case .recording: return .red
        case .processing: return .blue
        case .loadingModel, .error: return .orange
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
        return lm.isTrialExpired ? "Unlock Pro →" : "Trial · \(lm.trialDaysRemaining)d left"
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

    private var shortMicName: String {
        let raw = audioManager.currentInputDevice?.name ?? "Default Mic"
        return raw.count > 16 ? String(raw.prefix(15)) + "…" : raw
    }

    private var activeModelOriginLabel: String {
        guard let model = modelManager.currentModel else { return "On-device" }
        if model.category == .cloud { return "Cloud API" }
        return model.isBuiltIn ? "Built-in" : "On-device"
    }

    private var enhancementModeShort: String {
        if settings.selectedEnhancementModel == AIEnhancementEngine.EnhancementModel.appleOnDevice.rawValue {
            return "Apple On-Device"
        }
        if !settings.groqAPIKey.isEmpty || !settings.geminiAPIKey.isEmpty || !settings.openaiAPIKey.isEmpty {
            return "BYO Key"
        }
        return "Hosted"
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
