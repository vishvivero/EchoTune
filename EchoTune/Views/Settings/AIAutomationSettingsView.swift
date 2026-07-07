//
//  AIAutomationSettingsView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import Combine

struct AIAutomationSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var enhancementEngine = AIEnhancementEngine.shared
    @StateObject private var powerModeManager = PowerModeManager.shared
    
    @State private var showingAddRuleSheet = false
    @State private var newTriggerPhrase = ""
    @State private var newPromptText = ""
    @State private var removeTrigger = true
    @State private var forceAI = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: AI Enhancement Engine Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Enhancement Settings")
                        .font(.headline)
                    
                    Toggle("Enable AI Enhancement globally", isOn: $settings.aiEnhancementEnabled)
                        .toggleStyle(.switch)
                    
                    if settings.aiEnhancementEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Enhancement Model", selection: $settings.selectedEnhancementModel) {
                                ForEach(AIEnhancementEngine.EnhancementModel.allCases) { model in
                                    Text(model.displayName).tag(model.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Custom System Prompt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $settings.customEnhancementPrompt)
                                    .frame(height: 60)
                                    .padding(4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.2))
                                    )
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                
                // Section 2: Power Mode Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Power Mode settings")
                        .font(.headline)
                    
                    Toggle("Enable Adaptive Power Modes", isOn: Binding(
                        get: { powerModeManager.isEnabled },
                        set: { powerModeManager.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    
                    Toggle("Auto-switch profile based on active application", isOn: $powerModeManager.isAutoSwitchEnabled)
                        .toggleStyle(.switch)
                        .disabled(!powerModeManager.isEnabled)
                }
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                
                // Section 3: Trigger Word Rules
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Trigger Word Automation Rules")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingAddRuleSheet = true }) {
                            Label("Add Rule", systemImage: "plus")
                                .font(.caption)
                        }
                    }
                    
                    Text("When a trigger phrase is detected in your speech, a custom prompt runs automatically.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if enhancementEngine.triggerWordRules.isEmpty {
                        Text("No rules configured. Click Add Rule to create one.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(enhancementEngine.triggerWordRules) { rule in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\"\(rule.triggerPhrase)\"")
                                            .fontWeight(.bold)
                                        Text(rule.enhancementPrompt)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer(minLength: 20)
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Toggle("", isOn: Binding(
                                            get: { rule.isEnabled },
                                            set: { value in
                                                var updated = rule
                                                updated.isEnabled = value
                                                enhancementEngine.updateTriggerWordRule(updated)
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                        
                                        Button("Delete") {
                                            enhancementEngine.deleteTriggerWordRule(rule)
                                        }
                                        .font(.caption)
                                        .buttonStyle(.plain)
                                        .foregroundColor(.red)
                                    }
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    Button("Reset to Defaults") {
                        enhancementEngine.resetTriggerWordsToDefaults()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add Trigger Word Automation Rule")
                    .font(.headline)
                
                TextField("Trigger Phrase (e.g. 'fix grammar')", text: $newTriggerPhrase)
                    .textFieldStyle(.roundedBorder)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt Text")
                        .font(.caption)
                    TextEditor(text: $newPromptText)
                        .frame(height: 80)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                }
                
                Toggle("Remove trigger phrase from final output text", isOn: $removeTrigger)
                Toggle("Force-enable AI even if globally disabled", isOn: $forceAI)
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingAddRuleSheet = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Add") {
                        let rule = TriggerWordRule(
                            triggerPhrase: newTriggerPhrase.trimmingCharacters(in: .whitespacesAndNewlines),
                            enhancementPrompt: newPromptText.trimmingCharacters(in: .whitespacesAndNewlines),
                            removeTriggerFromOutput: removeTrigger,
                            activateAI: forceAI
                        )
                        if !rule.triggerPhrase.isEmpty && !rule.enhancementPrompt.isEmpty {
                            enhancementEngine.addTriggerWordRule(rule)
                        }
                        newTriggerPhrase = ""
                        newPromptText = ""
                        showingAddRuleSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTriggerPhrase.isEmpty || newPromptText.isEmpty)
                }
            }
            .padding()
            .frame(width: 400)
        }
    }
}
