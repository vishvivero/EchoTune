//
//  HistoryView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 27/10/2025.
//

import SwiftUI
import AppKit

// MARK: - History View

struct HistoryView: View {
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @StateObject private var audioPlayerManager = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var retranscribingItemId: UUID?
    @State private var expandedItemId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("History")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    if !historyManager.transcriptions.isEmpty {
                        Button("Clear All") {
                            clearAllHistory()
                        }
                        .foregroundColor(.red)
                    }
                }

                HStack(spacing: 16) {
                    Text("\(historyManager.transcriptions.count) transcriptions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    let totalAudioSize = historyManager.totalAudioStorageSize()
                    if totalAudioSize > 0 {
                        Text("Audio: \(AudioCleanupManager.shared.formatFileSize(totalAudioSize))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            // Transcription List
            if filteredTranscriptions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text(historyManager.transcriptions.isEmpty ? "No transcriptions yet" : "No matches found")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    if historyManager.transcriptions.isEmpty {
                        Text("Start recording to see your transcription history")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTranscriptions) { item in
                            TranscriptionHistoryRow(
                                item: item,
                                isRetranscribing: retranscribingItemId == item.id,
                                isExpanded: expandedItemId == item.id,
                                onToggleExpand: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        if expandedItemId == item.id {
                                            expandedItemId = nil
                                        } else {
                                            expandedItemId = item.id
                                        }
                                    }
                                },
                                onDelete: {
                                    if expandedItemId == item.id {
                                        expandedItemId = nil
                                    }
                                    historyManager.deleteTranscription(item)
                                },
                                onRetranscribe: {
                                    retranscribeItem(item)
                                },
                                onDeleteAudio: {
                                    historyManager.deleteAudioFile(for: item)
                                },
                                onUpdateText: { newText in
                                    historyManager.updateTranscriptionText(for: item, newText: newText)
                                }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var filteredTranscriptions: [TranscriptionHistoryItem] {
        if searchText.isEmpty {
            return historyManager.transcriptions
        }
        return historyManager.transcriptions.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func clearAllHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will delete all \(historyManager.transcriptions.count) transcriptions and their audio files. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            audioPlayerManager.stop()
            historyManager.clearAll()
        }
    }

    private func retranscribeItem(_ item: TranscriptionHistoryItem) {
        guard let audioPath = item.audioFilePath,
              FileManager.default.fileExists(atPath: audioPath) else {
            NotificationManager.shared.showNotification(
                title: "Audio Not Available",
                body: "The audio file for this transcription is no longer available.",
                sound: false
            )
            return
        }

        retranscribingItemId = item.id

        AppCoordinator.shared.retranscribe(historyItem: item) { newText in
            DispatchQueue.main.async {
                retranscribingItemId = nil
                if let newText = newText {
                    historyManager.updateTranscriptionText(for: item, newText: newText)
                }
            }
        }
    }
}
