//
//  DictionarySpellingsSection.swift
//  EchoTune
//
//  Correct spellings section for the Dictionary view
//

import SwiftUI
import AppKit

// MARK: - Spellings Section

struct DictionarySpellingsSection: View {
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    let searchText: String
    @Binding var showAddSpelling: Bool

    private var filteredSpellings: [CorrectSpelling] {
        if searchText.isEmpty { return dictionaryManager.correctSpellings }
        let query = searchText.lowercased()
        return dictionaryManager.correctSpellings.filter {
            $0.word.lowercased().contains(query) ||
            $0.variations.contains(where: { $0.lowercased().contains(query) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                    Text("Correct Spellings")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button(action: {
                    showAddSpelling = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Text("Teach EchoTune the correct spelling of names, technical terms, or specialized vocabulary")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if filteredSpellings.isEmpty && dictionaryManager.correctSpellings.isEmpty {
                spellingsEmptyState
            } else if filteredSpellings.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No spellings match \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredSpellings) { spelling in
                        CorrectSpellingCard(spelling: spelling)
                    }
                }
            }
        }
    }

    private var spellingsEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 4) {
                Text("No custom spellings yet")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Add names, places, or technical terms that need correct spelling.")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Example suggestions
            VStack(spacing: 8) {
                Text("Examples")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 6) {
                    ExampleRow(word: "Anthropic", variations: "anthropik, antropic")
                    ExampleRow(word: "macOS", variations: "mac OS, Mac OS")
                    ExampleRow(word: "GitHub", variations: "github, git hub")
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Correct Spelling Card

struct CorrectSpellingCard: View {
    let spelling: CorrectSpelling
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editWord = ""
    @State private var editVariationsText = ""

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .background(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.8) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 6 : 3, y: isHovered ? 2 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var displayView: some View {
        HStack(spacing: 14) {
            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { spelling.isEnabled },
                set: { _ in dictionaryManager.toggleSpelling(spelling) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()

            // Word and variations
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(spelling.word)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(spelling.isEnabled ? .green : .secondary)

                    if !spelling.variations.isEmpty {
                        Text("\(spelling.variations.count) variation\(spelling.variations.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                if !spelling.variations.isEmpty {
                    Text(spelling.variations.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                }

                Text(dateFormatter.string(from: spelling.dateAdded))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 6) {
                    Button(action: {
                        editWord = spelling.word
                        editVariationsText = spelling.variations.joined(separator: ", ")
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing = true
                        }
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Edit")

                    Button(action: {
                        withAnimation {
                            dictionaryManager.deleteSpelling(spelling)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var editingView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Correct spelling")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("e.g., Anthropic", text: $editWord)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Variations (comma-separated)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("e.g., Anthropick, Antropic", text: $editVariationsText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button("Save") {
                    let variations = editVariationsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    var updated = spelling
                    updated.word = editWord.trimmingCharacters(in: .whitespaces)
                    updated.variations = variations
                    dictionaryManager.updateSpelling(updated)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(editWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
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
