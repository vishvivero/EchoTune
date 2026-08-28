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
        popover.contentSize = NSSize(width: 280, height: 330)
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
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
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                    Text("EchoTune")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.recordingState.color)
                        .frame(width: 8, height: 8)
                    Text(appState.recordingState.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // Quick toggles / settings
            VStack(spacing: 12) {
                // Recording mode
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("Recording Mode")
                        .font(.body)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.recordingMode },
                        set: { settings.recordingMode = $0 }
                    )) {
                        Text("Hold").tag(RecordingMode.pushToTalk)
                        Text("Toggle").tag(RecordingMode.toggle)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                // AI Enhancement Toggle
                Toggle(isOn: Binding(
                    get: { settings.aiEnhancementEnabled },
                    set: { settings.aiEnhancementEnabled = $0 }
                )) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("AI Enhancement")
                    }
                }
                .toggleStyle(.switch)
                
                // Auto-Send Toggle
                Toggle(isOn: Binding(
                    get: { settings.autoSendEnabled },
                    set: { settings.autoSendEnabled = $0 }
                )) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Auto-Send After Paste")
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(16)
            
            Divider()
            
            // Stats / Info
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STREAK")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("🔥")
                        Text("\(appState.currentStreak) days")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL WORDS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(appState.totalWordsTranscribed)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
            .padding(16)
            
            Divider()
            
            // Actions
            HStack {
                Button(action: showMainWindow) {
                    Label("Dashboard", systemImage: "macwindow")
                }
                .buttonStyle(.bordered)
                
                Button(action: showSettingsWindow) {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: quitApp) {
                    Image(systemName: "power")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .help("Quit EchoTune")
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).ignoresSafeArea())
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
    
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
