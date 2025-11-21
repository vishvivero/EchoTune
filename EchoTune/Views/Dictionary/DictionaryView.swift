//
//  DictionaryView.swift
//  EchoTune
//
//  Custom dictionary for improving transcription accuracy
//

import SwiftUI

struct DictionaryContentView: View {
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @State private var selectedTab = 0
    @State private var showAddReplacement = false
    @State private var showAddSpelling = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Dictionary")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Improve transcription accuracy by teaching EchoTune your vocabulary")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 20)

            // Tabs
            Picker("Dictionary Type", selection: $selectedTab) {
                Text("Word Replacements").tag(0)
                Text("Correct Spellings").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            Divider()

            // Content
            if selectedTab == 0 {
                WordReplacementsView()
            } else {
                CorrectSpellingsView()
            }
        }
    }
}

// MARK: - Word Replacements View

struct WordReplacementsView: View {
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @State private var showAddDialog = false
    @State private var editingReplacement: WordReplacement?

    var body: some View {
        VStack(spacing: 16) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundColor(.blue)
                    Text("Word Replacements")
                        .font(.headline)
                }

                Text("Automatically replace spoken abbreviations with their full form (e.g., \"btw\" becomes \"by the way\")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            // Add button
            HStack {
                Spacer()
                Button(action: {
                    editingReplacement = nil
                    showAddDialog = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Replacement")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 32)

            // List
            ScrollView {
                if dictionaryManager.wordReplacements.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No word replacements yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Add abbreviations or shorthand that you commonly use")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 12) {
                        ForEach(dictionaryManager.wordReplacements) { replacement in
                            WordReplacementRow(
                                replacement: replacement,
                                onEdit: {
                                    editingReplacement = replacement
                                    showAddDialog = true
                                },
                                onDelete: {
                                    dictionaryManager.deleteReplacement(replacement)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .sheet(isPresented: $showAddDialog) {
            AddReplacementDialog(
                isPresented: $showAddDialog,
                editingReplacement: editingReplacement
            )
        }
    }
}

// MARK: - Word Replacement Row

struct WordReplacementRow: View {
    let replacement: WordReplacement
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Spoken form
            VStack(alignment: .leading, spacing: 4) {
                Text("You say:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\"\(replacement.spokenForm)\"")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .foregroundColor(.blue)

            // Written form
            VStack(alignment: .leading, spacing: 4) {
                Text("Gets typed:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\"\(replacement.writtenForm)\"")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Edit")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Add/Edit Replacement Dialog

struct AddReplacementDialog: View {
    @Binding var isPresented: Bool
    var editingReplacement: WordReplacement?
    @ObservedObject private var dictionaryManager = DictionaryManager.shared

    @State private var spokenForm = ""
    @State private var writtenForm = ""
    @State private var caseSensitive = false

    var body: some View {
        VStack(spacing: 20) {
            Text(editingReplacement == nil ? "Add Word Replacement" : "Edit Word Replacement")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("What you say:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("e.g., btw", text: $spokenForm)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("What gets typed:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("e.g., by the way", text: $writtenForm)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Case sensitive", isOn: $caseSensitive)
                .font(.subheadline)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(editingReplacement == nil ? "Add" : "Save") {
                    saveReplacement()
                }
                .keyboardShortcut(.return)
                .disabled(spokenForm.isEmpty || writtenForm.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            if let replacement = editingReplacement {
                spokenForm = replacement.spokenForm
                writtenForm = replacement.writtenForm
                caseSensitive = replacement.caseSensitive
            }
        }
    }

    private func saveReplacement() {
        if let existing = editingReplacement {
            var updated = existing
            updated.spokenForm = spokenForm.trimmingCharacters(in: .whitespaces)
            updated.writtenForm = writtenForm.trimmingCharacters(in: .whitespaces)
            updated.caseSensitive = caseSensitive
            dictionaryManager.updateReplacement(updated)
        } else {
            let new = WordReplacement(
                spokenForm: spokenForm.trimmingCharacters(in: .whitespaces),
                writtenForm: writtenForm.trimmingCharacters(in: .whitespaces),
                caseSensitive: caseSensitive
            )
            dictionaryManager.addReplacement(new)
        }
        isPresented = false
    }
}

// MARK: - Correct Spellings View

struct CorrectSpellingsView: View {
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @State private var showAddDialog = false
    @State private var editingSpelling: CorrectSpelling?

    var body: some View {
        VStack(spacing: 16) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Correct Spellings")
                        .font(.headline)
                }

                Text("Teach EchoTune the correct spelling of names, technical terms, or specialized vocabulary")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            // Add button
            HStack {
                Spacer()
                Button(action: {
                    editingSpelling = nil
                    showAddDialog = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Word")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 32)

            // List
            ScrollView {
                if dictionaryManager.correctSpellings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "character.cursor.ibeam")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No custom spellings yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Add names, places, or technical terms that need correct spelling")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 12) {
                        ForEach(dictionaryManager.correctSpellings) { spelling in
                            CorrectSpellingRow(
                                spelling: spelling,
                                onEdit: {
                                    editingSpelling = spelling
                                    showAddDialog = true
                                },
                                onDelete: {
                                    dictionaryManager.deleteSpelling(spelling)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .sheet(isPresented: $showAddDialog) {
            AddSpellingDialog(
                isPresented: $showAddDialog,
                editingSpelling: editingSpelling
            )
        }
    }
}

// MARK: - Correct Spelling Row

struct CorrectSpellingRow: View {
    let spelling: CorrectSpelling
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Correct spelling:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(spelling.word)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)

                if !spelling.variations.isEmpty {
                    Text("Variations: \(spelling.variations.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Edit")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Add/Edit Spelling Dialog

struct AddSpellingDialog: View {
    @Binding var isPresented: Bool
    var editingSpelling: CorrectSpelling?
    @ObservedObject private var dictionaryManager = DictionaryManager.shared

    @State private var word = ""
    @State private var variationsText = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(editingSpelling == nil ? "Add Correct Spelling" : "Edit Correct Spelling")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Correct spelling:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("e.g., Anthropic", text: $word)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Common misspellings (comma-separated, optional):")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("e.g., Anthropick, Antropic", text: $variationsText)
                    .textFieldStyle(.roundedBorder)
                Text("These will be automatically corrected to the proper spelling")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(editingSpelling == nil ? "Add" : "Save") {
                    saveSpelling()
                }
                .keyboardShortcut(.return)
                .disabled(word.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450)
        .onAppear {
            if let spelling = editingSpelling {
                word = spelling.word
                variationsText = spelling.variations.joined(separator: ", ")
            }
        }
    }

    private func saveSpelling() {
        let variations = variationsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let existing = editingSpelling {
            var updated = existing
            updated.word = word.trimmingCharacters(in: .whitespaces)
            updated.variations = variations
            dictionaryManager.updateSpelling(updated)
        } else {
            let new = CorrectSpelling(
                word: word.trimmingCharacters(in: .whitespaces),
                variations: variations
            )
            dictionaryManager.addSpelling(new)
        }
        isPresented = false
    }
}
