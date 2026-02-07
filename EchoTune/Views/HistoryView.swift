//
//  HistoryView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 27/10/2025.
//

import SwiftUI
import Combine
import AVFoundation

struct HistoryView: View {
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @StateObject private var audioPlayerManager = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var retranscribingItemId: UUID?

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
                                onDelete: {
                                    historyManager.deleteTranscription(item)
                                },
                                onRetranscribe: {
                                    retranscribeItem(item)
                                },
                                onDeleteAudio: {
                                    historyManager.deleteAudioFile(for: item)
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

// MARK: - Audio Player Manager

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()

    @Published var isPlaying = false
    @Published var currentlyPlayingId: UUID?
    @Published var playbackProgress: Double = 0.0

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    private init() {}

    func play(filePath: String, itemId: UUID) {
        // Stop any current playback
        stop()

        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ Audio file not found: \(filePath)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            currentlyPlayingId = itemId
            playbackProgress = 0.0

            // Start progress timer
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                if player.isPlaying {
                    self.playbackProgress = player.currentTime / player.duration
                } else {
                    self.stop()
                }
            }

            print("▶️ Playing audio: \(filePath)")
        } catch {
            print("❌ Failed to play audio: \(error.localizedDescription)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentlyPlayingId = nil
        playbackProgress = 0.0
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func togglePlayback(filePath: String, itemId: UUID) {
        if currentlyPlayingId == itemId && isPlaying {
            stop()
        } else {
            play(filePath: filePath, itemId: itemId)
        }
    }
}

// MARK: - History Row

struct TranscriptionHistoryRow: View {
    let item: TranscriptionHistoryItem
    let isRetranscribing: Bool
    let onDelete: () -> Void
    let onRetranscribe: () -> Void
    let onDeleteAudio: () -> Void

    @StateObject private var audioPlayerManager = AudioPlayerManager.shared
    @State private var isHovering = false

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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Icon / Play button
                ZStack {
                    Circle()
                        .fill(hasAudioFile ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)

                    if hasAudioFile {
                        Button(action: {
                            if let path = item.audioFilePath {
                                audioPlayerManager.togglePlayback(filePath: path, itemId: item.id)
                            }
                        }) {
                            Image(systemName: isCurrentlyPlaying ? "stop.fill" : "play.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help(isCurrentlyPlaying ? "Stop playback" : "Play recording")
                    } else {
                        Image(systemName: "text.quote")
                            .foregroundColor(.blue)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.body)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label(item.formattedDate, systemImage: "calendar")
                        Label("\(item.wordCount) words", systemImage: "textformat")
                        Label(String(format: "%.1fs", item.duration), systemImage: "timer")

                        if let size = audioFileSize {
                            Label(size, systemImage: "waveform")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Actions
                if isRetranscribing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                } else if isHovering {
                    HStack(spacing: 8) {
                        if hasAudioFile {
                            Button(action: onRetranscribe) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Re-transcribe with current model")

                            Button(action: onDeleteAudio) {
                                Image(systemName: "waveform.badge.minus")
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Delete audio file (keep transcript)")
                        }

                        Button(action: copyToClipboard) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
            }
            .padding(16)

            // Playback progress bar
            if isCurrentlyPlaying {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.1))
                            .frame(height: 3)

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * audioPlayerManager.playbackProgress, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }
}

// MARK: - History Manager

class TranscriptionHistoryManager: ObservableObject {
    static let shared = TranscriptionHistoryManager()

    @Published var transcriptions: [TranscriptionHistoryItem] = []

    private let userDefaults = UserDefaults.standard
    private let historyKey = "transcriptionHistory"

    /// Persistent recordings directory
    static var recordingsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recordingsDir = appSupport.appendingPathComponent("EchoTune/Recordings", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        return recordingsDir
    }

    /// Last transcription item (for quick access / paste last)
    var lastTranscription: TranscriptionHistoryItem? {
        transcriptions.first
    }

    private init() {
        loadHistory()
        ensureRecordingsDirectory()
    }

    private func ensureRecordingsDirectory() {
        let dir = TranscriptionHistoryManager.recordingsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                print("📁 Created recordings directory: \(dir.path)")
            } catch {
                print("❌ Failed to create recordings directory: \(error)")
            }
        }
    }

    func addTranscription(_ text: String, duration: TimeInterval, audioFilePath: String? = nil) {
        let item = TranscriptionHistoryItem(
            text: text,
            date: Date(),
            duration: duration,
            audioFilePath: audioFilePath
        )

        transcriptions.insert(item, at: 0) // Most recent first
        saveHistory()

        print("📝 Added to history: \(text.prefix(50))... (audio: \(audioFilePath != nil ? "yes" : "no"))")
    }

    func updateTranscriptionText(for item: TranscriptionHistoryItem, newText: String) {
        if let index = transcriptions.firstIndex(where: { $0.id == item.id }) {
            transcriptions[index] = TranscriptionHistoryItem(
                id: item.id,
                text: newText,
                date: item.date,
                duration: item.duration,
                audioFilePath: item.audioFilePath
            )
            saveHistory()
            print("📝 Updated transcription text for \(item.id)")
        }
    }

    func deleteTranscription(_ item: TranscriptionHistoryItem) {
        // Delete associated audio file if it exists
        if let audioPath = item.audioFilePath {
            try? FileManager.default.removeItem(atPath: audioPath)
            print("🗑️ Deleted audio file: \(audioPath)")
        }

        transcriptions.removeAll { $0.id == item.id }
        saveHistory()
    }

    func deleteAudioFile(for item: TranscriptionHistoryItem) {
        guard let audioPath = item.audioFilePath else { return }

        // Stop playback if this file is playing
        if AudioPlayerManager.shared.currentlyPlayingId == item.id {
            AudioPlayerManager.shared.stop()
        }

        try? FileManager.default.removeItem(atPath: audioPath)
        print("🗑️ Deleted audio file: \(audioPath)")

        // Update the item to remove audio path
        if let index = transcriptions.firstIndex(where: { $0.id == item.id }) {
            transcriptions[index] = TranscriptionHistoryItem(
                id: item.id,
                text: item.text,
                date: item.date,
                duration: item.duration,
                audioFilePath: nil
            )
            saveHistory()
        }
    }

    func clearAll() {
        // Delete all audio files
        for item in transcriptions {
            if let audioPath = item.audioFilePath {
                try? FileManager.default.removeItem(atPath: audioPath)
            }
        }

        transcriptions = []
        saveHistory()
    }

    /// Save audio data to the persistent recordings directory
    func saveAudioFile(data: Data, id: UUID) -> String? {
        let fileName = "\(id.uuidString).caf"
        let fileURL = TranscriptionHistoryManager.recordingsDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            print("💾 Saved audio file: \(fileURL.path) (\(data.count) bytes)")
            return fileURL.path
        } catch {
            print("❌ Failed to save audio file: \(error)")
            return nil
        }
    }

    /// Copy a temp audio file to the persistent recordings directory
    func copyAudioFile(from sourcePath: String, id: UUID) -> String? {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let fileName = "\(id.uuidString).caf"
        let destURL = TranscriptionHistoryManager.recordingsDirectory.appendingPathComponent(fileName)

        do {
            // Remove destination if it already exists
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            print("💾 Copied audio file: \(destURL.path)")
            return destURL.path
        } catch {
            print("❌ Failed to copy audio file: \(error)")
            return nil
        }
    }

    /// Calculate total storage used by audio files
    func totalAudioStorageSize() -> Int64 {
        var totalSize: Int64 = 0
        for item in transcriptions {
            if let path = item.audioFilePath,
               let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }

    /// Count of transcriptions that have audio files
    func audioFileCount() -> Int {
        return transcriptions.filter { item in
            guard let path = item.audioFilePath else { return false }
            return FileManager.default.fileExists(atPath: path)
        }.count
    }

    /// Remove audio path reference from a transcription item (keeps transcript, removes audio link)
    func clearAudioPath(for itemId: UUID) {
        if let index = transcriptions.firstIndex(where: { $0.id == itemId }) {
            let item = transcriptions[index]
            transcriptions[index] = TranscriptionHistoryItem(
                id: item.id,
                text: item.text,
                date: item.date,
                duration: item.duration,
                audioFilePath: nil
            )
            saveHistory()
        }
    }

    private func loadHistory() {
        if let data = userDefaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([TranscriptionHistoryItem].self, from: data) {
            transcriptions = decoded
            print("📚 Loaded \(transcriptions.count) transcriptions from history")
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(transcriptions) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }
}

// MARK: - History Item Model

struct TranscriptionHistoryItem: Identifiable, Codable {
    let id: UUID
    var text: String
    let date: Date
    let duration: TimeInterval
    var audioFilePath: String?

    init(text: String, date: Date, duration: TimeInterval, audioFilePath: String? = nil) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.duration = duration
        self.audioFilePath = audioFilePath
    }

    init(id: UUID, text: String, date: Date, duration: TimeInterval, audioFilePath: String? = nil) {
        self.id = id
        self.text = text
        self.date = date
        self.duration = duration
        self.audioFilePath = audioFilePath
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var hasAudioFile: Bool {
        guard let path = audioFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}
