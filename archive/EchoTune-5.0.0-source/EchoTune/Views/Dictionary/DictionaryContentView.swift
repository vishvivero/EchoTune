//
//  DictionaryContentView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct DictionaryContentView: View {
    @ObservedObject var dictionaryManager = DictionaryManager.shared
    @State private var selectedTab = 0
    
    // Add Replacement Form State
    @State private var showAddReplacement = false
    @State private var spokenForm = ""
    @State private var writtenForm = ""
    @State private var caseSensitive = false
    
    // Add Spelling Form State
    @State private var showAddSpelling = false
    @State private var correctWord = ""
    @State private var variationWord = ""
    @State private var variations: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Dictionary")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Teach EchoTune custom terminology, abbreviations, and name replacements.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Import / Export Buttons
                HStack(spacing: 8) {
                    Button(action: importDictionary) {
                        Label("Import", systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: exportDictionary) {
                        Label("Export", systemImage: "arrow.up.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            
            Divider()
            
            // Tabs segment
            Picker("", selection: $selectedTab) {
                Text("Word Replacements").tag(0)
                Text("Custom Spellings").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Tab Contents
            if selectedTab == 0 {
                // Word Replacements List
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Text Replacements (\(dictionaryManager.wordReplacements.count))")
                            .font(.headline)
                        Spacer()
                        Button(action: { showAddReplacement = true }) {
                            Label("Add Replacement", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    
                    List {
                        if dictionaryManager.wordReplacements.isEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "character.book.closed")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("No text replacements configured.")
                                    .foregroundColor(.secondary)
                                Text("Add replacements like 'btw' → 'by the way' to clean up dictations automatically.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            ForEach(dictionaryManager.wordReplacements) { r in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(r.spokenForm)
                                                .font(.system(.body, design: .monospaced))
                                                .fontWeight(.bold)
                                            Image(systemName: "arrow.right")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                            Text(r.writtenForm)
                                                .fontWeight(.semibold)
                                        }
                                        if r.caseSensitive {
                                            Text("Case Sensitive")
                                                .font(.system(size: 9))
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(3)
                                        }
                                    }
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { r.isEnabled },
                                        set: { _ in dictionaryManager.toggleReplacement(r) }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    
                                    Button(action: { dictionaryManager.deleteReplacement(r) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            } else {
                // Custom Spellings List
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Custom Spellings (\(dictionaryManager.correctSpellings.count))")
                            .font(.headline)
                        Spacer()
                        Button(action: { showAddSpelling = true }) {
                            Label("Add Spelling", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    
                    List {
                        if dictionaryManager.correctSpellings.isEmpty {
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("No custom spellings configured.")
                                    .foregroundColor(.secondary)
                                Text("Add spelling terms (e.g. brand names) to teach local Whisper engines how to output them.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            ForEach(dictionaryManager.correctSpellings) { s in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.word)
                                            .fontWeight(.bold)
                                        
                                        if !s.variations.isEmpty {
                                            Text("Variations: " + s.variations.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { s.isEnabled },
                                        set: { _ in dictionaryManager.toggleSpelling(s) }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    
                                    Button(action: { dictionaryManager.deleteSpelling(s) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        // Sheet: Add Replacement Form
        .sheet(isPresented: $showAddReplacement) {
            VStack(spacing: 16) {
                Text("New Replacement")
                    .font(.headline)
                
                TextField("When I say (e.g. btw)", text: $spokenForm)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Type this instead (e.g. by the way)", text: $writtenForm)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Case Sensitive Match", isOn: $caseSensitive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showAddReplacement = false
                        clearReplacementForm()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Add") {
                        let replacement = WordReplacement(
                            spokenForm: spokenForm.trimmingCharacters(in: .whitespaces),
                            writtenForm: writtenForm.trimmingCharacters(in: .whitespacesAndNewlines),
                            caseSensitive: caseSensitive
                        )
                        dictionaryManager.addReplacement(replacement)
                        showAddReplacement = false
                        clearReplacementForm()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(spokenForm.trimmingCharacters(in: .whitespaces).isEmpty || writtenForm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 350)
        }
        // Sheet: Add Spelling Form
        .sheet(isPresented: $showAddSpelling) {
            VStack(alignment: .leading, spacing: 16) {
                Text("New Custom Spelling")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                TextField("Correct Spelling (e.g. ChatGPT)", text: $correctWord)
                    .textFieldStyle(.roundedBorder)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add Variations (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Common misspelling (e.g. chat gpt)", text: $variationWord)
                            .textFieldStyle(.roundedBorder)
                        Button(action: addVariation) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if !variations.isEmpty {
                        FlowLayout(items: variations) { v in
                            HStack(spacing: 4) {
                                Text(v)
                                Button(action: { variations.removeAll { $0 == v } }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Spacer()
                    Button("Cancel") {
                        showAddSpelling = false
                        clearSpellingForm()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Add") {
                        let spelling = CorrectSpelling(
                            word: correctWord.trimmingCharacters(in: .whitespaces),
                            variations: variations
                        )
                        dictionaryManager.addSpelling(spelling)
                        showAddSpelling = false
                        clearSpellingForm()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(correctWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 350)
        }
    }
    
    private func addVariation() {
        let trimmed = variationWord.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !variations.contains(trimmed) {
            variations.append(trimmed)
            variationWord = ""
        }
    }
    
    private func clearReplacementForm() {
        spokenForm = ""
        writtenForm = ""
        caseSensitive = false
    }
    
    private func clearSpellingForm() {
        correctWord = ""
        variationWord = ""
        variations = []
    }
    
    private func exportDictionary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "echotune-dictionary.json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try dictionaryManager.exportDictionary()
                    try data.write(to: url)
                } catch {
                    debugLog("❌ DictionaryContentView: Export failed: \(error)")
                }
            }
        }
    }
    
    private func importDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    try dictionaryManager.importDictionary(from: data)
                } catch {
                    debugLog("❌ DictionaryContentView: Import failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: View {
    let items: [String]
    let viewBuilder: (String) -> AnyView
    
    init<V: View>(items: [String], @ViewBuilder viewBuilder: @escaping (String) -> V) {
        self.items = items
        self.viewBuilder = { AnyView(viewBuilder($0)) }
    }
    
    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(self.items, id: \.self) { item in
                    self.viewBuilder(item)
                        .padding([.horizontal, .vertical], 4)
                        .alignmentGuide(.leading, computeValue: { d in
                            if (abs(width - d.width) > geo.size.width) {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            if item == self.items.last! {
                                width = 0
                            } else {
                                width -= d.width
                            }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { d in
                            let result = height
                            if item == self.items.last! {
                                height = 0
                            }
                            return result
                        })
                }
            }
        }
        .frame(height: 50)
    }
}
