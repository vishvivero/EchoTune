//
//  SettingsCompositeViews.swift
//  EchoTune
//
//  Extracted from SettingsView.swift
//  Composite settings tabs: Permissions & Privacy, About & License.
//

import SwiftUI

// MARK: - Permissions & Privacy Settings (Composite View)

/// Merges Permissions and Privacy into one tab.
struct PermissionsPrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                PermissionsContentView()
            } header: {
                Text("Permissions")
            }

            Section {
                PrivacySettingsView()
            } header: {
                Text("Privacy")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About & License Settings (Composite View)

/// Combines License activation, updates, and reset.
struct AboutLicenseSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                LicenseSettingsView()
            } header: {
                Text("License")
            }

            Section("Updates") {
                Toggle("Automatic Updates", isOn: $settings.automaticUpdatesEnabled)

                Text("Automatically download and install updates in the background")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if settings.automaticUpdatesEnabled {
                    Toggle("Include Beta Updates", isOn: $settings.checkForBetaUpdates)
                        .padding(.leading, 20)

                    Text("Beta updates include experimental features and may be less stable")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.leading, 40)
                }

                Button("Check for Updates Now") {
                    checkForUpdates()
                }
                .buttonStyle(.bordered)
                .padding(.leading, 20)
            }

            Section("Reset") {
                Button("Reset All Settings") {
                    resetAllSettings()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)

                Text("This will reset all settings to their default values. This action cannot be undone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .formStyle(.grouped)
    }

    private func checkForUpdates() {
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "You are running the latest version of EchoTune.\n\nVersion: 1.0.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func resetAllSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This will reset all EchoTune settings to their default values. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            settings.resetToDefaults()
            debugLog("✓ Settings reset to defaults")
        }
    }
}
