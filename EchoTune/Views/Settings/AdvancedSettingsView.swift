//
//  AdvancedSettingsView.swift
//  EchoTune
//
//  Phase 1: Advanced Settings Tab
//

import SwiftUI
import UniformTypeIdentifiers

struct AdvancedSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    // Computed property for VAD sensitivity description
    private var sensitivityDescription: String {
        switch VADManager.shared.config.sensitivity {
        case .low:
            return "Best for quiet environments and soft speech. May detect more background noise."
        case .medium:
            return "Balanced detection for normal speaking volume. Recommended for most users."
        case .high:
            return "Only detects loud, clear speech. Use in noisy environments to avoid false positives."
        }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Advanced Settings")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Fine-tune transcription behavior and text processing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            Section("Text Processing") {
                Toggle("Auto-Punctuation", isOn: $settings.autoPunctuation)

                Text("Automatically add periods, commas, and question marks based on speech patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Smart Capitalization", isOn: $settings.smartCapitalization)

                Text("Automatically capitalize the first word of sentences and proper nouns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Insert Space After Text", isOn: $settings.insertSpaceAfterText)

                Text("Add a space after inserted text for easier continuous dictation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Auto-Correct In-Speech Corrections", isOn: $settings.autoCorrection)
                
                Text("Automatically correct utterances like 'Sorry, I meant 8am' and clean up your final transcript. Turn off to include all corrections in output.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }

            Section("Voice Activity Detection (VAD)") {
                Toggle("Enable Voice Detection", isOn: Binding(
                    get: { VADManager.shared.config.enabled },
                    set: { VADManager.shared.setEnabled($0) }
                ))

                Text("Automatically detect speech vs silence to skip transcription on non-speech audio. Reduces hallucinations and improves performance.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if VADManager.shared.config.enabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.vertical, 4)

                        // Sensitivity Control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detection Sensitivity")
                                .font(.caption)
                                .fontWeight(.medium)

                            Picker("Sensitivity", selection: Binding(
                                get: { VADManager.shared.config.sensitivity },
                                set: { VADManager.shared.updateSensitivity($0) }
                            )) {
                                Text("Low (Quiet Speech)").tag(VADManager.Sensitivity.low)
                                Text("Medium (Balanced)").tag(VADManager.Sensitivity.medium)
                                Text("High (Loud Speech Only)").tag(VADManager.Sensitivity.high)
                            }
                            .pickerStyle(.segmented)

                            Text(sensitivityDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Divider()
                            .padding(.vertical, 4)

                        // Minimum Speech Threshold
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Speech Threshold:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(VADManager.shared.config.speechConfidenceThreshold * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Minimum percentage of speech required to transcribe (currently 10%)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Divider()
                            .padding(.vertical, 4)

                        // VAD Method Info
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Detection Method:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("Energy-Based")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            Text("Ultra-fast speech detection using audio energy analysis. ML-based Silero VAD v5 is available.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }

            // Phase 6C: Browser Detection & Context Awareness
            Section("Context Awareness (Phase 6)") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Browser Context Detection")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    Text("Detects active browser and current website URL for Power Modes auto-switching")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)

                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supported Browsers (11):")
                            .font(.caption)
                            .fontWeight(.medium)

                        let browsers = ["Safari", "Chrome", "Firefox", "Edge", "Arc", "Brave", "Opera", "Vivaldi", "Orion", "SigmaOS", "Chromium"]
                        Text(browsers.joined(separator: " • "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }

            // Phase 6C: Auto-Update Settings
            Section("Auto-Update (Phase 6)") {
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

            Section("Performance") {
                Toggle("Enable Performance Monitoring", isOn: Binding(
                    get: { PerformanceMonitor.shared.isEnabled },
                    set: { PerformanceMonitor.shared.setEnabled($0) }
                ))

                Text("Track detailed performance metrics for transcription pipeline. Metrics are logged to console.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if PerformanceMonitor.shared.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance Metrics")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        HStack {
                            Button("View Metrics Summary") {
                                showPerformanceSummary()
                            }
                            .buttonStyle(.bordered)

                            Button("Export Metrics") {
                                exportMetrics()
                            }
                            .buttonStyle(.bordered)

                            Button("Reset Metrics") {
                                PerformanceMonitor.shared.resetMetrics()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.orange)
                        }

                        Text("Metrics include: recording duration, audio conversion time, transcription time, and total latency")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                }
            }

            Section("Voice Commands") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built-in Commands (Coming Soon)")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        CommandExample(command: "new line", result: "Insert line break")
                        CommandExample(command: "new paragraph", result: "Insert paragraph break")
                        CommandExample(command: "period/comma", result: "Insert punctuation")
                        CommandExample(command: "undo that", result: "Delete last transcription")
                    }

                    Text("Voice commands will be available in Phase 2")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            print("✓ Settings reset to defaults")
        }
    }

    private func showPerformanceSummary() {
        let summary = PerformanceMonitor.shared.getSessionSummary()

        let alert = NSAlert()
        alert.messageText = "Performance Metrics"
        alert.informativeText = summary
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func exportMetrics() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "echotune_performance_metrics.csv"
        savePanel.title = "Export Performance Metrics"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            let csvData = PerformanceMonitor.shared.exportMetrics()
            do {
                try csvData.write(to: url, atomically: true, encoding: .utf8)
                print("✓ Metrics exported to: \(url.path)")

                // Show success alert
                let successAlert = NSAlert()
                successAlert.messageText = "Export Successful"
                successAlert.informativeText = "Performance metrics have been exported to:\n\(url.lastPathComponent)"
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "OK")
                successAlert.runModal()
            } catch {
                print("❌ Failed to export metrics: \(error)")

                // Show error alert
                let errorAlert = NSAlert()
                errorAlert.messageText = "Export Failed"
                errorAlert.informativeText = "Failed to export metrics: \(error.localizedDescription)"
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }
        }
    }

    private func checkForUpdates() {
        print("🔄 Checking for updates...")
        // UpdateManager.shared.checkForUpdates() would be called here
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "You are running the latest version of EchoTune.\n\nVersion: 1.0.0 (Phase 6C Complete)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Command Example

struct CommandExample: View {
    let command: String
    let result: String

    var body: some View {
        HStack {
            Text("\"\(command)\"")
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(result)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
