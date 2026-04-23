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
            // Header + Search
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("History")
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            Text("\(historyManager.transcriptions.count) transcriptions")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            let totalAudioSize = historyManager.totalAudioStorageSize()
                            if totalAudioSize > 0 {
                                Text("· \(AudioCleanupManager.shared.formatFileSize(totalAudioSize))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if !historyManager.transcriptions.isEmpty {
                        Button(role: .destructive, action: { clearAllHistory() }) {
                            Text("Clear All")
                                .font(.caption)
                        }
                    }
                }

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Search transcriptions…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

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

        AppCoordinator.shared.retranscribe(historyItem: item) { result in
            DispatchQueue.main.async {
                retranscribingItemId = nil
                if let result = result {
                    historyManager.updateTranscriptionDetails(
                        for: item,
                        newText: result.text,
                        rawTranscriptionText: result.rawTranscriptionText,
                        processingMetadata: result.processingMetadata
                    )
                }
            }
        }
    }
}
