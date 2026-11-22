//
//  StatusBarController.swift
//  EchoTune
//
//  Menu bar icon + CodexBar-designed popover.
//
//  WHY THERE IS A BIT OF ARDOISE HERE
//  ----------------------------------
//  On macOS 26 the window server draws third-party status items through Control
//  Center (`NSSceneStatusItem` / `NSStatusItemView`, CGWindowLayer 25) and is
//  responsible for forwarding the click back into the owning app. Measured on this
//  machine (macOS 26.6, 2026-11-22), that forward is not delivered for EchoTune:
//
//    * the item is registered and drawn (`name = EchoTuneStatusItem`, layer 25),
//    * `AXUIElementPerformAction(item, kAXPressAction)` DOES open the menu,
//    * `AXUIElementCopyElementAtPosition` at the icon's centre DOES resolve to our
//      `AXMenuBarItem`,
//    * a *real* mouse-down swept across 30 positions over the whole slot never
//      opens it, and Control Center logs no `[Forward Event]` for us at all,
//    * six other third-party items on the same Mac (Tailscale, Ollama, AlDente,
//      CopyClip, Proton VPN, SSMenuAgent) DO open from the same synthetic click,
//      and the Apple menu does too — so the click injection is not the problem.
//
//  A status item that is never told about the click cannot react to it, and
//  `statusItem.menu`, `button.action`, re-vending the item and restarting Control
//  Center were each tried and all still failed. So we do not depend on the forward:
//  the icon's own rect is watched directly, and the click is handled here.
//
//  The two paths can never double-fire: a global monitor sees events delivered to
//  *other* applications (which is what a menu bar click is), while the button action
//  fires only when the event is delivered to *us*. A cooldown guards the one case
//  where the popover's own transient dismissal and a repeat click coincide.
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

/// Pure decision logic for "was this click on our menu bar icon, and should it toggle?".
/// Extracted so the behaviour is unit-testable without a live status item.
enum StatusItemClickDecision {
    /// Click tolerance around the icon, in points (the button is ~36x24 pt).
    static let rectSlack: CGFloat = 3

    /// A repeat click within this window of the previous one is treated as the same
    /// gesture and ignored.
    static let toggleCooldown: TimeInterval = 0.25

    /// When the popover dismisses itself because the click landed outside it, that
    /// click is the user's close gesture; it must not immediately reopen the popover.
    static let closedRecentlyWindow: TimeInterval = 0.30

    static func shouldToggle(
        clickPoint: CGPoint,
        statusItemRect: CGRect,
        popoverIsShown: Bool,
        secondsSinceLastToggle: TimeInterval,
        secondsSincePopoverClosed: TimeInterval
    ) -> Bool {
        let hitRect = statusItemRect.insetBy(dx: -rectSlack, dy: -rectSlack)
        guard hitRect.contains(clickPoint) else { return false }

        if secondsSinceLastToggle < toggleCooldown { return false }
        if !popoverIsShown && secondsSincePopoverClosed < closedRecentlyWindow { return false }
        return true
    }

    /// Clicks anywhere else only matter while the popover is open (dismiss it).
    static func shouldDismiss(
        clickPoint: CGPoint,
        statusItemRect: CGRect,
        popoverIsShown: Bool
    ) -> Bool {
        guard popoverIsShown else { return false }
        return !statusItemRect.insetBy(dx: -rectSlack, dy: -rectSlack).contains(clickPoint)
    }
}

final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private let popover: NSPopover
    private let presentation = EchoMenuPresentationState()
    private var cancellables = Set<AnyCancellable>()
    private var iconAnimationTimer: Timer?
    private var animationPhase: Double = 0

    /// Watches mouse-downs that go to other applications — which is where a menu
    /// bar click goes, because Control Center owns the status item's window.
    private var globalClickMonitor: Any?
    /// Watches mouse-downs delivered to us, so a click on our own popover/Dashboard
    /// can still dismiss the popover.
    private var localClickMonitor: Any?
    /// Independent second detector. A listen-only session event tap is below the
    /// window server's menu-bar routing, so it sees the click even if the AppKit
    /// monitor does not. Both funnel through the same cooldown, so a click that is
    /// reported twice is still handled once.
    private var clickEventTap: CFMachPort?
    private var clickEventTapSource: CFRunLoopSource?
    private var popoverCloseObserver: Any?

    private var lastToggleAt: Date = .distantPast
    private var lastPopoverCloseAt: Date = .distantPast

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        super.init()

        presentation.onDismissMenu = { [weak self] in
            self?.closePopover()
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

        popoverCloseObserver = NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            self?.lastPopoverCloseAt = Date()
        }

        configureStatusItemButton()
        installClickDetection()
        setupObservations()
        updateIcon(for: AppState.shared.recordingState)
    }

    deinit {
        iconAnimationTimer?.invalidate()
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let popoverCloseObserver { NotificationCenter.default.removeObserver(popoverCloseObserver) }
        if let clickEventTapSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), clickEventTapSource, .commonModes) }
        if let clickEventTap { CGEvent.tapEnable(tap: clickEventTap, enable: false) }
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

    // MARK: - Click detection that does not rely on Control Center

    private func installClickDetection() {
        // Events delivered to another application (a menu bar click is one: Control
        // Center owns the status item's window). Mouse monitors need no extra grant.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.handleClick(at: NSEvent.mouseLocation, deliveredToUs: false)
        }

        // Events delivered to us, so clicking our own windows still dismisses.
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            // A click inside the popover is the user using the card — never a dismiss.
            if let popoverWindow = self.popover.contentViewController?.view.window,
               event.window === popoverWindow {
                return event
            }
            let inScreen = event.window.map {
                $0.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
            } ?? NSEvent.mouseLocation
            self.handleClick(at: inScreen, deliveredToUs: true)
            return event
        }

        installClickEventTap()
    }

    /// Listen-only tap on mouse-downs. `NSEvent`'s global monitor does not always see
    /// clicks handled by the window server's own menu-bar machinery, so the icon also
    /// gets a second, independent reporter. `.listenOnly` means it can never consume
    /// or alter an event.
    private func installClickEventTap() {
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<StatusBarController>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.clickEventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            // Read the cursor in Cocoa screen space so both detectors agree on coordinates.
            DispatchQueue.main.async {
                controller.handleClick(at: NSEvent.mouseLocation, deliveredToUs: false)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            os_log("⚠️ Could not install menu bar click event tap; falling back to NSEvent monitors", log: appLog, type: .error)
            return
        }
        clickEventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        clickEventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        os_log("✓ Menu bar click event tap installed", log: appLog, type: .info)
    }

    /// The status item's rect in screen coordinates (Cocoa, bottom-left origin).
    private var statusItemRectInScreen: CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func handleClick(at point: CGPoint, deliveredToUs: Bool) {
        guard let rect = statusItemRectInScreen else { return }

        if StatusItemClickDecision.shouldToggle(
            clickPoint: point,
            statusItemRect: rect,
            popoverIsShown: popover.isShown,
            secondsSinceLastToggle: Date().timeIntervalSince(lastToggleAt),
            secondsSincePopoverClosed: Date().timeIntervalSince(lastPopoverCloseAt)
        ) {
            os_log("🖱️ Menu bar icon click handled by monitor (deliveredToUs=%d)", log: appLog, type: .info, deliveredToUs ? 1 : 0)
            lastToggleAt = Date()
            togglePopover(nil)
            return
        }

        if deliveredToUs,
           StatusItemClickDecision.shouldDismiss(clickPoint: point, statusItemRect: rect, popoverIsShown: popover.isShown) {
            closePopover()
        }
    }

    /// No longer re-vends the status item: recreating it tears down Control Center's
    /// tracked scene, which is what made the icon unclickable in 7.6.3–7.6.5. The app
    /// now owns one long-lived item for its whole lifetime; this only closes the popover.
    func rebuildStatusItemAfterPolicyChange() {
        closePopover()
    }

    // MARK: - Popover Presentation

    @objc func togglePopover(_ sender: AnyObject?) {
        lastToggleAt = Date()
        os_log("🖱️ Toggling popover (shown=%d)", log: appLog, type: .info, popover.isShown ? 1 : 0)
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        presentation.refreshHardware()
        PermissionsManager.shared.checkAllPermissions()
        TranscriptionStats.shared.loadStats()
        syncPopoverSize()

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    private func syncPopoverSize() {
        guard let vc = popover.contentViewController else { return }
        vc.view.layoutSubtreeIfNeeded()
        let fitted = vc.view.fittingSize
        if fitted.width > 0 && fitted.height > 0 {
            // Leave the icon-to-popover gap out of the height so the card is not clipped.
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

    private func startIconAnimationTimerIfNeeded() {
        guard iconAnimationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
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

    func updateIcon(for state: RecordingState) {
        guard let button = statusItem.button else { return }
        button.toolTip = "EchoTune — \(state.description)"

        let modelManager = ModelManager.shared
        let needsTimer: Bool
        let image: NSImage
        var title = ""

        switch state {
        case .recording:
            needsTimer = true
            image = MenuBarIconRenderer.render(state: .recording(level: AudioManager.shared.audioLevel))
            title = " \(AudioManager.formatDuration(AudioManager.shared.recordingDuration))"
            button.imagePosition = .imageLeading

        case .processing:
            needsTimer = true
            image = MenuBarIconRenderer.render(state: .processing(phase: animationPhase))
            button.imagePosition = .imageOnly

        case .loadingModel:
            needsTimer = true
            let progress = max(WhisperEngine.shared.loadingProgress, ParakeetEngine.shared.loadingProgress, 0.15)
            image = MenuBarIconRenderer.render(state: .loading(progress: progress))
            button.imagePosition = .imageOnly

        case .error:
            needsTimer = false
            image = MenuBarIconRenderer.render(state: .error)
            button.imagePosition = .imageOnly

        case .idle:
            needsTimer = false
            if modelManager.isDownloading {
                image = MenuBarIconRenderer.render(state: .loading(progress: modelManager.downloadProgress))
            } else {
                image = MenuBarIconRenderer.render(state: .idle)
            }
            button.imagePosition = .imageOnly
        }

        // Only touch the button when something actually changed. Writing to it every
        // animation frame made Control Center re-lay-out the status item ~10x/second
        // (an NSSceneFenceAction storm in its log), which is its own source of trouble.
        if button.image !== image { button.image = image }
        if button.title != title { button.title = title }
        if button.contentTintColor != nil { button.contentTintColor = nil }

        if needsTimer {
            startIconAnimationTimerIfNeeded()
        } else {
            stopIconAnimationTimer()
        }
    }
}
