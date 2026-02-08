//
//  DictionaryView.swift
//  EchoTune
//
//  Custom dictionary for improving transcription accuracy
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Main Dictionary Content View

struct DictionaryContentView: View {
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @State private var searchText = ""
    @State private var showAddReplacement = false
    @State private var showAddSpelling = false
    @State private var importResultMessage: String?
    @State private var showImportResult = false

    private var stats: DictionaryStatistics {
        dictionaryManager.getStatistics()
    }

    private var enabledReplacementsCount: Int {
        dictionaryManager.wordReplacements.filter(\.isEnabled).count
    }

    private var enabledSpellingsCount: Int {
        dictionaryManager.correctSpellings.filter(\.isEnabled).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Search bar
                searchBar

                // Word Replacements Section
                replacementsSection

                // Correct Spellings Section
                spellingsSection

                // Import/Export Section
                importExportSection

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAddReplacement) {
            AddReplacementDialog(isPresented: $showAddReplacement, editingReplacement: nil)
        }
        .sheet(isPresented: $showAddSpelling) {
            AddSpellingDialog(isPresented: $showAddSpelling, editingSpelling: nil)
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage ?? "Dictionary imported successfully.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Dictionary")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Improve transcription accuracy by teaching EchoTune your vocabulary")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(stats.totalReplacements + stats.totalSpellings > 0 ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(stats.totalReplacements + stats.totalSpellings > 0 ? "Dictionary Active" : "Empty Dictionary")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(stats.totalReplacements + stats.totalSpellings > 0 ? .green : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }

            // Stats cards
            HStack(spacing: 12) {
                DictionaryStatCard(
                    icon: "arrow.left.arrow.right",
                    label: "Replacements",
                    value: "\(stats.totalReplacements)",
                    detail: "\(enabledReplacementsCount) active",
                    color: .blue
                )

                DictionaryStatCard(
                    icon: "checkmark.seal",
                    label: "Spellings",
                    value: "\(stats.totalSpellings)",
                    detail: "\(enabledSpellingsCount) active",
                    color: .green
                )

                DictionaryStatCard(
                    icon: "text.word.spacing",
                    label: "Variations",
                    value: "\(stats.totalVariations)",
                    detail: "patterns tracked",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
            TextField("Search replacements and spellings…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    // MARK: - Replacements Section

    private var filteredReplacements: [WordReplacement] {
        if searchText.isEmpty { return dictionaryManager.wordReplacements }
        let query = searchText.lowercased()
        return dictionaryManager.wordReplacements.filter {
            $0.spokenForm.lowercased().contains(query) ||
            $0.writtenForm.lowercased().contains(query)
        }
    }

    private var replacementsSection: some View {
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

    // MARK: - Spellings Section

    private var filteredSpellings: [CorrectSpelling] {
        if searchText.isEmpty { return dictionaryManager.correctSpellings }
        let query = searchText.lowercased()
        return dictionaryManager.correctSpellings.filter {
            $0.word.lowercased().contains(query) ||
            $0.variations.contains(where: { $0.lowercased().contains(query) })
        }
    }

    private var spellingsSection: some View {
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

    // MARK: - Import/Export Section

    private var importExportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.on.square.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 18))
                Text("Import & Export")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Text("Back up your dictionary or share it between devices")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Export button
                Button(action: exportDictionary) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Dictionary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(stats.totalReplacements + stats.totalSpellings) entries")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(stats.totalReplacements + stats.totalSpellings == 0)

                // Import button
                Button(action: importDictionary) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Dictionary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Merge from JSON file")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Clear / Reset
            HStack(spacing: 12) {
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

                Button(action: {
                    dictionaryManager.clearAll()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear All")
                    }
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Import/Export Actions

    private func exportDictionary() {
        let panel = NSSavePanel()
        panel.title = "Export Dictionary"
        panel.nameFieldStringValue = "EchoTune-Dictionary.json"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try dictionaryManager.saveDictionaryToFile(at: url)
            } catch {
                print("❌ Export failed: \(error)")
            }
        }
    }

    private func importDictionary() {
        let panel = NSOpenPanel()
        panel.title = "Import Dictionary"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let counts = try dictionaryManager.importDictionaryWithCounts(from: data)
                importResultMessage = "Added \(counts.replacements) replacement\(counts.replacements == 1 ? "" : "s") and \(counts.spellings) spelling\(counts.spellings == 1 ? "" : "s")."
                showImportResult = true
            } catch {
                importResultMessage = "Import failed: \(error.localizedDescription)"
                showImportResult = true
            }
        }
    }
}

// MARK: - Dictionary Stat Card

struct DictionaryStatCard: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 13))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Example Row (for empty states)

struct ExampleRow: View {
    let word: String
    let variations: String

    var body: some View {
        HStack(spacing: 8) {
            Text(word)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            Text("←")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(variations)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
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
