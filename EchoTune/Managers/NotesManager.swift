//
//  NotesManager.swift
//  EchoTune
//
//  Manages structured notes with AI-assisted formatting
//

import Foundation
import Combine

class NotesManager: ObservableObject {
    static let shared = NotesManager()

    @Published var notes: [Note] = []

    private let notesKey = "savedNotes"

    private init() {
        loadNotes()
    }

    // MARK: - CRUD Operations

    func createNote(title: String = "New Note", content: String = "") -> Note {
        let note = Note(title: title, content: content)
        notes.insert(note, at: 0) // Add to beginning
        saveNotes()
        return note
    }

    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updatedNote = note
            updatedNote.dateModified = Date()
            notes[index] = updatedNote
            saveNotes()
        }
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }

    func toggleFavorite(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isFavorite.toggle()
            saveNotes()
        }
    }

    // MARK: - Smart Note Creation from Voice

    func createNoteFromTranscription(_ text: String) -> Note {
        // Parse the transcription to create structured note
        let items = parseTextToItems(text)

        // Extract title from first line or first few words
        let title = extractTitle(from: text)

        let note = Note(
            title: title,
            content: text,
            items: items
        )

        notes.insert(note, at: 0)
        saveNotes()
        return note
    }

    private func extractTitle(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let firstLine = lines.first ?? ""

        // Use first line if it's short, otherwise use first few words
        if firstLine.count < 50 {
            return firstLine.isEmpty ? "Untitled Note" : firstLine
        } else {
            let words = firstLine.components(separatedBy: .whitespaces).prefix(5)
            return words.joined(separator: " ") + "..."
        }
    }

    private func parseTextToItems(_ text: String) -> [NoteItem] {
        var items: [NoteItem] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Detect item type based on content
            if trimmed.lowercased().hasPrefix("todo:") || trimmed.lowercased().hasPrefix("task:") {
                let text = trimmed.replacingOccurrences(of: "(?i)^(todo|task):\\s*", with: "", options: .regularExpression)
                items.append(NoteItem(text: text, type: .checkbox))
            } else if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                items.append(NoteItem(text: text, type: .bullet))
            } else if let firstChar = trimmed.first, firstChar.isNumber {
                // Numbered item
                let text = trimmed.replacingOccurrences(of: "^\\d+\\.?\\s*", with: "", options: .regularExpression)
                items.append(NoteItem(text: text, type: .numbered))
            } else {
                // Regular bullet point
                items.append(NoteItem(text: trimmed, type: .bullet))
            }
        }

        return items
    }

    // MARK: - Search and Filter

    func searchNotes(query: String) -> [Note] {
        guard !query.isEmpty else { return notes }

        let lowercasedQuery = query.lowercased()
        return notes.filter { note in
            note.title.lowercased().contains(lowercasedQuery) ||
            note.content.lowercased().contains(lowercasedQuery) ||
            note.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    var favoriteNotes: [Note] {
        notes.filter { $0.isFavorite }
    }

    // MARK: - Persistence

    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: notesKey)
        }
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded
        }
    }
}
