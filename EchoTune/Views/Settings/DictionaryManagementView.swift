//
//  DictionaryManagementView.swift
//  EchoTune
//
//  Phase 6 UI: Dictionary Management - Word Replacements & Spellings
//

import SwiftUI
import UniformTypeIdentifiers

struct DictionaryManagementView: View {
    @ObservedObject var dictionaryManager = DictionaryManager.shared

    @State private var showingAddReplacement = false
    @State private var showingAddSpelling = false
    @State private var showingImport = false
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var importResult: String?
    @State private var exportResult: String?

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dictionary Management")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Customize word replacements and correct spellings to improve transcription accuracy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Statistics
            Section {
                let stats = dictionaryManager.getStatistics()

                HStack {
                    Phase6StatBox(
                        icon: "arrow.left.arrow.right",
                        title: "Replacements",
                        value: "\(stats.totalReplacements)"
                    )

                    Spacer()

                    Phase6StatBox(
                        icon: "textformat.abc",
                        title: "Spellings",
                        value: "\(stats.totalSpellings)"
                    )

                    Spacer()

                    Phase6StatBox(
                        icon: "list.bullet",
                        title: "Variations",
                        value: "\(stats.totalVariations)"
                    )
                }
                .padding(.vertical, 8)
            }

            // Word Replacements
            Section {
                if dictionaryManager.wordReplacements.isEmpty {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right.circle")
                            .foregroundColor(.secondary)
                        Text("No word replacements yet")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(dictionaryManager.wordReplacements) { replacement in
                        Phase6WordReplacementRow(replacement: replacement) {
                            dictionaryManager.deleteReplacement(replacement)
                        }
                    }
                }

                Button(action: { showingAddReplacement = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Replacement")
                    }
                }
            } header: {
                HStack {
                    Text("Word Replacements")
                    Spacer()
                    Text("(\(dictionaryManager.wordReplacements.count))")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("Replace spoken words with written forms. Example: 'btw' → 'by the way'")
                    .font(.caption)
            }

            // Correct Spellings
            Section {
                if dictionaryManager.correctSpellings.isEmpty {
                    HStack {
                        Image(systemName: "textformat.abc.dottedunderline")
                            .foregroundColor(.secondary)
                        Text("No correct spellings yet")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(dictionaryManager.correctSpellings) { spelling in
                        Phase6CorrectSpellingRow(spelling: spelling) {
                            dictionaryManager.deleteSpelling(spelling)
                        }
                    }
                }

                Button(action: { showingAddSpelling = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Correct Spelling")
                    }
                }
            } header: {
                HStack {
                    Text("Correct Spellings")
                    Spacer()
                    Text("(\(dictionaryManager.correctSpellings.count))")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("Teach proper spellings for names and technical terms. Example: 'GitHub' with variations 'github, Github, git hub'")
                    .font(.caption)
            }

            // Import/Export
            Section {
                Button(action: { showingImport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import from JSON")
                    }
                }

                Button(action: exportDictionary) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export to JSON")
                    }
                }

                if let result = importResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.contains("✅") ? .green : .red)
                }

                if let result = exportResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } header: {
                Text("Import / Export")
            } footer: {
                Text("Share your dictionary across devices or backup your customizations.")
                    .font(.caption)
            }

            // Actions
            Section {
                Button("Reset to Defaults") {
                    dictionaryManager.resetToDefaults()
                }
                .foregroundColor(.orange)

                Button("Clear All") {
                    dictionaryManager.clearAll()
                }
                .foregroundColor(.red)
            }

            // Help
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("How Dictionary Works")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)

                    Text("• Word replacements convert abbreviations to full phrases")
                    Text("• Correct spellings fix common misspellings and variations")
                    Text("• All changes apply after transcription completes")
                    Text("• Dictionary is processed before AI enhancement")
                    Text("• Changes are saved automatically")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddReplacement) {
            AddReplacementSheet(isPresented: $showingAddReplacement)
        }
        .sheet(isPresented: $showingAddSpelling) {
            AddSpellingSheet(isPresented: $showingAddSpelling)
        }
        .fileImporter(
            isPresented: $showingImport,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingExport,
            document: DictionaryDocument(data: exportURL),
            contentType: .json,
            defaultFilename: "echotune-dictionary.json"
        ) { result in
            handleExport(result)
        }
    }

    private func exportDictionary() {
        do {
            let data = try dictionaryManager.exportDictionary()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("echotune-dictionary.json")
            try data.write(to: tempURL)
            exportURL = tempURL
            showingExport = true
            exportResult = nil
        } catch {
            exportResult = "❌ Export failed: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let fileURL = try result.get().first!
            try dictionaryManager.loadDictionaryFromFile(at: fileURL)
            importResult = "✅ Dictionary imported successfully"
        } catch {
            importResult = "❌ Import failed: \(error.localizedDescription)"
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        do {
            let savedURL = try result.get()
            exportResult = "✅ Dictionary saved to \(savedURL.lastPathComponent)"
        } catch {
            exportResult = "❌ Save failed: \(error.localizedDescription)"
        }
    }
}

struct Phase6StatBox: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct Phase6WordReplacementRow: View {
    let replacement: WordReplacement
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(replacement.spokenForm)
                        .font(.body)
                        .fontWeight(.medium)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(replacement.writtenForm)
                        .font(.body)
                        .foregroundColor(.blue)
                }

                if replacement.caseSensitive {
                    Text("Case sensitive")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct Phase6CorrectSpellingRow: View {
    let spelling: CorrectSpelling
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(spelling.word)
                .font(.body)
                .fontWeight(.medium)

            if !spelling.variations.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Variations: \(spelling.variations.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddReplacementSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var dictionaryManager = DictionaryManager.shared

    @State private var spokenForm = ""
    @State private var writtenForm = ""
    @State private var caseSensitive = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Word Replacement")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Section {
                    TextField("What you say (e.g., btw)", text: $spokenForm)
                        .textFieldStyle(.roundedBorder)

                    TextField("What gets typed (e.g., by the way)", text: $writtenForm)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Case Sensitive", isOn: $caseSensitive)
                } footer: {
                    Text("Example: Say 'btw' → Types 'by the way'")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    let replacement = WordReplacement(
                        spokenForm: spokenForm,
                        writtenForm: writtenForm,
                        caseSensitive: caseSensitive
                    )
                    dictionaryManager.addReplacement(replacement)
                    isPresented = false
                }
                .disabled(spokenForm.isEmpty || writtenForm.isEmpty)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 500, height: 350)
    }
}

struct AddSpellingSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var dictionaryManager = DictionaryManager.shared

    @State private var word = ""
    @State private var variationsText = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Correct Spelling")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Section {
                    TextField("Correct spelling (e.g., GitHub)", text: $word)
                        .textFieldStyle(.roundedBorder)

                    TextField("Variations (comma-separated)", text: $variationsText)
                        .textFieldStyle(.roundedBorder)
                } footer: {
                    Text("Example: Correct: 'GitHub', Variations: 'github, Github, git hub'")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    let variations = variationsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    let spelling = CorrectSpelling(
                        word: word,
                        variations: variations
                    )
                    dictionaryManager.addSpelling(spelling)
                    isPresented = false
                }
                .disabled(word.isEmpty)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 500, height: 350)
    }
}

// Document type for file export
struct DictionaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: URL?

    init(data: URL?) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export-only
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = data else {
            throw CocoaError(.fileReadUnknown)
        }
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    DictionaryManagementView()
        .frame(width: 700, height: 900)
}
