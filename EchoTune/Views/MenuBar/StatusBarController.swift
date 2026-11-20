//
//  StatusBarController.swift
//  EchoTune
//
//  Uses the proven NSStatusItem + button.action + NSPopover (.transient)
//  mechanism that works reliably across macOS 14–26 Control Center, paired with
//  automatic status-item re-vending after any activationPolicy transition so
//  Tahoe's NSSceneStatusItem never detaches.
//

import AppKit
import Combine
import SwiftUI
import os.log

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

final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private let popover: NSPopover
    private let presentation = EchoMenuPresentationState()
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var iconAnimationTimer: Timer?
    private var animationPhase: Double = 0

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        super.init()

        presentation.onDismissMenu = { [weak self] in
            self?.closePopover(nil)
        }
        presentation.onLayoutInvalidated = { [weak self] in
            self?.syncPopoverSize()
        }

        let rootView = EchoTuneMenuCardView(presentation: presentation)
            .environmentObject(AppState.shared)
            .environmentObject(AppSettings.shared)
            .environmentObject(AppCoordinator.shared)
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController

        configureStatusItemButton()
        setupObservations()
        updateIcon(for: AppState.shared.recordingState)
    }

    deinit {
        iconAnimationTimer?.invalidate()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func configureStatusItemButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        button.setAccessibilityTitle("EchoTune")
    }

    /// Re-vends a fresh NSStatusItem after a `.regular` → `.accessory` policy
    /// transition so macOS 26 Tahoe's Control Center scene stays clickable.
    func rebuildStatusItemAfterPolicyChange() {
        closePopover(nil)
        NSStatusBar.system.removeStatusItem(statusItem)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemButton()
        updateIcon(for: AppState.shared.recordingState)
    }

    // MARK: - Popover Presentation

    @objc func togglePopover(_ sender: AnyObject?) {
        os_log("🖱️ Status bar icon clicked (shown=%d)", log: appLog, type: .info, popover.isShown ? 1 : 0)
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        presentation.refreshHardware()
        PermissionsManager.shared.checkAllPermissions()
        TranscriptionStats.shared.loadStats()
        syncPopoverSize()

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.closePopover(event)
            }
        }
    }

    private func closePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func syncPopoverSize() {
        guard let vc = popover.contentViewController else { return }
        vc.view.layoutSubtreeIfNeeded()
        let fitted = vc.view.fittingSize
        if fitted.width > 0 && fitted.height > 0 {
            popover.contentSize = fitted
        }
    }

    // MARK: - Observations & Icon Animation

    private func setupObservations() {
        AppState.shared.$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateIcon(for: state)
            }
            .store(in: &cancellables)

        ModelManager.shared.$isDownloading
            .combineLatest(ModelManager.shared.$downloadProgress)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.updateIcon(for: AppState.shared.recordingState)
            }
            .store(in: &cancellables)
    }

    func updateIcon(for state: RecordingState) {
        guard let button = statusItem.button else { return }
        button.toolTip = "EchoTune — \(state.description)"

        let modelManager = ModelManager.shared
        let needsTimer: Bool

        switch state {
        case .recording:
            needsTimer = true
            let durationText = AudioManager.formatDuration(AudioManager.shared.recordingDuration)
            button.imagePosition = .imageLeading
            button.image = MenuBarIconRenderer.render(state: .recording(level: AudioManager.shared.audioLevel))
            button.title = " \(durationText)"
            button.contentTintColor = nil

        case .processing:
            needsTimer = true
            button.imagePosition = .imageOnly
            button.image = MenuBarIconRenderer.render(state: .processing(phase: animationPhase))
            button.title = ""
            button.contentTintColor = nil

        case .loadingModel:
            needsTimer = true
            let progress = max(WhisperEngine.shared.loadingProgress, ParakeetEngine.shared.loadingProgress, 0.15)
            button.imagePosition = .imageOnly
            button.image = MenuBarIconRenderer.render(state: .loading(progress: progress))
            button.title = ""
            button.contentTintColor = nil

        case .error:
            needsTimer = false
            button.imagePosition = .imageOnly
            button.image = MenuBarIconRenderer.render(state: .error)
            button.title = ""
            button.contentTintColor = nil

        case .idle:
            button.imagePosition = .imageOnly
            if modelManager.isDownloading {
                needsTimer = false
                button.image = MenuBarIconRenderer.render(state: .loading(progress: modelManager.downloadProgress))
            } else {
                needsTimer = false
                button.image = MenuBarIconRenderer.render(state: .idle)
            }
            button.title = ""
            button.contentTintColor = nil
        }

        if needsTimer {
            startIconAnimationTimerIfNeeded()
        } else {
            stopIconAnimationTimer()
        }
    }

    private func startIconAnimationTimerIfNeeded() {
        guard iconAnimationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animationPhase += 0.45
            self.updateIcon(for: AppState.shared.recordingState)
        }
        RunLoop.main.add(timer, forMode: .common)
        iconAnimationTimer = timer
    }

    private func stopIconAnimationTimer() {
        iconAnimationTimer?.invalidate()
        iconAnimationTimer = nil
        animationPhase = 0
    }
}
