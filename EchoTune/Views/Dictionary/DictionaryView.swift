//
//  DictionaryView.swift
//  EchoTune
//
//  Custom dictionary for improving transcription accuracy
//

import SwiftUI

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
                DictionaryReplacementsSection(
                    searchText: searchText,
                    showAddReplacement: $showAddReplacement
                )

                // Correct Spellings Section
                DictionarySpellingsSection(
                    searchText: searchText,
                    showAddSpelling: $showAddSpelling
                )

                // Import/Export Section
                DictionaryImportExportSection(
                    importResultMessage: $importResultMessage,
                    showImportResult: $showImportResult
                )

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
}
