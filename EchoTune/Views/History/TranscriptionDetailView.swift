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
    @ObservedObject private var settings = AppSettings.shared
    @State private var editableText: String
    @State private var isEditing = false
    @State private var selectedFeedback: TranscriptionQualityFeedback?

    private let historyManager = TranscriptionHistoryManager.shared

    init(item: TranscriptionHistoryItem, isRetranscribing: Bool, onDelete: @escaping () -> Void, onRetranscribe: @escaping () -> Void, onDeleteAudio: @escaping () -> Void, onUpdateText: @escaping (String) -> Void) {
        self.item = item
        self.isRetranscribing = isRetranscribing
        self.onDelete = onDelete
        self.onRetranscribe = onRetranscribe
        self.onDeleteAudio = onDeleteAudio
        self.onUpdateText = onUpdateText
        self._editableText = State(initialValue: item.text)
        self._selectedFeedback = State(initialValue: item.processingMetadata?.qualityFeedback)
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
                    Text(item.rawTranscriptionText != nil && item.rawTranscriptionText != item.text ? "Inserted / Enhanced Text" : "Transcription")
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

            if let rawTranscriptionText = item.rawTranscriptionText,
               rawTranscriptionText != item.text {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Raw Transcript")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    ScrollView {
                        Text(rawTranscriptionText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 40, maxHeight: 120)
                }
            }

            if let originalText = item.originalText,
               originalText != item.text,
               originalText != item.rawTranscriptionText {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.translatedText != nil ? "Original Spoken Text" : "Original")
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

            if settings.showTranscriptionDiagnostics, let metadata = item.processingMetadata {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Diagnostics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: 8) {
                        if let provider = metadata.transcriptionProvider {
                            MetadataGridRow(label: "Transcribed with", value: provider)
                        }
                        if let model = metadata.transcriptionModel {
                            MetadataGridRow(label: "Model", value: model)
                        }
                        if let enhancementProvider = metadata.enhancementProvider {
                            MetadataGridRow(label: "Enhanced with", value: enhancementProvider)
                        }
                        if let enhancementModel = metadata.enhancementModel {
                            MetadataGridRow(label: "Enhancement model", value: enhancementModel)
                        }
                        if let recordingDuration = metadata.recordingDuration {
                            MetadataGridRow(label: "Recording duration", value: String(format: "%.2fs", recordingDuration))
                        }
                        if let transcriptionLatency = metadata.transcriptionLatency {
                            MetadataGridRow(label: "Transcription latency", value: String(format: "%.2fs", transcriptionLatency))
                        }
                        if let enhancementLatency = metadata.enhancementLatency {
                            MetadataGridRow(label: "Enhancement latency", value: String(format: "%.2fs", enhancementLatency))
                        }
                        if let textInsertionLatency = metadata.textInsertionLatency {
                            MetadataGridRow(label: "Insertion latency", value: String(format: "%.2fs", textInsertionLatency))
                        }
                        if let totalLatency = metadata.totalLatency {
                            MetadataGridRow(label: "Total latency", value: String(format: "%.2fs", totalLatency))
                        }
                        if let audioByteCount = metadata.audioByteCount {
                            MetadataGridRow(label: "Audio size", value: ByteCountFormatter.string(fromByteCount: Int64(audioByteCount), countStyle: .file))
                        }
                        MetadataGridRow(label: "Fallback used", value: metadata.usedFallback ? (metadata.fallbackReason.map { "Yes — \($0)" } ?? "Yes") : "No")
                        MetadataGridRow(label: "Edited after insert", value: metadata.userEdited ? "Yes" : "No")
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                    .cornerRadius(10)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Quality Feedback")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    ForEach(TranscriptionQualityFeedback.allCases) { feedback in
                        Button {
                            let newValue: TranscriptionQualityFeedback? = selectedFeedback == feedback ? nil : feedback
                            selectedFeedback = newValue
                            historyManager.updateQualityFeedback(for: item, feedback: newValue)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: feedback.iconName)
                                    .font(.caption)
                                Text(feedback.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(selectedFeedback == feedback ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12)))
                            .foregroundColor(selectedFeedback == feedback ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Useful when comparing Groq-only output against Groq + enhancement over time.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
        .onChange(of: item.processingMetadata?.qualityFeedback) { newValue in
            selectedFeedback = newValue
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

private struct MetadataGridRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }
}
