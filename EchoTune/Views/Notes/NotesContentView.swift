//
//  NotesContentView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//

import SwiftUI

struct NotesContentView: View {
    @ObservedObject var notesManager = NotesManager.shared
    @State private var selectedNote: Note? = nil
    @State private var searchText = ""
    @State private var aiBusy = false
    @State private var aiError: String? = nil

    // MARK: - AI Note Actions

    private enum NoteAIAction {
        case summarize, todo, cleanup, keyPoints, professional

        var prompt: String {
            switch self {
            case .summarize:
                return "Summarize the following note content into a tight paragraph (max 5 sentences). Reply with ONLY the summary.\n\nContent:\n"
            case .todo:
                return "Extract an actionable to-do list from the following note. Output ONLY the list as lines starting with '- [ ] '. Each item short and action-first. If there are no actionable items, output the 3 most important points as '- [ ]' items.\n\nContent:\n"
            case .cleanup:
                return "Clean up the following dictated note: fix grammar, remove filler words and repetitions, keep the structure and meaning. Reply with ONLY the cleaned note.\n\nContent:\n"
            case .keyPoints:
                return "Condense the following note into key points as bullet lines starting with '- '. Reply with ONLY the bullets.\n\nContent:\n"
            case .professional:
                return "Rewrite the following note in a professional, well-structured form. Reply with ONLY the rewrite.\n\nContent:\n"
            }
        }
    }

    private func runAI(action: NoteAIAction, note: Note) {
        let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !aiBusy else { return }

        // Use the user's selected enhancement model — hosted free path works
        // with no key, so the menu is functional out of the box.
        let modelString = AppSettings.shared.selectedEnhancementModel
        guard let model = AIEnhancementEngine.EnhancementModel(rawValue: modelString) else {
            aiError = "No enhancement model configured."
            return
        }
        let apiKey = AppSettings.shared.apiKey(for: model.provider)

        aiBusy = true
        aiError = nil

        Task {
            do {
                let result = try await AIEnhancementEngine.shared.enhance(
                    content,
                    using: model,
                    apiKey: apiKey,
                    customPrompt: action.prompt
                )

                await MainActor.run {
                    aiBusy = false
                    var updated = note
                    updated.content = result
                    updated.dateModified = Date()
                    notesManager.updateNote(updated)
                    selectedNote = updated
                }
            } catch {
                await MainActor.run {
                    aiBusy = false
                    aiError = model.provider == .hosted
                        ? "AI request failed: \(error.localizedDescription)"
                        : "AI failed (\(model.provider.displayName)): \(error.localizedDescription). Add a key in Settings > Intelligence, or switch to EchoTune Hosted (free)."
                }
            }
        }
    }
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notesManager.notes
        } else {
            return notesManager.searchNotes(query: searchText)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar List of Notes
            VStack(alignment: .leading, spacing: 0) {
                // Header & Add Note Button
                HStack {
                    Text("My Notes")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        let newNote = notesManager.createNote(title: "New Note", content: "")
                        selectedNote = newNote
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                    .help("Create New Note")
                }
                .padding()
                
                // Search field
                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                
                Divider()
                
                // List
                if filteredNotes.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No notes created" : "No matches found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(filteredNotes) { note in
                            Button(action: { selectedNote = note }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            if note.isFavorite {
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(.yellow)
                                                    .font(.caption)
                                            }
                                            Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        }
                                        
                                        Text(note.content.isEmpty ? "No content" : note.content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(selectedNote?.id == note.id ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(width: 240)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Detail pane
            VStack {
                if var note = selectedNote {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title / Actions bar
                        HStack {
                            TextField("Note Title", text: Binding(
                                get: { note.title },
                                set: {
                                    note.title = $0
                                    note.dateModified = Date()
                                    notesManager.updateNote(note)
                                    selectedNote = note
                                }
                            ))
                            .font(.title2)
                            .fontWeight(.bold)
                            .textFieldStyle(.plain)
                            
                            Spacer()
                            
                            // Favorite toggle
                            Button(action: {
                                notesManager.toggleFavorite(note)
                                note.isFavorite.toggle()
                                selectedNote = note
                            }) {
                                Image(systemName: note.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(note.isFavorite ? .yellow : .secondary)
                            }
                            .buttonStyle(.bordered)
                            .help("Toggle Favorite")

                            // AI actions
                            Menu {
                                Button("Summarize") { runAI(action: .summarize, note: note) }
                                Button("To-Do List") { runAI(action: .todo, note: note) }
                                Button("Clean Up Dictation") { runAI(action: .cleanup, note: note) }
                                Button("Key Points") { runAI(action: .keyPoints, note: note) }
                                Button("Make Professional") { runAI(action: .professional, note: note) }
                            } label: {
                                if aiBusy {
                                    ProgressView().scaleEffect(0.55)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                            }
                            .disabled(aiBusy || note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help("AI assist: summarize, extract todos, clean up")

                            // AI actions menu
                            Menu {
                                Button("Summarize") { runAI(action: .summarize, note: note) }
                                Button("Extract To-Do List") { runAI(action: .todo, note: note) }
                                Button("Clean Up & Format") { runAI(action: .cleanup, note: note) }
                                Button("Key Points Bullets") { runAI(action: .keyPoints, note: note) }
                                Divider()
                                Button("Rewrite Professionally") { runAI(action: .professional, note: note) }
                            } label: {
                                Label("AI", systemImage: "sparkles")
                            }
                            .disabled(aiBusy || note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help("AI helper — uses your selected enhancement model (hosted free available)")

                            if aiBusy {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }

                            // Delete button
                            Button(action: {
                                notesManager.deleteNote(note)
                                selectedNote = nil
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.bordered)
                            .help("Delete Note")
                        }
                        .padding(20)

                        if let err = aiError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Dismiss") { aiError = nil }
                                    .buttonStyle(.link)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 6)
                        }
                        
                        Divider()
                        
                        // Text Editor
                        TextEditor(text: Binding(
                            get: { note.content },
                            set: {
                                note.content = $0
                                note.dateModified = Date()
                                notesManager.updateNote(note)
                                selectedNote = note
                            }
                        ))
                        .font(.body)
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Note Selected")
                            .font(.headline)
                        Text("Select a note from the sidebar or create a new one.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .onAppear {
            if selectedNote == nil, let first = notesManager.notes.first {
                selectedNote = first
            }
        }
    }
}
