//
//  PrivacySettingsView.swift
//  EchoTune
//
//  Phase 1: Privacy Settings Tab
//

import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Settings")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Control how EchoTune handles your data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            Section("Data Privacy") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title)
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% Local Processing")
                                .font(.headline)

                            Text("All transcription happens on your device. No audio or text data is ever sent to external servers.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)

                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cloud-Based Models")
                                .font(.headline)

                            Text("If you use cloud-based AI models, audio data is sent to the model provider for processing. However, EchoTune does not store or retain any of your data.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Section("Audio History") {
                Toggle("Save Audio Recordings", isOn: $settings.keepAudioHistory)

                Text("Keep a local history of your audio recordings for review. Recordings are stored securely on your device and can be deleted at any time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if settings.keepAudioHistory {
                    Button("Clear Audio History") {
                        // TODO: Phase 2 - Implement clear history
                        print("Clear audio history")
                    }
                    .buttonStyle(.bordered)
                    .padding(.leading, 20)
                }
            }

            Section("Usage Analytics") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local Analytics Only")
                                .font(.headline)

                            Text("Usage statistics are calculated locally on your device and never shared with third parties.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

