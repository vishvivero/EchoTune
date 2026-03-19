//
//  NotesFullView.swift
//  EchoTune
//
//  Full notes implementation (disabled - for future use).
//

import SwiftUI

// MARK: - Full Notes Implementation (Disabled - for future use)

struct NotesContentView_Full: View {
    @ObservedObject private var notesManager = NotesManager.shared
    @State private var selectedNote: Note?
    @State private var searchText = ""
    @State private var showingNewNoteSheet = false

    var filteredNotes: [Note] {
        searchText.isEmpty ? notesManager.notes : notesManager.searchNotes(query: searchText)
    }

    var body: some View {
        HSplitView {
            // Sidebar - Notes List
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(notesManager.notes.count) notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // New Note Button
                Button(action: {
                    showingNewNoteSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Note")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Divider()

                // Notes List
                if filteredNotes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text(searchText.isEmpty ? "No notes yet" : "No matching notes")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if searchText.isEmpty {
                            Text("Create your first note using voice dictation")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredNotes) { note in
                                NoteRowView(
                                    note: note,
                                    isSelected: selectedNote?.id == note.id,
                                    onSelect: {
                                        selectedNote = note
                                    },
                                    onToggleFavorite: {
                                        notesManager.toggleFavorite(note)
                                    }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .frame(minWidth: 250, idealWidth: 300)

            // Detail - Note Editor
            if let note = selectedNote {
                NoteDetailView(note: Binding(
                    get: { note },
                    set: { updatedNote in
                        selectedNote = updatedNote
                        notesManager.updateNote(updatedNote)
                    }
                ))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Select a note or create a new one")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Button("Create Note") {
                        showingNewNoteSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingNewNoteSheet) {
            NewNoteSheet(
                isPresented: $showingNewNoteSheet,
                onCreate: { note in
                    selectedNote = note
                }
            )
        }
    }
}

// MARK: - Note Row

struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: onToggleFavorite) {
                        Image(systemName: note.isFavorite ? "star.fill" : "star")
                            .foregroundColor(note.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(note.dateModified, style: .relative)
                        .font(.caption2)

                    if !note.items.isEmpty {
                        Spacer()
                        Image(systemName: "list.bullet")
                            .font(.caption2)
                        Text("\(note.items.count) items")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Note Detail View

struct NoteDetailView: View {
    @Binding var note: Note
    @ObservedObject private var notesManager = NotesManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                TextField("Note Title", text: $note.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)

                Spacer()

                Button(action: {
                    notesManager.toggleFavorite(note)
                }) {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                        .foregroundColor(note.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)

                Button(action: {
                    // Delete note
                    notesManager.deleteNote(note)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Content Editor
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Free-form content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextEditor(text: $note.content)
                            .font(.body)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }

                    // Structured Items
                    if !note.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Items")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            ForEach(Array(note.items.enumerated()), id: \.element.id) { index, item in
                                NoteItemRow(
                                    item: item,
                                    index: index,
                                    onToggle: {
                                        var items = note.items
                                        items[index].isCompleted.toggle()
                                        note.items = items
                                    },
                                    onDelete: {
                                        note.items.remove(at: index)
                                    }
                                )
                            }
                        }
                    }

                    // Add Item Button
                    Button(action: {
                        let newItem = NoteItem(text: "", type: .bullet)
                        note.items.append(newItem)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Item")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    // Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created: \(note.dateCreated, style: .date) at \(note.dateCreated, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Modified: \(note.dateModified, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 16)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Note Item Row

struct NoteItemRow: View {
    let item: NoteItem
    let index: Int
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Group {
                switch item.type {
                case .checkbox:
                    Button(action: onToggle) {
                        Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundColor(item.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                case .bullet:
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.secondary)

                case .numbered:
                    Text("\(index + 1).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 24)

            Text(item.text)
                .font(.body)
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary : .primary)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - New Note Sheet

struct NewNoteSheet: View {
    @Binding var isPresented: Bool
    let onCreate: (Note) -> Void
    @ObservedObject private var notesManager = NotesManager.shared

    @State private var title = ""
    @State private var content = ""
    @State private var useVoiceInput = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Note")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Title")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("Enter note title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Content (optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $content)
                    .font(.body)
                    .frame(height: 150)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text("Tip: Use \"todo:\" or \"task:\" prefixes to create checkboxes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("Use structured formatting", isOn: $useVoiceInput)
                .font(.subheadline)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Create") {
                    createNote()
                }
                .keyboardShortcut(.return)
                .disabled(title.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func createNote() {
        let note: Note
        if useVoiceInput && !content.isEmpty {
            note = notesManager.createNoteFromTranscription(content)
            var updatedNote = note
            updatedNote.title = title
            notesManager.updateNote(updatedNote)
            onCreate(updatedNote)
        } else {
            note = notesManager.createNote(title: title, content: content)
            onCreate(note)
        }
        isPresented = false
    }
}
