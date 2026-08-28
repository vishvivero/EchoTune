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
