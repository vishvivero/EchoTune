//
//  PowerModesViewContent.swift
//  EchoTune
//
//  Extracted content-only view for embedding inside other Forms.
//

import SwiftUI

struct PowerModesViewContent: View {
    @ObservedObject var powerModeManager = PowerModeManager.shared
    @State private var selectedMode: PowerMode?
    @State private var showingEditSheet = false
    @State private var showingCreateSheet = false

    var body: some View {
        Group {
            // Master Toggle
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

            if let currentMode = powerModeManager.currentPowerMode {
                Divider()

                HStack {
                    Text(currentMode.emoji)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentMode.name)
                            .fontWeight(.semibold)
                        Text("Currently Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }

            Divider()

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

            Button(action: { showingCreateSheet = true }) {
                Label("Create Custom Power Mode", systemImage: "plus.circle.fill")
            }

            Button("Reset to Defaults") {
                powerModeManager.resetToDefaults()
            }
            .foregroundColor(.orange)

            Divider()

            LabeledContent("Total Uses", value: "\(powerModeManager.getTotalUseCount())")
        }
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
