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
                        clearAudioHistory()
                    }
                    .buttonStyle(.bordered)
                    .padding(.leading, 20)
                }
            }

            Section("Transcription History") {
                let historyCount = TranscriptionHistoryManager.shared.transcriptions.count

                HStack {
                    Text("Saved Transcriptions")
                    Spacer()
                    Text("\(historyCount) items")
                        .foregroundColor(.secondary)
                }

                if historyCount > 0 {
                    Button("Clear All Transcription History") {
                        clearTranscriptionHistory()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
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

    // MARK: - Helper Methods

    private func clearAudioHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear Audio History?"
        alert.informativeText = "This will permanently delete all saved audio recordings. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Clear audio recordings from temp directory
            let tempDir = FileManager.default.temporaryDirectory
            do {
                let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                let audioFiles = files.filter { $0.pathExtension == "caf" || $0.pathExtension == "wav" || $0.pathExtension == "m4a" }
                for file in audioFiles {
                    try FileManager.default.removeItem(at: file)
                }
                print("✅ Cleared \(audioFiles.count) audio files")

                NotificationManager.shared.showNotification(
                    title: "Audio History Cleared",
                    body: "All audio recordings have been deleted.",
                    sound: false
                )
            } catch {
                print("❌ Failed to clear audio history: \(error)")
            }
        }
    }

    private func clearTranscriptionHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear Transcription History?"
        alert.informativeText = "This will permanently delete all saved transcriptions. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            TranscriptionHistoryManager.shared.clearAll()

            NotificationManager.shared.showNotification(
                title: "History Cleared",
                body: "All transcriptions have been deleted.",
                sound: false
            )
        }
    }
}

