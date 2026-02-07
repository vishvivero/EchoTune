//
//  TriggerWordsView.swift
//  EchoTune
//
//  Trigger Words Configuration UI
//  Allows users to define words/phrases that auto-activate specific AI prompts
//

import SwiftUI

struct TriggerWordsView: View {
    @ObservedObject var engine = AIEnhancementEngine.shared
    @State private var showingAddSheet = false
    @State private var editingRule: TriggerWordRule?

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trigger Words")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Define words or phrases that automatically activate specific AI prompts when detected in your transcription.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Rules List
            Section {
                if engine.triggerWordRules.isEmpty {
                    Text("No trigger words configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(engine.triggerWordRules) { rule in
                        TriggerWordRow(
                            rule: rule,
                            onEdit: {
                                editingRule = rule
                            },
                            onToggle: { enabled in
                                var updated = rule
                                updated.isEnabled = enabled
                                engine.updateTriggerWordRule(updated)
                            },
                            onDelete: {
                                engine.deleteTriggerWordRule(rule)
                            }
                        )
                    }
                }
            } header: {
                Text("Active Rules (\(engine.triggerWordRules.filter { $0.isEnabled }.count) of \(engine.triggerWordRules.count))")
            }

            // Actions
            Section {
                Button(action: { showingAddSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Trigger Word")
                    }
                }

                Button("Reset to Defaults") {
                    engine.resetTriggerWordsToDefaults()
                }
                .foregroundColor(.orange)
            }

            // Help
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("How Trigger Words Work")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)

                    Text("• Say a trigger phrase at the start or end of your recording")
                    Text("• EchoTune detects it and applies the matching AI prompt")
                    Text("• The trigger phrase is automatically removed from output")
                    Text("• Works even when AI Enhancement is turned off globally")
                    Text("• Example: Say \"fix this\" before your text to auto-correct it")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSheet) {
            TriggerWordEditSheet(rule: nil, isPresented: $showingAddSheet)
        }
        .sheet(item: $editingRule) { rule in
            TriggerWordEditSheet(rule: rule, isPresented: Binding(
                get: { editingRule != nil },
                set: { if !$0 { editingRule = nil } }
            ))
        }
    }
}

struct TriggerWordRow: View {
    let rule: TriggerWordRule
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    @State private var isEnabled: Bool

    init(rule: TriggerWordRule, onEdit: @escaping () -> Void, onToggle: @escaping (Bool) -> Void, onDelete: @escaping () -> Void) {
        self.rule = rule
        self.onEdit = onEdit
        self.onToggle = onToggle
        self.onDelete = onDelete
        _isEnabled = State(initialValue: rule.isEnabled)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\"\(rule.triggerPhrase)\"")
                    .font(.body)
                    .fontWeight(.medium)

                Text(rule.enhancementPrompt.prefix(80) + (rule.enhancementPrompt.count > 80 ? "…" : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if rule.activateAI {
                        Label("Force AI", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    if rule.removeTriggerFromOutput {
                        Label("Auto-strip", systemImage: "scissors")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { newValue in
                    onToggle(newValue)
                }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct TriggerWordEditSheet: View {
    let rule: TriggerWordRule?
    @Binding var isPresented: Bool

    @State private var triggerPhrase: String = ""
    @State private var enhancementPrompt: String = ""
    @State private var removeTrigger: Bool = true
    @State private var activateAI: Bool = true

    var isEditing: Bool { rule != nil }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Trigger Word" : "Add Trigger Word")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Section {
                    TextField("Trigger phrase", text: $triggerPhrase)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Trigger Phrase")
                } footer: {
                    Text("The word or phrase to detect (e.g., \"fix this\", \"translate\", \"summarize\")")
                        .font(.caption)
                }

                Section {
                    TextEditor(text: $enhancementPrompt)
                        .frame(minHeight: 100)
                        .font(.body)
                } header: {
                    Text("AI Prompt")
                } footer: {
                    Text("The AI prompt to use when this trigger is detected")
                        .font(.caption)
                }

                Section {
                    Toggle("Remove trigger from output", isOn: $removeTrigger)
                    Toggle("Force AI enhancement (even if globally off)", isOn: $activateAI)
                } header: {
                    Text("Options")
                }
            }
            .formStyle(.grouped)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save" : "Add") {
                    saveRule()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(triggerPhrase.trimmingCharacters(in: .whitespaces).isEmpty || enhancementPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500, height: 480)
        .onAppear {
            if let rule = rule {
                triggerPhrase = rule.triggerPhrase
                enhancementPrompt = rule.enhancementPrompt
                removeTrigger = rule.removeTriggerFromOutput
                activateAI = rule.activateAI
            }
        }
    }

    private func saveRule() {
        let newRule = TriggerWordRule(
            id: rule?.id ?? UUID(),
            triggerPhrase: triggerPhrase.trimmingCharacters(in: .whitespaces),
            enhancementPrompt: enhancementPrompt.trimmingCharacters(in: .whitespaces),
            isEnabled: rule?.isEnabled ?? true,
            removeTriggerFromOutput: removeTrigger,
            activateAI: activateAI
        )

        if isEditing {
            AIEnhancementEngine.shared.updateTriggerWordRule(newRule)
        } else {
            AIEnhancementEngine.shared.addTriggerWordRule(newRule)
        }
    }
}

#Preview {
    TriggerWordsView()
        .frame(width: 600, height: 700)
}
