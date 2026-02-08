//
//  AdvancedSettingsView.swift
//  EchoTune
//
//  Phase 1: Advanced Settings Tab
//

import SwiftUI

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

        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// CommandExample struct removed — voice commands section was cut

