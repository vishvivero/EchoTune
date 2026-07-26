//
//  MultiHotkeyManager.swift
//  EchoTune
//
//  Phase 6C+: Multiple Hotkeys with Modifier Key Support
//  Allows users to register multiple keyboard shortcuts for different actions
//  including single modifier keys (Right Cmd, Left Option, Fn) as push-to-talk triggers
//

import Foundation
import AppKit
import Carbon
import Combine

class MultiHotkeyManager: ObservableObject {
    static let shared = MultiHotkeyManager()

    // Auxiliary hotkeys only. The primary dictation trigger is owned solely by
    // ShortcutManager (the single Option-key push-to-talk/toggle path) — keeping
    // dictation out of here is what prevents the old double-fire, where one key
    // press ran toggleDictation() through both systems.
    enum HotkeyAction: String, CaseIterable, Codable, Identifiable {
        case pasteLastTranscript = "Paste Last Transcript"
        case pasteLastEnhanced = "Paste Last Enhanced"
        case showMainWindow = "Show Main Window"
        case togglePowerModes = "Toggle Power Modes"

        var id: String { rawValue }

        var defaultShortcut: String? {
            switch self {
            case .pasteLastTranscript:
                return "⌘⇧T"  // Command+Shift+T
            case .pasteLastEnhanced:
                return nil
            case .showMainWindow:
                return "⌘⇧E"  // Command+Shift+E
            case .togglePowerModes:
                return nil
            }
        }
    }

    /// Represents a modifier key that can be used standalone as a hotkey trigger
    enum ModifierKeyTrigger: String, CaseIterable, Codable, Identifiable {
        case rightCommand = "Right ⌘"
        case leftCommand = "Left ⌘"
        case rightOption = "Right ⌥"
        case leftOption = "Left ⌥"
        case rightControl = "Right ⌃"
        case leftControl = "Left ⌃"
        case fn = "fn (Globe)"
        case none = "None"

        var id: String { rawValue }

        var displayName: String { rawValue }

        /// The NSEvent.ModifierFlags bit that distinguishes this key
        var flagBit: UInt {
            switch self {
            case .rightCommand:  return NSEvent.ModifierFlags.command.rawValue
            case .leftCommand:   return NSEvent.ModifierFlags.command.rawValue
            case .rightOption:   return NSEvent.ModifierFlags.option.rawValue
            case .leftOption:    return NSEvent.ModifierFlags.option.rawValue
            case .rightControl:  return NSEvent.ModifierFlags.control.rawValue
            case .leftControl:   return NSEvent.ModifierFlags.control.rawValue
            case .fn:            return NSEvent.ModifierFlags.function.rawValue
            case .none:          return 0
            }
        }

        /// The raw Carbon/IOKit key code to differentiate left vs right
        /// Left/right modifiers can be detected from the CGEvent keyCode in flagsChanged
        var expectedKeyCode: UInt16? {
            switch self {
            case .rightCommand:  return 54   // kVK_RightCommand
            case .leftCommand:   return 55   // kVK_Command
            case .rightOption:   return 61   // kVK_RightOption
            case .leftOption:    return 58   // kVK_Option
            case .rightControl:  return 62   // kVK_RightControl
            case .leftControl:   return 59   // kVK_Control
            case .fn:            return 63   // kVK_Function
            case .none:          return nil
            }
        }
    }

    struct HotkeyBinding: Codable, Identifiable {
        let id: UUID
        let action: HotkeyAction
        var keyCode: UInt32?
        var modifiers: UInt32?
        var displayString: String?
        var isEnabled: Bool
        var modifierTrigger: ModifierKeyTrigger?  // NEW: single modifier key trigger

        init(action: HotkeyAction,
             keyCode: UInt32? = nil,
             modifiers: UInt32? = nil,
             displayString: String? = nil,
             isEnabled: Bool = true,
             modifierTrigger: ModifierKeyTrigger? = nil) {
            self.id = UUID()
            self.action = action
            self.keyCode = keyCode
            self.modifiers = modifiers
            self.displayString = displayString ?? action.defaultShortcut
            self.isEnabled = isEnabled
            self.modifierTrigger = modifierTrigger
        }

        /// Whether this binding uses a single modifier key as trigger
        var isModifierOnlyBinding: Bool {
            return modifierTrigger != nil && modifierTrigger != .none
        }
    }

    @Published var hotkeyBindings: [HotkeyBinding] = []

    // Modifier-key monitoring via CGEvent tap
    private var modifierEventTap: CFMachPort?
    private var modifierRunLoopSource: CFRunLoopSource?
    private var modifierKeyPressed: [ModifierKeyTrigger: Bool] = [:]

    private let storageKey = "multiHotkeyBindings"

    private init() {
        loadBindings()
        registerAllHotkeys()
        setupModifierKeyMonitoring()
        debugLog("✅ MultiHotkeyManager initialized with \(hotkeyBindings.count) bindings")
    }

    deinit {
        teardownModifierKeyMonitoring()
    }

    // MARK: - Modifier Key Event Monitoring (NEW)

    /// Sets up a CGEvent tap to monitor flagsChanged events for modifier-only hotkeys
    private func setupModifierKeyMonitoring() {
        // Check if any binding uses a modifier trigger
        let hasModifierBindings = hotkeyBindings.contains { $0.isModifierOnlyBinding && $0.isEnabled }
        guard hasModifierBindings else {
            debugLog("ℹ️ No modifier-key bindings active, skipping event tap")
            return
        }

        guard AXIsProcessTrusted() else {
            debugLog("⚠️ Modifier key monitoring requires accessibility permission")
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<MultiHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleModifierEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Listen only — don't consume modifier events
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            debugLog("❌ Failed to create modifier event tap")
            return
        }

        modifierEventTap = tap
        modifierRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), modifierRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        debugLog("✅ Modifier key event tap registered")
    }

    private func teardownModifierKeyMonitoring() {
        if let source = modifierRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            modifierRunLoopSource = nil
        }
        if let tap = modifierEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            modifierEventTap = nil
        }
    }

    /// Handles flagsChanged CGEvents to detect single modifier key presses/releases
    private func handleModifierEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable the tap if macOS disabled it (timeout/user input),
        // otherwise the hotkey silently dies until relaunch.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = modifierEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                debugLog("♻️ Modifier event tap re-enabled after disable event")
            }
            return nil
        }
        guard type == .flagsChanged else { return Unmanaged.passRetained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

        // Check each active modifier binding
        for binding in hotkeyBindings where binding.isModifierOnlyBinding && binding.isEnabled {
            guard let trigger = binding.modifierTrigger,
                  let expectedKeyCode = trigger.expectedKeyCode else {
                continue
            }

            if keyCode == expectedKeyCode {
                let isPressed = isModifierActive(trigger: trigger, flags: flags)
                let wasPressed = modifierKeyPressed[trigger] ?? false

                if isPressed && !wasPressed {
                    // Key pressed down
                    modifierKeyPressed[trigger] = true
                    debugLog("🎯 Modifier key pressed: \(trigger.displayName) for \(binding.action.rawValue)")
                    DispatchQueue.main.async { [weak self] in
                        self?.handleHotkeyAction(binding.action)
                    }
                } else if !isPressed && wasPressed {
                    // Key released — auxiliary actions fire on press only, so
                    // nothing to do here beyond clearing the pressed flag.
                    modifierKeyPressed[trigger] = false
                    debugLog("🎯 Modifier key released: \(trigger.displayName) for \(binding.action.rawValue)")
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    /// Checks if a specific modifier is currently active in the flags
    private func isModifierActive(trigger: ModifierKeyTrigger, flags: NSEvent.ModifierFlags) -> Bool {
        switch trigger {
        case .rightCommand, .leftCommand:
            return flags.contains(.command)
        case .rightOption, .leftOption:
            return flags.contains(.option)
        case .rightControl, .leftControl:
            return flags.contains(.control)
        case .fn:
            return flags.contains(.function)
        case .none:
            return false
        }
    }

    // MARK: - Hotkey Management

    func updateBinding(_ binding: HotkeyBinding) {
        if let index = hotkeyBindings.firstIndex(where: { $0.id == binding.id }) {
            hotkeyBindings[index] = binding
            saveBindings()

            // Re-register all hotkeys
            unregisterAllHotkeys()
            registerAllHotkeys()

            // Re-setup modifier monitoring since bindings changed
            teardownModifierKeyMonitoring()
            setupModifierKeyMonitoring()

            debugLog("✏️ Updated hotkey for \(binding.action.rawValue)")
        }
    }

    /// Assigns a modifier key trigger to an action
    func setModifierTrigger(_ trigger: ModifierKeyTrigger, for action: HotkeyAction) {
        if let index = hotkeyBindings.firstIndex(where: { $0.action == action }) {
            hotkeyBindings[index] = HotkeyBinding(
                action: action,
                keyCode: nil,
                modifiers: nil,
                displayString: trigger == .none ? nil : trigger.displayName,
                isEnabled: trigger != .none,
                modifierTrigger: trigger
            )
            saveBindings()

            unregisterAllHotkeys()
            registerAllHotkeys()
            teardownModifierKeyMonitoring()
            setupModifierKeyMonitoring()

            debugLog("✅ Set modifier trigger \(trigger.displayName) for \(action.rawValue)")
        }
    }

    func enableBinding(for action: HotkeyAction, enabled: Bool) {
        if let index = hotkeyBindings.firstIndex(where: { $0.action == action }) {
            hotkeyBindings[index].isEnabled = enabled
            saveBindings()

            // Re-register hotkeys
            unregisterAllHotkeys()
            registerAllHotkeys()

            // Rebuild modifier monitoring
            teardownModifierKeyMonitoring()
            setupModifierKeyMonitoring()
        }
    }

    func getBinding(for action: HotkeyAction) -> HotkeyBinding? {
        return hotkeyBindings.first { $0.action == action }
    }

    // MARK: - Hotkey Registration (for non-modifier bindings)

    // Carbon RegisterEventHotKey registration removed for 4.0.0: there was
    // never an InstallEventHandler, so registered combos could not be
    // delivered — and the OSType/UInt32(hashValue) conversions would trap.
    // Modifier-only bindings still work via the CGEvent tap above.

    private func registerAllHotkeys() {
        // Intentionally empty — see note above.
    }

    private func unregisterAllHotkeys() {
        // Intentionally empty — see note above.
    }

    // MARK: - Action Handlers

    func handleHotkeyAction(_ action: HotkeyAction) {
        debugLog("🔥 Hotkey triggered: \(action.rawValue)")

        switch action {
        case .pasteLastTranscript:
            pasteLastTranscript(enhanced: false)

        case .pasteLastEnhanced:
            pasteLastTranscript(enhanced: true)

        case .showMainWindow:
            showMainWindow()

        case .togglePowerModes:
            togglePowerModes()
        }
    }

    private func pasteLastTranscript(enhanced: Bool) {
        debugLog("📋 Paste last transcript (enhanced: \(enhanced))")

        guard let lastTranscript = TranscriptionHistoryManager.shared.transcriptions.first else {
            NotificationManager.shared.showNotification(
                title: "No Transcript Available",
                body: "Record something first to use this feature.",
                sound: false
            )
            return
        }

        let textToInsert = lastTranscript.text

        if enhanced {
            Task {
                do {
                    let settings = AppSettings.shared
                    guard settings.aiEnhancementEnabled else {
                        await MainActor.run { insertText(textToInsert) }
                        return
                    }

                    guard let model = AIEnhancementEngine.EnhancementModel(rawValue: settings.selectedEnhancementModel) else {
                        await MainActor.run { insertText(textToInsert) }
                        return
                    }

                    let apiKey = settings.apiKey(for: model.provider)

                    guard !apiKey.isEmpty else {
                        await MainActor.run { insertText(textToInsert) }
                        return
                    }

                    let enhanced = try await AIEnhancementEngine.shared.enhance(
                        textToInsert,
                        using: model,
                        apiKey: apiKey
                    )
                    await MainActor.run { insertText(enhanced) }
                } catch {
                    await MainActor.run { insertText(textToInsert) }
                }
            }
        } else {
            insertText(textToInsert)
        }
    }

    private func insertText(_ text: String) {
        TextInsertionManager.shared.insertText(text) { result in
            switch result {
            case .success:
                NotificationManager.shared.showNotification(
                    title: "Transcript Pasted",
                    body: "Inserted \(text.split(separator: " ").count) words",
                    sound: false
                )
            case .failure(let error):
                debugLog("❌ Failed to insert text: \(error)")
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)

                NotificationManager.shared.showNotification(
                    title: "Copied to Clipboard",
                    body: "Text was copied (couldn't insert directly)",
                    sound: false
                )
            }
        }
    }

    private func showMainWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.title.contains("EchoTune") || $0.isKeyWindow }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func togglePowerModes() {
        let currentState = PowerModeManager.shared.isEnabled
        PowerModeManager.shared.setEnabled(!currentState)

        NotificationManager.shared.showNotification(
            title: "Power Modes",
            body: currentState ? "Power Modes disabled" : "Power Modes enabled",
            sound: false
        )
    }

    // MARK: - Persistence

    private func saveBindings() {
        if let encoded = try? JSONEncoder().encode(hotkeyBindings) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func defaultBinding(for action: HotkeyAction) -> HotkeyBinding {
        HotkeyBinding(
            action: action,
            displayString: action.defaultShortcut,
            isEnabled: action.defaultShortcut != nil
        )
    }

    private func loadBindings() {
        // Only auxiliary actions live here now. Any persisted binding for a
        // removed action (the old dictation entries) is dropped by keying off
        // the current HotkeyAction.allCases.
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            hotkeyBindings = HotkeyAction.allCases.map { action in
                decoded.first(where: { $0.action == action }) ?? defaultBinding(for: action)
            }
            saveBindings()
            debugLog("📂 Loaded \(hotkeyBindings.count) hotkey bindings")
        } else {
            hotkeyBindings = HotkeyAction.allCases.map { defaultBinding(for: $0) }
            saveBindings()
            debugLog("📂 Initialized default hotkey bindings")
        }
    }

    // MARK: - Helper Methods

    func parseKeyboardShortcut(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        var modifiers: UInt32 = 0

        if shortcut.contains("⌘") || shortcut.contains("Cmd") {
            modifiers |= UInt32(cmdKey)
        }
        if shortcut.contains("⇧") || shortcut.contains("Shift") {
            modifiers |= UInt32(shiftKey)
        }
        if shortcut.contains("⌥") || shortcut.contains("Opt") {
            modifiers |= UInt32(optionKey)
        }
        if shortcut.contains("⌃") || shortcut.contains("Ctrl") {
            modifiers |= UInt32(controlKey)
        }

        guard let lastChar = shortcut.last else { return nil }
        let keyCode = mapCharacterToKeyCode(lastChar)
        guard let code = keyCode else { return nil }
        return (code, modifiers)
    }

    private func mapCharacterToKeyCode(_ char: Character) -> UInt32? {
        switch char.lowercased() {
        case "a": return 0
        case "b": return 11
        case "c": return 8
        case "d": return 2
        case "e": return 14
        case "t": return 17
        default: return nil
        }
    }

    // Reset to defaults
    func resetToDefaults() {
        hotkeyBindings = HotkeyAction.allCases.map { defaultBinding(for: $0) }
        saveBindings()
        unregisterAllHotkeys()
        registerAllHotkeys()
        teardownModifierKeyMonitoring()
        setupModifierKeyMonitoring()
        debugLog("🔄 Reset to default hotkey bindings")
    }
}
