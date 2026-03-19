//
//  DictionaryImportExport.swift
//  EchoTune
//
//  Import and export section for the Dictionary view
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Import/Export Section

struct DictionaryImportExportSection: View {
    @ObservedObject private var dictionaryManager = DictionaryManager.shared
    @Binding var importResultMessage: String?
    @Binding var showImportResult: Bool

    private var stats: DictionaryStatistics {
        dictionaryManager.getStatistics()
    }

    var body: some View {
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
                debugLog("❌ Export failed: \(error)")
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
