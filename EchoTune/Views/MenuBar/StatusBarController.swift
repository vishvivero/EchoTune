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
            // Header
            HStack(spacing: 10) {
                appIcon
                Text("EchoTune")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                statusBadge
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // Settings
            VStack(spacing: 0) {
                modeRow
                    .padding(.bottom, 14)
                Divider().opacity(0.5)
                    .padding(.vertical, 12)
                toggleRow(icon: "sparkles", title: "AI Enhancement", isOn: Binding(
                    get: { settings.aiEnhancementEnabled },
                    set: { settings.aiEnhancementEnabled = $0 }
                ))
                    .padding(.bottom, 12)
                toggleRow(icon: "paperplane.fill", title: "Auto-Paste", isOn: Binding(
                    get: { settings.autoSendEnabled },
                    set: { settings.autoSendEnabled = $0 }
                ))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()

            // Stats
            HStack(spacing: 0) {
                stat(
                    icon: "flame.fill",
                    value: "\(appState.currentStreak)",
                    label: "Day streak",
                    tint: .orange
                )
                statDivider
                stat(
                    icon: "textformat",
                    value: appState.totalWordsTranscribed.formatted(),
                    label: "Words",
                    tint: .secondary
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            Divider()

            // Actions
            HStack(spacing: 8) {
                actionButton(icon: "mic.fill", title: appState.recordingState == .recording ? "Stop" : "Dictate") {
                    coordinator.toggleDictation()
                }
                actionButton(icon: "doc.on.doc", title: "Copy Last") {
                    copyLast()
                }
                .disabled(lastTranscription == nil)
                .opacity(lastTranscription == nil ? 0.45 : 1)
                Spacer(minLength: 4)
                Button(action: quitApp) {
                    Image(systemName: "power")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Quit EchoTune")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 280)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }

    // MARK: - Subviews

    private var appIcon: some View {
        Group {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.recordingState.color)
                .frame(width: 7, height: 7)
            Text(appState.recordingState.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
    }

    private var modeRow: some View {
        HStack {
            icon("mic.fill")
            VStack(alignment: .leading, spacing: 1) {
                Text("Recording Mode")
                    .font(.system(size: 13, weight: .medium))
                Text(settings.recordingMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { settings.recordingMode },
                set: { settings.recordingMode = $0 }
            )) {
                Text("Hold").tag(RecordingMode.pushToTalk)
                Text("Toggle").tag(RecordingMode.toggle)
            }
            .pickerStyle(.segmented)
            .frame(width: 104)
        }
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                self.icon(icon)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func stat(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statDivider: some View {
        Divider().frame(height: 30)
            .padding(.horizontal, 10)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(width: 22)
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("EchoTune") && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showWelcomeNotification()
            }
        }
    }
    
    private func showSettingsWindow() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showSettings()
        }
    }

    // MARK: - Copy Last Transcription

    private var lastTranscription: TranscriptionHistoryItem? {
        history.transcriptions.first
    }

    private func copyLast() {
        guard let t = lastTranscription else { return }
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: nil)
        pb.setString(t.text, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copyToast = "last" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copyToast == "last" { withAnimation { copyToast = nil } }
        }
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}
