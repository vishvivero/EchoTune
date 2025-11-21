//
//  MultiHotkeyManager.swift
//  EchoTune
//
//  Phase 6C: Multiple Hotkeys Support
//  Allows users to register multiple keyboard shortcuts for different actions
//

import Foundation
import AppKit
import Carbon
import Combine

class MultiHotkeyManager: ObservableObject {
    static let shared = MultiHotkeyManager()

    enum HotkeyAction: String, CaseIterable, Codable, Identifiable {
        case toggleDictation = "Toggle Dictation"
        case startDictation = "Start Dictation"
        case stopDictation = "Stop Dictation"
        case pasteLastTranscript = "Paste Last Transcript"
        case pasteLastEnhanced = "Paste Last Enhanced"
        case showMainWindow = "Show Main Window"
        case togglePowerModes = "Toggle Power Modes"

        var id: String { rawValue }

        var defaultShortcut: String? {
            switch self {
            case .toggleDictation:
                return "^D"  // Control+D
            case .startDictation:
                return nil
            case .stopDictation:
                return nil
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

    struct HotkeyBinding: Codable, Identifiable {
        let id: UUID
        let action: HotkeyAction
        var keyCode: UInt32?
        var modifiers: UInt32?
        var displayString: String?
        var isEnabled: Bool

        init(action: HotkeyAction,
             keyCode: UInt32? = nil,
             modifiers: UInt32? = nil,
             displayString: String? = nil,
             isEnabled: Bool = true) {
            self.id = UUID()
            self.action = action
            self.keyCode = keyCode
            self.modifiers = modifiers
            self.displayString = displayString ?? action.defaultShortcut
            self.isEnabled = isEnabled
        }
    }

    @Published var hotkeyBindings: [HotkeyBinding] = []
    private var eventHandlers: [EventHotKeyRef?] = []

    private let storageKey = "multiHotkeyBindings"

    private init() {
        loadBindings()
        registerAllHotkeys()
        print("✅ MultiHotkeyManager initialized with \(hotkeyBindings.count) bindings")
    }

    // MARK: - Hotkey Management

    func updateBinding(_ binding: HotkeyBinding) {
        if let index = hotkeyBindings.firstIndex(where: { $0.id == binding.id }) {
            hotkeyBindings[index] = binding
            saveBindings()

            // Re-register all hotkeys
            unregisterAllHotkeys()
            registerAllHotkeys()

            print("✏️ Updated hotkey for \(binding.action.rawValue)")
        }
    }

    func enableBinding(for action: HotkeyAction, enabled: Bool) {
        if let index = hotkeyBindings.firstIndex(where: { $0.action == action }) {
            hotkeyBindings[index].isEnabled = enabled
            saveBindings()

            // Re-register hotkeys
            unregisterAllHotkeys()
            registerAllHotkeys()
        }
    }

    func getBinding(for action: HotkeyAction) -> HotkeyBinding? {
        return hotkeyBindings.first { $0.action == action }
    }

    // MARK: - Hotkey Registration

    private func registerAllHotkeys() {
        for binding in hotkeyBindings where binding.isEnabled {
            guard let keyCode = binding.keyCode,
                  let modifiers = binding.modifiers else {
                continue
            }

            registerHotkey(binding: binding)
        }
    }

    private func registerHotkey(binding: HotkeyBinding) {
        guard let keyCode = binding.keyCode,
              let modifiers = binding.modifiers else {
            return
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(binding.action.rawValue.hashValue), id: UInt32(binding.id.hashValue))

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            eventHandlers.append(hotKeyRef)
            print("⌨️ Registered hotkey: \(binding.displayString ?? "Unknown") for \(binding.action.rawValue)")
        } else {
            print("❌ Failed to register hotkey for \(binding.action.rawValue)")
        }
    }

    private func unregisterAllHotkeys() {
        for handler in eventHandlers {
            if let handler = handler {
                UnregisterEventHotKey(handler)
            }
        }
        eventHandlers.removeAll()
    }

    // MARK: - Action Handlers

    func handleHotkeyAction(_ action: HotkeyAction) {
        print("🔥 Hotkey triggered: \(action.rawValue)")

        switch action {
        case .toggleDictation:
            AppCoordinator.shared.toggleDictation()

        case .startDictation:
            AppCoordinator.shared.startDictation()

        case .stopDictation:
            AppCoordinator.shared.stopDictation()

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
        // TODO: Implement last transcript storage
        print("📋 Paste last transcript (enhanced: \(enhanced))")

        // For now, show notification
        NotificationManager.shared.showNotification(
            title: "Paste Last Transcript",
            body: "This feature will paste your last transcription",
            sound: false
        )
    }

    private func showMainWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            // Find and show the main window
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

    private func loadBindings() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            hotkeyBindings = decoded
            print("📂 Loaded \(hotkeyBindings.count) hotkey bindings")
        } else {
            // Create default bindings
            hotkeyBindings = HotkeyAction.allCases.map { action in
                HotkeyBinding(
                    action: action,
                    displayString: action.defaultShortcut,
                    isEnabled: action.defaultShortcut != nil
                )
            }
            saveBindings()
            print("📂 Initialized default hotkey bindings")
        }
    }

    // MARK: - Helper Methods

    func parseKeyboardShortcut(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        // Parse strings like "⌘⇧D" into keyCode and modifiers
        // This is a simplified implementation
        // Real implementation would need proper key mapping

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

        // Extract the key (last character usually)
        guard let lastChar = shortcut.last else { return nil }

        // Map character to virtual key code
        let keyCode = mapCharacterToKeyCode(lastChar)

        guard let code = keyCode else { return nil }

        return (code, modifiers)
    }

    private func mapCharacterToKeyCode(_ char: Character) -> UInt32? {
        // Simplified key mapping
        // Real implementation would have complete mapping
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
        hotkeyBindings = HotkeyAction.allCases.map { action in
            HotkeyBinding(
                action: action,
                displayString: action.defaultShortcut,
                isEnabled: action.defaultShortcut != nil
            )
        }
        saveBindings()
        unregisterAllHotkeys()
        registerAllHotkeys()
        print("🔄 Reset to default hotkey bindings")
    }
}
