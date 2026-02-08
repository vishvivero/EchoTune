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
    @ObservedObject private var cleanupManager = AudioCleanupManager.shared
    @State private var showDeleteAllConfirmation = false
    @State private var showCleanupConfirmation = false
    @State private var cleanupResult: (deletedCount: Int, freedSpace: Int64)?

    private let retentionOptions = [1, 3, 7, 14, 30]

    var body: some View {
        Form {
            Section("Audio Recordings") {
                // Storage info
                let totalSize = TranscriptionHistoryManager.shared.totalAudioStorageSize()
                let fileCount = TranscriptionHistoryManager.shared.audioFileCount()

                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                    Text("Saved Recordings")
                    Spacer()
                    Text("\(fileCount) files · \(AudioCleanupManager.shared.formatFileSize(totalSize))")
                        .foregroundColor(.secondary)
                }

                Text("Audio recordings are saved alongside transcriptions so you can replay and re-transcribe them with different models.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }

            Section("Audio Cleanup") {
                Toggle("Automatic Cleanup", isOn: $settings.isAudioCleanupEnabled)

                Text("Automatically delete audio files older than the retention period. Transcription text is always kept.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if settings.isAudioCleanupEnabled {
                    HStack {
                        Text("Retention Period")
                        Spacer()
                        Picker("", selection: $settings.audioRetentionDays) {
                            ForEach(retentionOptions, id: \.self) { days in
                                Text("\(days) \(days == 1 ? "day" : "days")").tag(days)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }

                // Cleanup info
                let cleanupInfo = cleanupManager.getCleanupInfo()
                if cleanupInfo.fileCount > 0 {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("\(cleanupInfo.fileCount) files eligible for cleanup (\(cleanupManager.formatFileSize(cleanupInfo.totalSize)))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 12) {
                    Button("Run Cleanup Now") {
                        showCleanupConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(cleanupManager.isCleanupRunning)
                    .alert("Run Audio Cleanup?", isPresented: $showCleanupConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clean Up", role: .destructive) {
                            let result = cleanupManager.runManualCleanup()
                            cleanupResult = result
                            if result.deletedCount > 0 {
                                NotificationManager.shared.showNotification(
                                    title: "Audio Cleanup Complete",
                                    body: "Deleted \(result.deletedCount) files, freed \(cleanupManager.formatFileSize(result.freedSpace)).",
                                    sound: false
                                )
                            } else {
                                NotificationManager.shared.showNotification(
                                    title: "Nothing to Clean",
                                    body: "No audio files are older than \(settings.audioRetentionDays) days.",
                                    sound: false
                                )
                            }
                        }
                    } message: {
                        Text("This will delete audio files older than \(settings.audioRetentionDays) days. Transcription text will be kept. This cannot be undone.")
                    }

                    Button("Delete All Audio") {
                        showDeleteAllConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .disabled(cleanupManager.isCleanupRunning)
                    .alert("Delete All Audio Files?", isPresented: $showDeleteAllConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete All", role: .destructive) {
                            AudioPlayerManager.shared.stop()
                            let result = cleanupManager.deleteAllAudioFiles()
                            if result.deletedCount > 0 {
                                NotificationManager.shared.showNotification(
                                    title: "All Audio Deleted",
                                    body: "Deleted \(result.deletedCount) files, freed \(cleanupManager.formatFileSize(result.freedSpace)). Transcriptions are preserved.",
                                    sound: false
                                )
                            }
                        }
                    } message: {
                        Text("This will permanently delete ALL saved audio recordings. Transcription text will be kept. This cannot be undone.")
                    }
                }

                if let lastCleanup = cleanupManager.lastCleanupDate {
                    Text("Last cleanup: \(lastCleanupText(lastCleanup))")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

        }
        .formStyle(.grouped)
    }

    // MARK: - Helper Methods

    private func lastCleanupText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func clearTranscriptionHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear Transcription History?"
        alert.informativeText = "This will permanently delete all saved transcriptions and their audio files. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            AudioPlayerManager.shared.stop()
            TranscriptionHistoryManager.shared.clearAll()

            NotificationManager.shared.showNotification(
                title: "History Cleared",
                body: "All transcriptions and audio files have been deleted.",
                sound: false
            )
        }
    }
}
