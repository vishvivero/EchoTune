//
//  KeyboardShortcutRecorder.swift
//  EchoTune
//
//  Keyboard shortcut recorder for custom shortcuts
//

import SwiftUI
import AppKit

struct KeyboardShortcutRecorder: View {
    @Binding var isPresented: Bool
    @State private var recordedShortcut: String = "Press keys..."
    @State private var isRecording = false
    @State private var capturedKeyCode: UInt32?
    @State private var capturedModifiers: UInt32?
    @State private var eventMonitor: Any?
    @State private var previousModifiers: UInt32 = 0

    let shortcutManager = ShortcutManager.shared
    let onSave: (UInt32, UInt32) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Record Keyboard Shortcut")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Click \"Start Recording\" then press your desired keyboard shortcut")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Shortcut Display
            HStack {
                if isRecording {
                    Image(systemName: "record.circle")
                        .foregroundColor(.red)
                        .imageScale(.large)
                }

                Text(recordedShortcut)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(minWidth: 200)
                    .background(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(isRecording ? .red : .blue)
                    .cornerRadius(8)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Use a single key: Function keys (F1-F12), ⌃ Control, or ⌥ Option")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Or combine modifiers with letter keys (⌘⇧D, ⌃⌥E, etc.)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Avoid system shortcuts like ⌘Q, ⌘W, ⌘C, ⌘V")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)

                if isRecording {
                    Button("Stop Recording") {
                        stopRecording()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Start Recording") {
                        startRecording()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                Button("Save") {
                    saveShortcut()
                }
                .buttonStyle(.borderedProminent)
                .disabled(capturedKeyCode == nil || capturedModifiers == nil)
            }
        }
        .padding(24)
        .frame(width: 500)
        .onDisappear {
            // Clean up event monitor if still active
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private func startRecording() {
        isRecording = true
        recordedShortcut = "Press keys..."
        capturedKeyCode = nil
        capturedModifiers = nil
        previousModifiers = 0

        // Start monitoring for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                self.handleKeyDown(event: event)
                return nil // Consume the event
            } else if event.type == .flagsChanged {
                self.handleFlagsChanged(event: event)
                return event
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false

        // Remove the event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyDown(event: NSEvent) {
        guard isRecording else { return }

        let keyCode = UInt32(event.keyCode)
        let modifierFlags = event.modifierFlags

        // Extract relevant modifiers
        var modifiers: UInt32 = 0
        if modifierFlags.contains(.command) {
            modifiers |= UInt32(NSEvent.ModifierFlags.command.rawValue)
        }
        if modifierFlags.contains(.shift) {
            modifiers |= UInt32(NSEvent.ModifierFlags.shift.rawValue)
        }
        if modifierFlags.contains(.control) {
            modifiers |= UInt32(NSEvent.ModifierFlags.control.rawValue)
        }
        if modifierFlags.contains(.option) {
            modifiers |= UInt32(NSEvent.ModifierFlags.option.rawValue)
        }

        // Check if it's a function key (F1-F12) - these can be used alone
        let isFunctionKey = (keyCode >= 122 && keyCode <= 111) || // F1-F12 range
                           keyCode == 122 || keyCode == 120 || keyCode == 99 ||
                           keyCode == 118 || keyCode == 96 || keyCode == 97 ||
                           keyCode == 98 || keyCode == 100 || keyCode == 101 ||
                           keyCode == 109 || keyCode == 103 || keyCode == 111

        // Allow function keys without modifiers, or any key with modifiers
        if isFunctionKey {
            // Function key - allow with or without modifiers
            capturedKeyCode = keyCode
            capturedModifiers = modifiers

            let modifierString = shortcutManager.modifierFlagsToString(modifiers)
            let keyString = getKeyString(for: keyCode)
            recordedShortcut = modifierString + keyString

            stopRecording()
        } else if modifiers != 0 {
            // Regular key with modifiers
            capturedKeyCode = keyCode
            capturedModifiers = modifiers

            let modifierString = shortcutManager.modifierFlagsToString(modifiers)
            let keyString = getKeyString(for: keyCode)
            recordedShortcut = modifierString + keyString

            stopRecording()
        } else {
            recordedShortcut = "⚠️ Use function key or add modifier"
        }
    }

    private func handleFlagsChanged(event: NSEvent) {
        guard isRecording else { return }

        let modifierFlags = event.modifierFlags

        // Extract current modifiers
        var currentModifiers: UInt32 = 0
        if modifierFlags.contains(.command) {
            currentModifiers |= UInt32(NSEvent.ModifierFlags.command.rawValue)
        }
        if modifierFlags.contains(.shift) {
            currentModifiers |= UInt32(NSEvent.ModifierFlags.shift.rawValue)
        }
        if modifierFlags.contains(.control) {
            currentModifiers |= UInt32(NSEvent.ModifierFlags.control.rawValue)
        }
        if modifierFlags.contains(.option) {
            currentModifiers |= UInt32(NSEvent.ModifierFlags.option.rawValue)
        }

        // Detect single modifier key release (Control or Option only)
        if previousModifiers != 0 && currentModifiers == 0 {
            // They released a modifier key
            let controlOnly = UInt32(NSEvent.ModifierFlags.control.rawValue)
            let optionOnly = UInt32(NSEvent.ModifierFlags.option.rawValue)

            // Check if it was ONLY Control or ONLY Option (no other modifiers)
            if previousModifiers == controlOnly {
                // Control key alone
                capturedKeyCode = 59 // Special code for Control
                capturedModifiers = controlOnly
                recordedShortcut = "⌃ Control"
                stopRecording()
                previousModifiers = 0
                return
            } else if previousModifiers == optionOnly {
                // Option key alone
                capturedKeyCode = 58 // Special code for Option
                capturedModifiers = optionOnly
                recordedShortcut = "⌥ Option"
                stopRecording()
                previousModifiers = 0
                return
            }
        }

        // Update previous modifiers
        previousModifiers = currentModifiers

        // Show visual feedback
        var modifierString = ""
        if modifierFlags.contains(.command) {
            modifierString += "⌘"
        }
        if modifierFlags.contains(.shift) {
            modifierString += "⇧"
        }
        if modifierFlags.contains(.control) {
            modifierString += "⌃"
        }
        if modifierFlags.contains(.option) {
            modifierString += "⌥"
        }

        if !modifierString.isEmpty {
            recordedShortcut = modifierString + "..."
        } else {
            recordedShortcut = "Press keys..."
        }
    }

    private func getKeyString(for keyCode: UInt32) -> String {
        // Map common key codes to characters
        switch keyCode {
        // Special modifier keys (when used alone)
        case 59: return " Control"
        case 58: return " Option"
        // Letter keys
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Escape"
        // Function keys
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "?"
        }
    }

    private func saveShortcut() {
        guard let keyCode = capturedKeyCode, let modifiers = capturedModifiers else {
            return
        }

        // Validate that it's not a system shortcut
        if isSystemShortcut(keyCode: keyCode, modifiers: modifiers) {
            let alert = NSAlert()
            alert.messageText = "System Shortcut"
            alert.informativeText = "This shortcut is reserved by macOS. Please choose a different combination."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Save the shortcut
        onSave(keyCode, modifiers)
        isPresented = false
    }

    private func isSystemShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let cmdOnly = UInt32(NSEvent.ModifierFlags.command.rawValue)

        // Check for common system shortcuts with just Command key
        if modifiers == cmdOnly {
            switch keyCode {
            case 12: return true  // ⌘Q (Quit)
            case 13: return true  // ⌘W (Close)
            case 8: return true   // ⌘C (Copy)
            case 9: return true   // ⌘V (Paste)
            case 7: return true   // ⌘X (Cut)
            case 0: return true   // ⌘A (Select All)
            case 6: return true   // ⌘Z (Undo)
            default: return false
            }
        }

        return false
    }
}

// MARK: - Preview

#Preview {
    KeyboardShortcutRecorder(isPresented: .constant(true)) { keyCode, modifiers in
        debugLog("Saved: \(keyCode), \(modifiers)")
    }
}
