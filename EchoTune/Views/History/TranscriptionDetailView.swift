//
//  TranscriptionDetailView.swift
//  EchoTune
//
//  Extracted from HistoryView.swift
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Detail View

struct TranscriptionDetailView: View {
    let item: TranscriptionHistoryItem
    let isRetranscribing: Bool
    let onDelete: () -> Void
    let onRetranscribe: () -> Void
    let onDeleteAudio: () -> Void
    let onUpdateText: (String) -> Void

    @ObservedObject private var audioPlayerManager = AudioPlayerManager.shared
    @State private var editableText: String
    @State private var isEditing = false

    init(item: TranscriptionHistoryItem, isRetranscribing: Bool, onDelete: @escaping () -> Void, onRetranscribe: @escaping () -> Void, onDeleteAudio: @escaping () -> Void, onUpdateText: @escaping (String) -> Void) {
        self.item = item
        self.isRetranscribing = isRetranscribing
        self.onDelete = onDelete
        self.onRetranscribe = onRetranscribe
        self.onDeleteAudio = onDeleteAudio
        self.onUpdateText = onUpdateText
        self._editableText = State(initialValue: item.text)
    }

    private var hasAudioFile: Bool {
        guard let path = item.audioFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private var audioFileSize: String? {
        guard let path = item.audioFilePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return AudioCleanupManager.shared.formatFileSize(size)
    }

    private var isCurrentlyPlaying: Bool {
        audioPlayerManager.currentlyPlayingId == item.id && audioPlayerManager.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Waveform player
            if hasAudioFile, let audioPath = item.audioFilePath {
                VStack(spacing: 8) {
                    WaveformView(
                        audioFilePath: audioPath,
                        progress: audioPlayerManager.currentlyPlayingId == item.id ? audioPlayerManager.playbackProgress : 0,
                        duration: audioPlayerManager.currentlyPlayingId == item.id ? audioPlayerManager.duration : item.duration,
                        onSeek: { time in
                            if audioPlayerManager.currentlyPlayingId == item.id {
                                audioPlayerManager.seek(to: time)
                            } else {
                                audioPlayerManager.play(filePath: audioPath, itemId: item.id)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    audioPlayerManager.seek(to: time)
                                }
                            }
                        }
                    )
                    .frame(height: 60)
                    .padding(.horizontal, 4)

                    // Time display
                    HStack {
                        Text(audioPlayerManager.currentlyPlayingId == item.id ? audioPlayerManager.currentTimeFormatted : "0:00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Text(audioPlayerManager.currentlyPlayingId == item.id ? audioPlayerManager.durationFormatted : Self.formatTime(item.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
            }

            // Transcription text
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Transcription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    if isEditing {
                        Button("Save") {
                            onUpdateText(editableText)
                            isEditing = false
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }

                    Button(isEditing ? "Cancel" : "Edit") {
                        if isEditing {
                            editableText = item.text
                        }
                        isEditing.toggle()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }

                if isEditing {
                    TextEditor(text: $editableText)
                        .font(.body)
                        .frame(minHeight: 80, maxHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                } else {
                    ScrollView {
                        Text(item.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 40, maxHeight: 160)
                }
            }

            if let originalText = item.originalText, originalText != item.text {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    ScrollView {
                        Text(originalText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 40, maxHeight: 120)
                }
            }

            // Metadata
            HStack(spacing: 16) {
                Label(item.formattedDate, systemImage: "calendar")
                Label(String(format: "%.1fs", item.duration), systemImage: "timer")
                Label("\(item.wordCount) words", systemImage: "textformat")
                if let detectedLanguage = item.detectedLanguage {
                    Label(languageName(for: detectedLanguage), systemImage: "globe")
                }
                if item.translatedText != nil {
                    Label("English Output", systemImage: "character.bubble")
                }
                if let size = audioFileSize {
                    Label(size, systemImage: "waveform")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                if hasAudioFile {
                    Button(action: {
                        if let path = item.audioFilePath {
                            audioPlayerManager.togglePlayback(filePath: path, itemId: item.id)
                        }
                    }) {
                        Label(isCurrentlyPlaying ? "Pause" : "Play", systemImage: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                if hasAudioFile {
                    if isRetranscribing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Transcribing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: onRetranscribe) {
                            Label("Re-transcribe", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                    }
                }

                Button(action: copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Button(action: exportTranscription) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.green)

                Spacer()

                if hasAudioFile {
                    Button(action: onDeleteAudio) {
                        Label("Delete Audio", systemImage: "waveform.badge.minus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                }

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .onChange(of: item.text) { newValue in
            if !isEditing {
                editableText = newValue
            }
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }

    private func exportTranscription() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "transcription-\(item.id.uuidString.prefix(8)).txt"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? item.text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func languageName(for code: String) -> String {
        LanguageManager.shared.language(for: code)?.name ?? code.uppercased()
    }
}
