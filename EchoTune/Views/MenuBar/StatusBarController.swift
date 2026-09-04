//
//  StatusBarController.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        
        let contentView = MenuBarPopoverView()
            .environmentObject(AppState.shared)
            .environmentObject(AppSettings.shared)
            .environmentObject(AppCoordinator.shared)
        
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        super.init()
        
        if let button = statusItem.button {
            button.image = Self.logoImage()
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Observe AppState.recordingState to update icon/badge
        AppState.shared.$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateIcon(for: state)
            }
            .store(in: &cancellables)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.closePopover(event)
            }
        }
    }
    
    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    /// The menu bar keeps the same lean logo glyph at all times and only tints it to
    /// reflect state — swapping between different filled SF Symbols per state read as
    /// heavy/inconsistent, whereas a single template icon that recolors is the native,
    /// minimalistic pattern most polished menu bar apps use.
    private static func logoImage() -> NSImage? {
        guard let image = NSImage(named: "MenuBarIcon") else { return nil }
        image.isTemplate = true
        image.accessibilityDescription = "EchoTune"
        return image
    }

    func updateIcon(for state: RecordingState) {
        guard let button = statusItem.button else { return }

        button.image = Self.logoImage()
        button.toolTip = state.description

        switch state {
        case .idle:
            button.contentTintColor = nil
        case .loadingModel:
            button.contentTintColor = .systemOrange
        case .recording:
            button.contentTintColor = .systemRed
        case .processing:
            button.contentTintColor = .systemBlue
        case .error:
            button.contentTintColor = .systemOrange
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct MenuBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var history = TranscriptionHistoryManager.shared
    @State private var copyToast: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    sectionLabel("Quick Actions")
                    quickActions
                    sectionLabel("Preferences")
                    preferences
                    sectionLabel("Recent Transcriptions")
                    recentList
                }
            }

            footer
        }
        .frame(width: 300)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow).opacity(0.98))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSImage(named: "MenuBarIcon") ?? NSImage())
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.primary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("EchoTune")
                    .font(.system(size: 14, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var statusText: String {
        switch appState.recordingState {
        case .idle: return "Ready to dictate"
        case .recording: return "Recording…"
        case .processing: return "Processing…"
        case .loadingModel(let name): return "Loading \(name)…"
        case .error(let msg): return msg
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(badgeColor)
                .frame(width: 7, height: 7)
            Text(badgeLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }

    private var badgeColor: Color {
        switch appState.recordingState {
        case .recording: return .red
        case .processing: return .blue
        case .loadingModel: return .orange
        case .error: return .orange
        case .idle: return .green
        }
    }

    private var badgeLabel: String {
        switch appState.recordingState {
        case .recording: return "REC"
        case .processing: return "BUSY"
        case .loadingModel: return "LOAD"
        case .error: return "ERR"
        case .idle: return "LIVE"
        }
    }

    // MARK: - Sections

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private var quickActions: some View {
        VStack(spacing: 8) {
            // Copy Last Transcription — big, prominent
            Button(action: copyLast) {
                HStack(spacing: 9) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 12))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(copyLastTitle)
                            .font(.system(size: 12, weight: .medium))
                        if let preview = lastPreview {
                            Text(preview)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if copyToast != nil && copyToast == "last" {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.12)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(lastTranscription == nil)
            .opacity(lastTranscription == nil ? 0.45 : 1)

            HStack(spacing: 8) {
                actionButton(icon: "mic.fill", title: coordinator.appState.recordingState == .recording ? "Stop" : "Dictate") {
                    coordinator.toggleDictation()
                }
                actionButton(icon: "clock.arrow.circlepath", title: "History") {
                    (NSApp.delegate as? AppDelegate)?.showSettings()
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var preferences: some View {
        VStack(spacing: 0) {
            toggleRow(icon: "sparkles", title: "AI Enhancement", isOn: Binding(
                get: { settings.aiEnhancementEnabled },
                set: { settings.aiEnhancementEnabled = $0 }
            ))
                .padding(.bottom, 10)
            toggleRow(icon: "paperplane.fill", title: "Auto-Paste", isOn: Binding(
                get: { settings.autoSendEnabled },
                set: { settings.autoSendEnabled = $0 }
            ))
        }
        .padding(.horizontal, 16)
    }

    private var recentList: some View {
        VStack(spacing: 4) {
            if recentTranscriptions.isEmpty {
                Text("No transcriptions yet")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                ForEach(recentTranscriptions) { item in
                    RecentRow(item: item, showCheck: copyToast == item.id.uuidString) {
                        copy(item: item)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Settings…") { (NSApp.delegate as? AppDelegate)?.showSettings() }
                .buttonStyle(.link)
                .font(.system(size: 11))
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Data helpers

    private var lastTranscription: TranscriptionHistoryItem? {
        history.transcriptions.first
    }

    private var copyLastTitle: String {
        lastTranscription == nil ? "No transcriptions yet" : "Copy Last Transcription"
    }

    private var lastPreview: String? {
        guard let t = lastTranscription else { return nil }
        return t.text.isEmpty ? "Empty" : t.text
    }

    /// Last 10, newest first
    private var recentTranscriptions: [TranscriptionHistoryItem] {
        Array(history.transcriptions.prefix(10))
    }

    // MARK: - Actions

    private func copyLast() {
        guard let t = lastTranscription else { return }
        copy(item: t, toastId: "last")
    }

    private func copy(item: TranscriptionHistoryItem, toastId: String? = nil) {
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: nil)
        pb.setString(item.text, forType: .string)

        let id = toastId ?? item.id.uuidString
        withAnimation(.easeOut(duration: 0.15)) { copyToast = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copyToast == id {
                withAnimation { copyToast = nil }
            }
        }
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }
}

// MARK: - Recent history row

struct RecentRow: View {
    let item: TranscriptionHistoryItem
    let showCheck: Bool
    let onCopy: () -> Void

    private var timeText: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = item.date.isSameDay(as: Date()) ? .none : .short
        return f.string(from: item.date)
    }

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 9) {
                Text(item.text.isEmpty ? "Empty" : item.text)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if showCheck {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                } else {
                    Text(timeText)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.035)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to copy: \(item.text.prefix(80))")
    }
}

extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
