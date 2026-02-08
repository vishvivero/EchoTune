//
//  TriggerWordsViewContent.swift
//  EchoTune
//
//  Extracted content-only view for embedding inside other Forms.
//

import SwiftUI

struct TriggerWordsViewContent: View {
    @ObservedObject var engine = AIEnhancementEngine.shared
    @State private var showingAddSheet = false
    @State private var editingRule: TriggerWordRule?

    var body: some View {
        Group {
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

            Button(action: { showingAddSheet = true }) {
                Label("Add Trigger Word", systemImage: "plus.circle.fill")
            }

            Button("Reset to Defaults") {
                engine.resetTriggerWordsToDefaults()
            }
            .foregroundColor(.orange)
        }
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
