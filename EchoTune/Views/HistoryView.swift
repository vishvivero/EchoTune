//
//  HistoryView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 27/10/2025.
//

import SwiftUI
import Combine

struct HistoryView: View {
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @State private var searchText = ""

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

                Text("\(historyManager.transcriptions.count) transcriptions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                            TranscriptionHistoryRow(item: item) {
                                historyManager.deleteTranscription(item)
                            }
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
        alert.informativeText = "This will delete all \(historyManager.transcriptions.count) transcriptions. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            historyManager.clearAll()
        }
    }
}

// MARK: - History Row

struct TranscriptionHistoryRow: View {
    let item: TranscriptionHistoryItem
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: "text.quote")
                    .foregroundColor(.blue)
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
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            if isHovering {
                HStack(spacing: 8) {
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

    private init() {
        loadHistory()
    }

    func addTranscription(_ text: String, duration: TimeInterval) {
        let item = TranscriptionHistoryItem(
            text: text,
            date: Date(),
            duration: duration
        )

        transcriptions.insert(item, at: 0) // Most recent first
        saveHistory()

        print("📝 Added to history: \(text.prefix(50))...")
    }

    func deleteTranscription(_ item: TranscriptionHistoryItem) {
        transcriptions.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearAll() {
        transcriptions = []
        saveHistory()
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
    let text: String
    let date: Date
    let duration: TimeInterval

    init(text: String, date: Date, duration: TimeInterval) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.duration = duration
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
}







