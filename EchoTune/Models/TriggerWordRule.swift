//
//  TriggerWordRule.swift
//  EchoTune
//
//  Trigger word models extracted from AIEnhancementEngine.
//  A trigger word rule activates a specific AI prompt when detected in transcription.
//

import Foundation

// MARK: - Trigger Word Rule

/// A trigger word rule that activates a specific AI prompt when detected in transcription
struct TriggerWordRule: Identifiable, Codable, Equatable {
    let id: UUID
    var triggerPhrase: String           // e.g., "fix this", "translate", "summarize"
    var enhancementPrompt: String       // The prompt to use when triggered
    var isEnabled: Bool
    var removeTriggerFromOutput: Bool   // Strip the trigger word from final text
    var activateAI: Bool               // Force-enable AI even if globally off

    init(id: UUID = UUID(),
         triggerPhrase: String,
         enhancementPrompt: String,
         isEnabled: Bool = true,
         removeTriggerFromOutput: Bool = true,
         activateAI: Bool = true) {
        self.id = id
        self.triggerPhrase = triggerPhrase
        self.enhancementPrompt = enhancementPrompt
        self.isEnabled = isEnabled
        self.removeTriggerFromOutput = removeTriggerFromOutput
        self.activateAI = activateAI
    }
}

// MARK: - Trigger Word Result

struct TriggerWordResult {
    let matchedRule: TriggerWordRule?
    let cleanedTranscript: String       // Transcript with trigger word removed (if applicable)
    let overridePrompt: String?         // The prompt to use instead of default
    let shouldForceAI: Bool             // Whether to force AI enhancement on
}

// MARK: - Default Trigger Word Rules

extension TriggerWordRule {
    static let defaultRules: [TriggerWordRule] = [
        TriggerWordRule(
            triggerPhrase: "fix this",
            enhancementPrompt: "Fix the grammar, spelling, and punctuation of the following text. Make it clear and professional. Output ONLY the corrected text.",
            removeTriggerFromOutput: true,
            activateAI: true
        ),
        TriggerWordRule(
            triggerPhrase: "summarize",
            enhancementPrompt: "Summarize the following text into a concise summary with key points. Use bullet points if there are multiple items. Output ONLY the summary.",
            removeTriggerFromOutput: true,
            activateAI: true
        ),
        TriggerWordRule(
            triggerPhrase: "translate to spanish",
            enhancementPrompt: "Translate the following text to Spanish. Output ONLY the Spanish translation, nothing else.",
            removeTriggerFromOutput: true,
            activateAI: true
        ),
        TriggerWordRule(
            triggerPhrase: "make it formal",
            enhancementPrompt: "Rewrite the following text in a formal, professional tone suitable for business communication. Output ONLY the rewritten text.",
            removeTriggerFromOutput: true,
            activateAI: true
        ),
        TriggerWordRule(
            triggerPhrase: "make it casual",
            enhancementPrompt: "Rewrite the following text in a casual, friendly tone suitable for messaging friends or colleagues. Output ONLY the rewritten text.",
            removeTriggerFromOutput: true,
            activateAI: true
        ),
    ]
}
