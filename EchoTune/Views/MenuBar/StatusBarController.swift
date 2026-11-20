//
//  StatusBarController.swift
//  EchoTune
//
//  CodexBar-style native NSMenu status bar controller.
//  Combines a rich hosted SwiftUI dashboard card (Overview / Controls / Recent)
//  at the top of a native NSMenu with crisp AppKit submenus and action rows
//  (Model switcher, Microphone picker, Language picker, Recent dictations,
//  Dashboard/Profile/Tasks/Notes/Dictionary launchers, Sparkle updater,
//  Settings ⌘, and Quit ⌘Q), plus a 1:1 Retina animated status-bar glyph.
//

import AppKit
import Combine
import SwiftUI

/// Custom NSMenuItem that suppresses AppKit's full-row selection fill behind
/// our hosted SwiftUI card (matching CodexBar's `MenuCardMenuItem`).
final class EchoMenuCardItem: NSMenuItem {
    override var isHighlighted: Bool { false }
}

final class FirstMouseMenuHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
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

final class StatusBarController: NSObject, NSMenuDelegate {
    static let menuWidth: CGFloat = 320

    private let statusItem: NSStatusItem
    private let rootMenu: NSMenu
    private let presentation = EchoMenuPresentationState()
    private var cardHostingView: FirstMouseMenuHostingView?
    private var cardMenuItem: EchoMenuCardItem?
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObservation: NSKeyValueObservation?
    private var iconAnimationTimer: Timer?
    private var animationPhase: Double = 0

    override init() {
        // Repair any corrupt/offscreen saved preferred position before registering
        let posKey = "NSStatusItem Preferred Position EchoTuneStatusItem"
        if let savedPos = UserDefaults.standard.object(forKey: posKey) as? NSNumber {
            let maxWidth = NSScreen.screens.map { Double($0.frame.width) }.max() ?? 2560
            if !savedPos.doubleValue.isFinite || savedPos.doubleValue < 0 || savedPos.doubleValue > maxWidth + 512 {
                UserDefaults.standard.removeObject(forKey: posKey)
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rootMenu = NSMenu(title: "EchoTune")
        rootMenu.autoenablesItems = false
        rootMenu.minimumWidth = Self.menuWidth

        super.init()

        statusItem.autosaveName = "EchoTuneStatusItem"
        rootMenu.delegate = self
        statusItem.menu = rootMenu

        if let button = statusItem.button {
            button.imageScaling = .scaleNone
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
            button.setAccessibilityTitle("EchoTune")
        }

        presentation.onLayoutInvalidated = { [weak self] in
            self?.syncCardHeight()
        }
        presentation.onDismissMenu = { [weak self] in
            self?.rootMenu.cancelTracking()
        }

        buildMenuSkeleton()
        setupObservations()
        updateIcon(for: AppState.shared.recordingState)
    }

    deinit {
        iconAnimationTimer?.invalidate()
        appearanceObservation?.invalidate()
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

        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pinMenuAppearance(self.rootMenu)
                self.updateIcon(for: AppState.shared.recordingState)
            }
        }
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
            button.image = MenuBarIconRenderer.render(state: .recording(level: AudioManager.shared.audioLevel))
            button.title = " \(durationText)"
            button.contentTintColor = nil

        case .processing:
            needsTimer = true
            button.image = MenuBarIconRenderer.render(state: .processing(phase: animationPhase))
            button.title = ""
            button.contentTintColor = nil

        case .loadingModel:
            needsTimer = true
            let progress = max(WhisperEngine.shared.loadingProgress, ParakeetEngine.shared.loadingProgress, 0.15)
            button.image = MenuBarIconRenderer.render(state: .loading(progress: progress))
            button.title = ""
            button.contentTintColor = nil

        case .error:
            needsTimer = false
            button.image = MenuBarIconRenderer.render(state: .error)
            button.title = ""
            button.contentTintColor = nil

        case .idle:
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

    // MARK: - NSMenuDelegate & Appearance Pinning (CodexBar pattern)

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === rootMenu else { return }
        pinMenuAppearance(rootMenu)
        _ = AudioManager.shared.getAvailableInputDevices()
        PermissionsManager.shared.checkAllPermissions()
        TranscriptionStats.shared.loadStats()
        rebuildDynamicMenuItems()
        syncCardHeight()
    }

    private func pinMenuAppearance(_ menu: NSMenu) {
        menu.appearance = NSApp.effectiveAppearance
        for item in menu.items {
            item.submenu?.appearance = nil
        }
    }

    // MARK: - Menu Construction

    private func buildMenuSkeleton() {
        let rootCard = AnyView(
            EchoTuneMenuCardView(presentation: presentation)
                .environmentObject(AppState.shared)
                .environmentObject(AppSettings.shared)
                .environmentObject(AppCoordinator.shared)
        )
        let hosting = FirstMouseMenuHostingView(rootView: rootCard)
        hosting.translatesAutoresizingMaskIntoConstraints = true

        let item = EchoMenuCardItem()
        item.title = ""
        item.view = hosting
        item.isEnabled = true

        self.cardHostingView = hosting
        self.cardMenuItem = item

        rootMenu.addItem(item)
        rootMenu.addItem(.separator())

        rebuildDynamicMenuItems()
        syncCardHeight()
    }

    private func syncCardHeight() {
        guard let hosting = cardHostingView else { return }
        hosting.frame.size.width = Self.menuWidth
        hosting.layoutSubtreeIfNeeded()
        let fitted = hosting.fittingSize
        let measuredHeight = max(220, ceil(fitted.height + 2))
        if abs(hosting.frame.height - measuredHeight) > 0.5 || abs(hosting.frame.width - Self.menuWidth) > 0.5 {
            hosting.frame = NSRect(x: 0, y: 0, width: Self.menuWidth, height: measuredHeight)
        }
    }

    private func rebuildDynamicMenuItems() {
        // Keep cardMenuItem (index 0) and its separator (index 1) permanently
        // attached so NSHostingView never detaches during menuWillOpen on macOS 26.
        while rootMenu.numberOfItems > 2 {
            rootMenu.removeItem(at: 2)
        }

        // Section 0: Native 1-Click Dictate & Copy Last Actions
        let isRecording = AppState.shared.recordingState == .recording
        let shortcutLabel = ShortcutManager.shared.getCurrentShortcutString()
        let dictateItem = makeActionItem(
            title: isRecording ? "Stop Dictation" : "Start Dictation (\(shortcutLabel))",
            symbol: isRecording ? "stop.circle.fill" : "mic.fill",
            action: #selector(toggleDictationFromMenu)
        )
        rootMenu.addItem(dictateItem)

        let copyItem = makeActionItem(
            title: "Copy Last Dictation",
            symbol: "doc.on.doc",
            action: #selector(copyLatestFromMenu)
        )
        copyItem.isEnabled = !TranscriptionHistoryManager.shared.transcriptions.isEmpty
        rootMenu.addItem(copyItem)

        rootMenu.addItem(.separator())

        // Section 1: Live Pipeline Pickers (Submenus)
        rootMenu.addItem(makeModelSubmenuItem())
        rootMenu.addItem(makeMicrophoneSubmenuItem())
        rootMenu.addItem(makeLanguageSubmenuItem())
        rootMenu.addItem(makePasteMethodSubmenuItem())
        rootMenu.addItem(makeEnhancementSubmenuItem())
        rootMenu.addItem(makeRecentDictationsSubmenuItem())

        rootMenu.addItem(.separator())

        // Section 1b: Instant Floating HUDs (#12)
        rootMenu.addItem(makeActionItem(
            title: "Quick History Search…",
            symbol: "magnifyingglass",
            keyEquivalent: "H",
            modifiers: [.command, .shift],
            action: #selector(openQuickHistoryHUD)
        ))
        rootMenu.addItem(makeActionItem(
            title: "Quick-Add to Dictionary…",
            symbol: "plus.bubble",
            keyEquivalent: "D",
            modifiers: [.command, .shift],
            action: #selector(openQuickAddDictionaryHUD)
        ))

        rootMenu.addItem(.separator())

        // Section 2: Workspace & Memory Windows
        rootMenu.addItem(makeActionItem(
            title: "Open EchoTune Dashboard",
            symbol: "rectangle.grid.1x2",
            action: #selector(openDashboardHome)
        ))
        rootMenu.addItem(makeActionItem(
            title: "Echo Profile",
            symbol: "brain.head.profile",
            action: #selector(openEchoProfile)
        ))

        let openTaskCount = CommitmentMemoryManager.shared.commitments.filter { $0.status == .open }.count
        let tasksTitle = openTaskCount > 0 ? "Tasks & Commitments (\(openTaskCount))" : "Tasks & Commitments"
        rootMenu.addItem(makeActionItem(
            title: tasksTitle,
            symbol: "checklist",
            action: #selector(openTasks)
        ))

        rootMenu.addItem(makeActionItem(
            title: "Voice Notes",
            symbol: "note.text",
            action: #selector(openNotes)
        ))
        rootMenu.addItem(makeActionItem(
            title: "Custom Dictionary",
            symbol: "character.book.closed",
            action: #selector(openDictionary)
        ))
        rootMenu.addItem(makeActionItem(
            title: "Share Progress Card…",
            symbol: "square.and.arrow.up",
            action: #selector(openShareCard)
        ))

        rootMenu.addItem(.separator())

        // Section 3: Meta / App Lifecycle (CodexBar metaSection)
        rootMenu.addItem(makeActionItem(
            title: "Check for Updates…",
            symbol: "arrow.triangle.2.circlepath.circle",
            action: #selector(checkForUpdates)
        ))
        rootMenu.addItem(makeActionItem(
            title: "Settings…",
            symbol: "gearshape",
            keyEquivalent: ",",
            action: #selector(openSettingsGeneral)
        ))
        rootMenu.addItem(makeActionItem(
            title: "About EchoTune (v\(Bundle.main.appVersionString))",
            symbol: "info.circle",
            action: #selector(openAboutLicense)
        ))
        rootMenu.addItem(makeActionItem(
            title: "Quit EchoTune",
            symbol: "xmark.rectangle",
            keyEquivalent: "q",
            action: #selector(quitApp)
        ))
    }

    // MARK: - Submenu Builders

    private func makeModelSubmenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Transcription Model")
        submenu.autoenablesItems = false

        let modelManager = ModelManager.shared
        let activeID = modelManager.currentModel?.id ?? AppSettings.shared.defaultTranscriptionModel

        let locals = modelManager.availableModels.filter { $0.category == .local }
        let clouds = modelManager.availableModels.filter { $0.category == .cloud }

        let localHeader = NSMenuItem(title: "On-Device Models", action: nil, keyEquivalent: "")
        localHeader.isEnabled = false
        submenu.addItem(localHeader)

        for model in locals {
            let isSelected = model.id == activeID
            let statusTag: String
            if model.isBuiltIn {
                statusTag = "Built-in"
            } else if modelManager.isInstalledAndUsable(model) {
                statusTag = "Ready"
            } else {
                statusTag = "Download"
            }

            let item = NSMenuItem(
                title: "\(model.name) — \(statusTag)",
                action: #selector(selectModelFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = model.id
            item.state = isSelected ? .on : .off
            item.image = symbolImage(model.isBuiltIn ? "apple.logo" : "cpu")
            submenu.addItem(item)
        }

        if !clouds.isEmpty {
            submenu.addItem(.separator())
            let cloudHeader = NSMenuItem(title: "Cloud Models (BYO API Key)", action: nil, keyEquivalent: "")
            cloudHeader.isEnabled = false
            submenu.addItem(cloudHeader)

            for model in clouds {
                let isSelected = model.id == activeID
                let item = NSMenuItem(
                    title: model.name,
                    action: #selector(selectModelFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = model.id
                item.state = isSelected ? .on : .off
                item.image = symbolImage("cloud")
                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())
        submenu.addItem(makeActionItem(
            title: "Manage AI Models & Keys…",
            symbol: "slider.horizontal.below.rectangle",
            action: #selector(openSettingsModels)
        ))

        let parent = NSMenuItem(title: "Transcription Model", action: nil, keyEquivalent: "")
        parent.image = symbolImage("cpu")
        parent.submenu = submenu
        return parent
    }

    private func makeMicrophoneSubmenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Microphone Input")
        submenu.autoenablesItems = false

        let devices = AudioManager.shared.getAvailableInputDevices()
        let currentID = AudioManager.shared.currentInputDevice?.id

        if devices.isEmpty {
            let empty = NSMenuItem(title: "System Default Microphone", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for device in devices {
                let title = device.isDefault ? "\(device.name) (System Default)" : device.name
                let item = NSMenuItem(
                    title: title,
                    action: #selector(selectMicrophoneFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = device.id
                item.state = (device.id == currentID || (currentID == nil && device.isDefault)) ? .on : .off
                item.image = symbolImage(device.icon)
                submenu.addItem(item)
            }
        }

        let parent = NSMenuItem(title: "Microphone Input", action: nil, keyEquivalent: "")
        parent.image = symbolImage("mic")
        parent.submenu = submenu
        return parent
    }

    private func makeLanguageSubmenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Dictation Language")
        submenu.autoenablesItems = false
        let settings = AppSettings.shared

        let autoItem = NSMenuItem(
            title: "Auto-Detect Language (Multilingual)",
            action: #selector(toggleAutoDetectLanguage),
            keyEquivalent: ""
        )
        autoItem.target = self
        autoItem.state = settings.autoDetectLanguage ? .on : .off
        autoItem.image = symbolImage("sparkles")
        submenu.addItem(autoItem)

        submenu.addItem(.separator())

        let languages: [(code: String, label: String)] = [
            ("en-US", "English (US)"),
            ("en-GB", "English (UK)"),
            ("es-ES", "Spanish"),
            ("fr-FR", "French"),
            ("de-DE", "German"),
            ("ja-JP", "Japanese"),
            ("zh-CN", "Chinese (Mandarin)"),
            ("hi-IN", "Hindi"),
            ("pt-BR", "Portuguese"),
            ("it-IT", "Italian"),
            ("ar-SA", "Arabic")
        ]

        for lang in languages {
            let item = NSMenuItem(
                title: lang.label,
                action: #selector(selectLanguageFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang.code
            item.state = (!settings.autoDetectLanguage && settings.preferredLanguage == lang.code) ? .on : .off
            submenu.addItem(item)
        }

        submenu.addItem(.separator())
        submenu.addItem(makeActionItem(
            title: "Speech & Translation Settings…",
            symbol: "globe",
            action: #selector(openSettingsSpeech)
        ))

        let parent = NSMenuItem(title: "Dictation Language", action: nil, keyEquivalent: "")
        parent.image = symbolImage("globe")
        parent.submenu = submenu
        return parent
    }

    private func makePasteMethodSubmenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Paste Method")
        submenu.autoenablesItems = false
        let current = AppSettings.shared.pasteMethod

        for method in PasteMethod.allCases {
            let item = NSMenuItem(
                title: method.displayName,
                action: #selector(selectPasteMethodFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = method.rawValue
            item.state = (method == current) ? .on : .off
            submenu.addItem(item)
        }

        let parent = NSMenuItem(title: "Paste Method (\(current.shortName))", action: nil, keyEquivalent: "")
        parent.image = symbolImage("keyboard.badge.ellipsis")
        parent.submenu = submenu
        return parent
    }

    private func makeEnhancementSubmenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "AI Enhancement")
        submenu.autoenablesItems = false
        let settings = AppSettings.shared

        let enabledItem = NSMenuItem(
            title: "Enable AI Cleanup & Formatting",
            action: #selector(toggleAIEnhancement),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = settings.aiEnhancementEnabled ? .on : .off
        enabledItem.image = symbolImage("sparkles")
        submenu.addItem(enabledItem)

        let translateItem = NSMenuItem(
            title: "Translate Dictation to English",
            action: #selector(toggleTranslateToEnglish),
            keyEquivalent: ""
        )
        translateItem.target = self
        translateItem.state = settings.translateToEnglish ? .on : .off
        translateItem.image = symbolImage("character.bubble")
        submenu.addItem(translateItem)

        submenu.addItem(.separator())
        submenu.addItem(makeActionItem(
            title: "Configure Prompts & Automation…",
            symbol: "bolt.fill",
            action: #selector(openSettingsAutomation)
        ))
        submenu.addItem(makeActionItem(
            title: "Configure Keyboard Shortcuts…",
            symbol: "keyboard",
            action: #selector(openSettingsHotkeys)
        ))

        let parent = NSMenuItem(title: "AI Cleanup & Shortcuts", action: nil, keyEquivalent: "")
        parent.image = symbolImage("wand.and.stars")
        parent.submenu = submenu
        return parent
    }

    private func makeRecentDictationsSubmenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Recent Dictations")
        submenu.autoenablesItems = false
        let items = Array(TranscriptionHistoryManager.shared.transcriptions.prefix(8))

        if items.isEmpty {
            let empty = NSMenuItem(title: "No dictations recorded yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            let hint = NSMenuItem(title: "Click any transcript to copy", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            submenu.addItem(hint)

            for entry in items {
                let singleLine = entry.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let clipped = singleLine.count > 48 ? String(singleLine.prefix(48)) + "…" : singleLine
                let row = NSMenuItem(
                    title: clipped.isEmpty ? "(Empty)" : clipped,
                    action: #selector(copyHistoryItemFromMenu(_:)),
                    keyEquivalent: ""
                )
                row.target = self
                row.representedObject = entry.text
                row.toolTip = entry.text
                row.image = symbolImage("doc.on.doc")
                submenu.addItem(row)
            }

            submenu.addItem(.separator())
            submenu.addItem(makeActionItem(
                title: "Open Full History…",
                symbol: "clock.arrow.circlepath",
                action: #selector(openHistory)
            ))
        }

        let parent = NSMenuItem(title: "Recent Dictations", action: nil, keyEquivalent: "")
        parent.image = symbolImage("clock.arrow.circlepath")
        parent.submenu = submenu
        return parent
    }

    // MARK: - NSMenuItem Factory

    private func makeActionItem(
        title: String,
        symbol: String,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        action: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = modifiers
        }
        item.target = self
        item.isEnabled = true
        item.image = symbolImage(symbol)
        return item
    }

    private func symbolImage(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .regular)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        img?.isTemplate = true
        return img
    }

    // MARK: - Actions

    @objc private func toggleDictationFromMenu() {
        DispatchQueue.main.async {
            AppCoordinator.shared.toggleDictation()
        }
    }

    @objc private func copyLatestFromMenu() {
        guard let latest = TranscriptionHistoryManager.shared.transcriptions.first else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latest.text, forType: .string)
    }

    @objc private func selectModelFromMenu(_ sender: NSMenuItem) {
        guard let modelID = sender.representedObject as? String else { return }
        let mm = ModelManager.shared
        guard let target = mm.availableModels.first(where: { $0.id == modelID }) else { return }

        if target.category == .local && !target.isBuiltIn && !mm.isInstalledAndUsable(target) {
            mm.downloadModel(target) { result in
                if case .success(let installed) = result {
                    _ = mm.setCurrentModel(installed)
                }
            }
        } else {
            _ = mm.setCurrentModel(target)
        }
    }

    @objc private func selectMicrophoneFromMenu(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String else { return }
        AudioManager.shared.selectAudioDevice(id: deviceID)
    }

    @objc private func toggleAutoDetectLanguage() {
        AppSettings.shared.autoDetectLanguage.toggle()
    }

    @objc private func selectLanguageFromMenu(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        AppSettings.shared.autoDetectLanguage = false
        AppSettings.shared.preferredLanguage = code
    }

    @objc private func selectPasteMethodFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let method = PasteMethod(rawValue: raw) else { return }
        AppSettings.shared.pasteMethod = method
    }

    @objc private func openQuickHistoryHUD() {
        QuickHistoryPanelController.shared.toggle()
    }

    @objc private func openQuickAddDictionaryHUD() {
        DictionaryQuickAddPanelController.shared.show()
    }

    @objc private func toggleAIEnhancement() {
        AppSettings.shared.aiEnhancementEnabled.toggle()
    }

    @objc private func toggleTranslateToEnglish() {
        AppSettings.shared.translateToEnglish.toggle()
    }

    @objc private func copyHistoryItemFromMenu(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc private func openDashboardHome() {
        (NSApp.delegate as? AppDelegate)?.showDashboard(item: .home)
    }

    @objc private func openHistory() {
        (NSApp.delegate as? AppDelegate)?.showDashboard(item: .history)
    }

    @objc private func openNotes() {
        (NSApp.delegate as? AppDelegate)?.showDashboard(item: .notes)
    }

    @objc private func openDictionary() {
        (NSApp.delegate as? AppDelegate)?.showDashboard(item: .dictionary)
    }

    @objc private func openShareCard() {
        (NSApp.delegate as? AppDelegate)?.showDashboard(item: .share)
    }

    @objc private func openEchoProfile() {
        (NSApp.delegate as? AppDelegate)?.showEchoProfile()
    }

    @objc private func openTasks() {
        (NSApp.delegate as? AppDelegate)?.showCommitments()
    }

    @objc private func openSettingsGeneral() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .general)
    }

    @objc private func openSettingsModels() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .aiModels)
    }

    @objc private func openSettingsSpeech() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .speech)
    }

    @objc private func openSettingsAutomation() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .automation)
    }

    @objc private func openSettingsHotkeys() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .hotkeys)
    }

    @objc private func openAboutLicense() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .license)
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
