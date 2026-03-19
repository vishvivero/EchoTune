//
//  DictionaryReplacementsSection.swift
//  EchoTune
//
//  Word replacements section for the Dictionary view
//

import SwiftUI
import AppKit

// MARK: - Replacements Section

struct DictionaryReplacementsSection: View {
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    let searchText: String
    @Binding var showAddReplacement: Bool

    private var filteredReplacements: [WordReplacement] {
        if searchText.isEmpty { return dictionaryManager.wordReplacements }
        let query = searchText.lowercased()
        return dictionaryManager.wordReplacements.filter {
            $0.spokenForm.lowercased().contains(query) ||
            $0.writtenForm.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    Text("Word Replacements")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button(action: {
                    showAddReplacement = true
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

            Text("Automatically replace spoken abbreviations with their full form")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if filteredReplacements.isEmpty && dictionaryManager.wordReplacements.isEmpty {
                // Empty state
                replacementsEmptyState
            } else if filteredReplacements.isEmpty {
                // Search returned nothing
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No replacements match \"\(searchText)\"")
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
                    ForEach(filteredReplacements) { replacement in
                        WordReplacementCard(replacement: replacement)
                    }
                }
            }
        }
    }

    private var replacementsEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 4) {
                Text("No word replacements yet")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Add abbreviations or shorthand you commonly use.")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Quick add presets
            VStack(spacing: 8) {
                Text("Quick Add")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                let presets: [(String, String)] = [
                    ("btw", "by the way"),
                    ("fyi", "for your information"),
                    ("asap", "as soon as possible"),
                    ("omw", "on my way"),
                    ("imo", "in my opinion"),
                    ("tbh", "to be honest"),
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(presets, id: \.0) { preset in
                        Button(action: {
                            let newReplacement = WordReplacement(spokenForm: preset.0, writtenForm: preset.1)
                            dictionaryManager.addReplacement(newReplacement)
                        }) {
                            HStack(spacing: 4) {
                                Text(preset.0)
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8))
                                Text(preset.1)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().padding(.vertical, 4)

            Button(action: {
                dictionaryManager.resetToDefaults()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Word Replacement Card

struct WordReplacementCard: View {
    let replacement: WordReplacement
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editSpoken = ""
    @State private var editWritten = ""
    @State private var editCaseSensitive = false

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
                get: { replacement.isEnabled },
                set: { _ in dictionaryManager.toggleReplacement(replacement) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()

            // Spoken form
            VStack(alignment: .leading, spacing: 2) {
                Text(replacement.spokenForm)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(replacement.isEnabled ? .primary : .secondary)
                Text(dateFormatter.string(from: replacement.dateAdded))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Image(systemName: "arrow.right")
                .foregroundColor(.blue.opacity(replacement.isEnabled ? 1 : 0.4))
                .font(.system(size: 12))

            // Written form
            Text(replacement.writtenForm)
                .font(.system(size: 14))
                .foregroundColor(replacement.isEnabled ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Badges
            if replacement.caseSensitive {
                Text("Aa")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }

            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 6) {
                    Button(action: {
                        editSpoken = replacement.spokenForm
                        editWritten = replacement.writtenForm
                        editCaseSensitive = replacement.caseSensitive
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
                            dictionaryManager.deleteReplacement(replacement)
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
                TextField("Spoken form", text: $editSpoken)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))

                TextField("Written form", text: $editWritten)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            HStack {
                Toggle("Case sensitive", isOn: $editCaseSensitive)
                    .font(.caption)
                    .controlSize(.small)

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
                    var updated = replacement
                    updated.spokenForm = editSpoken.trimmingCharacters(in: .whitespaces)
                    updated.writtenForm = editWritten.trimmingCharacters(in: .whitespaces)
                    updated.caseSensitive = editCaseSensitive
                    dictionaryManager.updateReplacement(updated)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(editSpoken.trimmingCharacters(in: .whitespaces).isEmpty || editWritten.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
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
