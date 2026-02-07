//
//  PowerModesView.swift
//  EchoTune
//
//  Phase 6 UI: Power Modes Management
//

import SwiftUI

struct PowerModesView: View {
    @ObservedObject var powerModeManager = PowerModeManager.shared
    @State private var selectedMode: PowerMode?
    @State private var showingEditSheet = false
    @State private var showingCreateSheet = false

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Power Modes")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Context-aware configurations that automatically switch settings based on the active app or website.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Master Toggle
            Section {
                Toggle("Enable Power Modes", isOn: Binding(
                    get: { powerModeManager.isEnabled },
                    set: { powerModeManager.setEnabled($0) }
                ))
                .toggleStyle(.switch)

                Toggle("Auto-Switch on App Change", isOn: Binding(
                    get: { powerModeManager.isAutoSwitchEnabled },
                    set: { powerModeManager.setAutoSwitchEnabled($0) }
                ))
                .toggleStyle(.switch)
                .disabled(!powerModeManager.isEnabled)
            } header: {
                Text("Power Modes")
            } footer: {
                Text("When Auto-Switch is enabled, EchoTune automatically detects the active application and applies the matching Power Mode in real time — no need to start a recording first.")
                    .font(.caption)
            }

            // Current Active Mode
            if let currentMode = powerModeManager.currentPowerMode {
                Section {
                    HStack {
                        Text(currentMode.emoji)
                            .font(.title)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentMode.name)
                                .font(.headline)

                            Text("Currently Active")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Active Mode")
                }
            }

            // Available Power Modes
            Section {
                ForEach(powerModeManager.powerModes) { mode in
                    PowerModeRow(
                        mode: mode,
                        isActive: mode.id == powerModeManager.currentPowerMode?.id,
                        onEdit: {
                            selectedMode = mode
                            showingEditSheet = true
                        },
                        onToggle: { enabled in
                            var updatedMode = mode
                            updatedMode.isEnabled = enabled
                            powerModeManager.updatePowerMode(updatedMode)
                        },
                        onDelete: {
                            powerModeManager.deletePowerMode(mode)
                        }
                    )
                }
            } header: {
                Text("Configured Modes (\(powerModeManager.powerModes.count))")
            }

            // Actions
            Section {
                Button(action: { showingCreateSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Custom Power Mode")
                    }
                }

                Button("Reset to Defaults") {
                    powerModeManager.resetToDefaults()
                }
                .foregroundColor(.orange)
            }

            // Statistics
            Section {
                LabeledContent("Total Uses", value: "\(powerModeManager.getTotalUseCount())")

                let mostUsed = powerModeManager.getMostUsedPowerModes(limit: 3)
                if !mostUsed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Most Used:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(mostUsed) { mode in
                            HStack {
                                Text(mode.emoji)
                                Text(mode.name)
                                    .font(.caption)
                                Spacer()
                                Text("\(mode.useCount) uses")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Statistics")
            }

            // Help
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("How Power Modes Work")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)

                    Text("• Power Modes automatically detect your active app or website")
                    Text("• When a match is found, EchoTune applies the mode's settings")
                    Text("• Settings include AI enhancement, transcription models, and auto-send behavior")
                    Text("• Create custom modes for your specific workflows")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingEditSheet) {
            if let mode = selectedMode {
                PowerModeEditSheet(mode: mode, isPresented: $showingEditSheet)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            PowerModeCreateSheet(isPresented: $showingCreateSheet)
        }
    }
}

struct PowerModeRow: View {
    let mode: PowerMode
    let isActive: Bool
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    @State private var isEnabled: Bool

    init(mode: PowerMode, isActive: Bool, onEdit: @escaping () -> Void, onToggle: @escaping (Bool) -> Void, onDelete: @escaping () -> Void) {
        self.mode = mode
        self.isActive = isActive
        self.onEdit = onEdit
        self.onToggle = onToggle
        self.onDelete = onDelete
        _isEnabled = State(initialValue: mode.isEnabled)
    }

    var body: some View {
        HStack {
            Text(mode.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mode.name)
                        .font(.body)
                        .fontWeight(isActive ? .semibold : .regular)

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // Show trigger info
                if !mode.appBundleIdentifiers.isEmpty {
                    Text("Apps: \(mode.appBundleIdentifiers.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !mode.websitePatterns.isEmpty {
                    Text("Websites: \(mode.websitePatterns.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Show settings preview
                HStack(spacing: 8) {
                    if mode.aiEnhancementEnabled {
                        Label("AI", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }

                    if mode.autoSendEnabled {
                        Label("Auto-send", systemImage: "paperplane.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    if mode.useCount > 0 {
                        Text("\(mode.useCount) uses")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { newValue in
                    onToggle(newValue)
                }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct PowerModeEditSheet: View {
    let mode: PowerMode
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Power Mode")
                .font(.title2)
                .fontWeight(.bold)

            Text("Coming soon: Full editing interface")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Close") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(30)
        .frame(width: 600, height: 500)
    }
}

struct PowerModeCreateSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Power Mode")
                .font(.title2)
                .fontWeight(.bold)

            Text("Coming soon: Custom Power Mode creation")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Close") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(30)
        .frame(width: 600, height: 500)
    }
}

#Preview {
    PowerModesView()
        .frame(width: 700, height: 800)
}
