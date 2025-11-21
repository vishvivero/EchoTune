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
    @State private var isRecording = false

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
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                Text(isRecording ? "Press your desired key combination" : "Click 'Record' to begin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(isRecording ? "Stop Recording" : "Record") {
                    isRecording.toggle()
                }
                .keyboardShortcut(.defaultAction)

                if recordedShortcut != "Press keys..." {
                    Button("Save") {
                        // TODO: Save the new shortcut
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(30)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    HotkeysView()
        .frame(width: 600, height: 700)
}
