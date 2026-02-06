//
//  HotkeysView.swift
//  EchoTune
//
//  Phase 6C UI: Multiple Hotkeys Configuration
//

import SwiftUI
import Carbon

struct HotkeysView: View {
    @ObservedObject var hotkeyManager = MultiHotkeyManager.shared
    @State private var editingHotkey: MultiHotkeyManager.HotkeyAction?
    @State private var showingRecordSheet = false

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcuts")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Configure global keyboard shortcuts for quick access to EchoTune features.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Hotkey List
            Section {
                ForEach(MultiHotkeyManager.HotkeyAction.allCases) { action in
                    if let binding = hotkeyManager.getBinding(for: action) {
                        HotkeyRow(
                            binding: binding,
                            onEdit: {
                                editingHotkey = action
                                showingRecordSheet = true
                            },
                            onToggle: { enabled in
                                hotkeyManager.enableBinding(for: action, enabled: enabled)
                            }
                        )
                    }
                }
            } header: {
                Text("Active Shortcuts")
            }

            // Actions
            Section {
                Button("Reset to Defaults") {
                    hotkeyManager.resetToDefaults()
                }
                .foregroundColor(.orange)
            }

            // Help
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Tips")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)

                    Text("• Click on a shortcut to change it")
                    Text("• Use ⌘ (Command), ⌃ (Control), ⌥ (Option), ⇧ (Shift)")
                    Text("• Avoid conflicts with system shortcuts")
                    Text("• Disable unused shortcuts to free up key combinations")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingRecordSheet) {
            if let action = editingHotkey {
                HotkeyRecordSheet(action: action, isPresented: $showingRecordSheet)
            }
        }
    }
}

struct HotkeyRow: View {
    let binding: MultiHotkeyManager.HotkeyBinding
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void

    @State private var isEnabled: Bool

    init(binding: MultiHotkeyManager.HotkeyBinding, onEdit: @escaping () -> Void, onToggle: @escaping (Bool) -> Void) {
        self.binding = binding
        self.onEdit = onEdit
        self.onToggle = onToggle
        _isEnabled = State(initialValue: binding.isEnabled)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(binding.action.rawValue)
                    .font(.body)

                if let description = actionDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let shortcut = binding.displayString {
                Button(action: onEdit) {
                    Text(shortcut)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onEdit) {
                    Text("Set Shortcut")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { newValue in
                    onToggle(newValue)
                }
        }
    }

    var actionDescription: String? {
        switch binding.action {
        case .toggleDictation:
            return "Start/stop voice dictation"
        case .startDictation:
            return "Start dictation only"
        case .stopDictation:
            return "Stop dictation only"
        case .pasteLastTranscript:
            return "Paste your last transcription"
        case .pasteLastEnhanced:
            return "Paste last with AI enhancement"
        case .showMainWindow:
            return "Show EchoTune window"
        case .togglePowerModes:
            return "Enable/disable Power Modes"
        }
    }
}

struct HotkeyRecordSheet: View {
    let action: MultiHotkeyManager.HotkeyAction
    @Binding var isPresented: Bool

    @State private var recordedShortcut: String = "Press keys..."
    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32?
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(spacing: 20) {
            Text("Record Shortcut")
                .font(.title2)
                .fontWeight(.bold)

            Text("for \(action.rawValue)")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Text(recordedShortcut)
                    .font(.system(.title, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isRecording ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 2)
                    )

                Text(isRecording ? "Press your desired key combination now..." : "Click 'Record' to begin")
                    .font(.caption)
                    .foregroundColor(isRecording ? .blue : .secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") {
                    stopRecording()
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(isRecording ? "Stop Recording" : "Record") {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .buttonStyle(.bordered)

                if recordedKeyCode != nil && recordedModifiers != nil {
                    Button("Save") {
                        saveShortcut()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(30)
        .frame(width: 400, height: 300)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordedShortcut = "Waiting for keys..."

        // Monitor for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                // Capture key code and modifiers
                self.recordedKeyCode = UInt32(event.keyCode)
                self.recordedModifiers = UInt32(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)

                // Build display string
                self.recordedShortcut = buildDisplayString(keyCode: event.keyCode, modifiers: event.modifierFlags)

                // Stop recording after capturing
                self.stopRecording()

                return nil // Consume the event
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func buildDisplayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        // Map key code to character
        let keyChar = keyCodeToCharacter(keyCode)
        parts.append(keyChar)

        return parts.joined()
    }

    private func keyCodeToCharacter(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↵",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "F2",
            120: "F1", 122: "F16", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]

        return keyMap[keyCode] ?? "?"
    }

    private func saveShortcut() {
        guard let keyCode = recordedKeyCode, let modifiers = recordedModifiers else { return }

        // Convert modifiers to Carbon format
        var carbonModifiers: UInt32 = 0
        let nsModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiers))

        if nsModifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if nsModifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if nsModifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        // Update the binding
        if var binding = MultiHotkeyManager.shared.getBinding(for: action) {
            let updatedBinding = MultiHotkeyManager.HotkeyBinding(
                action: action,
                keyCode: keyCode,
                modifiers: carbonModifiers,
                displayString: recordedShortcut,
                isEnabled: binding.isEnabled
            )
            MultiHotkeyManager.shared.updateBinding(updatedBinding)

            print("✅ Saved shortcut: \(recordedShortcut) for \(action.rawValue)")

            NotificationManager.shared.showNotification(
                title: "Shortcut Updated",
                body: "\(action.rawValue) is now \(recordedShortcut)",
                sound: false
            )
        }
    }
}

#Preview {
    HotkeysView()
        .frame(width: 600, height: 700)
}
