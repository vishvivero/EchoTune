//
//  AIEnhancementView.swift
//  EchoTune
//
//  Phase 6 UI: AI Enhancement Configuration
//

import SwiftUI

struct AIEnhancementView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var aiEngine = AIEnhancementEngine.shared

    @State private var showingSampleTest = false
    @State private var sampleInput = "Um, like, I just wanted to say that, uh, the meeting yesterday was really good and, you know, we should definitely do it again."
    @State private var sampleOutput = ""
    @State private var isTesting = false
    @State private var testError: String?

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Enhancement")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Improve transcription quality using AI to fix grammar, remove fillers, and enhance clarity.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Master Toggle
            Section {
                Toggle("Enable AI Enhancement", isOn: $settings.aiEnhancementEnabled)
                    .toggleStyle(.switch)
            } footer: {
                Text("When enabled, all transcriptions will be enhanced using the selected AI model before being inserted.")
                    .font(.caption)
            }

            // Model Selection
            if settings.aiEnhancementEnabled {
                Section {
                    Picker("AI Model", selection: $settings.selectedEnhancementModel) {
                        ForEach(AIEnhancementEngine.EnhancementModel.allCases) { model in
                            Text(model.displayName)
                                .tag(model.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    // Show which API key is needed
                    if let model = AIEnhancementEngine.EnhancementModel(rawValue: settings.selectedEnhancementModel) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                switch model.provider {
                                case .openai:
                                    Text("Requires: OpenAI API Key")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if settings.openaiAPIKey.isEmpty {
                                        Text("⚠️ Not configured")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("✅ Configured")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }

                                case .anthropic:
                                    Text("Requires: Anthropic API Key")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if settings.claudeAPIKey.isEmpty {
                                        Text("⚠️ Not configured")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("✅ Configured")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                            }

                            Spacer()

                            Button(action: {
                                // Navigate to API Keys settings
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SwitchToSettingsTab"),
                                    object: nil,
                                    userInfo: ["tab": "apikeys"]
                                )
                            }) {
                                Text("Add API Keys →")
                                    .font(.caption)
                            }
                            .buttonStyle(.link)
                        }
                    }
                } header: {
                    Text("Model Selection")
                } footer: {
                    Text("GPT-4o Mini is recommended for speed and cost. GPT-4o and Claude models provide higher quality for complex text.")
                        .font(.caption)
                }

                // Enhancement Features
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Phase6FeatureRow(
                            icon: "text.bubble",
                            title: "Remove Fillers",
                            description: "Removes um, uh, like, you know",
                            isEnabled: true,
                            isLocked: true
                        )

                        Divider()

                        Phase6FeatureRow(
                            icon: "textformat.abc",
                            title: "Fix Grammar & Spelling",
                            description: "Corrects grammatical errors and typos",
                            isEnabled: true,
                            isLocked: true
                        )

                        Divider()

                        Phase6FeatureRow(
                            icon: "sparkles",
                            title: "Improve Clarity",
                            description: "Enhances sentence structure and flow",
                            isEnabled: true,
                            isLocked: true
                        )

                        Divider()

                        Phase6FeatureRow(
                            icon: "list.bullet",
                            title: "Smart Formatting",
                            description: "Auto-detects and formats lists properly",
                            isEnabled: true,
                            isLocked: true
                        )
                    }
                } header: {
                    Text("Features (Always Enabled)")
                } footer: {
                    Text("All features are automatically included in AI enhancement.")
                        .font(.caption)
                }

                // Custom Prompt
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Enhancement Instructions")
                            .font(.caption)
                            .fontWeight(.semibold)

                        TextEditor(text: $settings.customEnhancementPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        if settings.customEnhancementPrompt.isEmpty {
                            Text("Leave blank to use default enhancement prompt")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Button("Clear Custom Prompt") {
                                settings.customEnhancementPrompt = ""
                            }
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Advanced (Optional)")
                } footer: {
                    Text("Add custom instructions for specific use cases. Example: 'Format as technical documentation' or 'Use casual, conversational tone'")
                        .font(.caption)
                }

                // Test Enhancement
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test AI Enhancement")
                            .font(.headline)

                        Text("Input (with fillers):")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $sampleInput)
                            .font(.body)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        if !sampleOutput.isEmpty {
                            Divider()

                            Text("Enhanced Output:")
                                .font(.caption)
                                .foregroundColor(.green)

                            Text(sampleOutput)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(6)
                        }

                        if let error = testError {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Button(action: testEnhancement) {
                            HStack {
                                if isTesting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "play.circle.fill")
                                }
                                Text(isTesting ? "Testing..." : "Test Enhancement")
                            }
                        }
                        .disabled(isTesting || sampleInput.isEmpty || !hasRequiredAPIKey())
                        .buttonStyle(.borderedProminent)
                    }
                } header: {
                    Text("Test")
                }
            }

            // Help
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("How It Works")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)

                    Text("• AI enhancement processes your transcription after speech recognition")
                    Text("• Original transcription is preserved in history")
                    Text("• Processing typically takes 1-3 seconds")
                    Text("• Requires internet connection and valid API key")
                    Text("• Uses ~100-500 tokens per transcription (very low cost)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func hasRequiredAPIKey() -> Bool {
        guard let model = AIEnhancementEngine.EnhancementModel(rawValue: settings.selectedEnhancementModel) else {
            return false
        }

        switch model.provider {
        case .openai:
            return !settings.openaiAPIKey.isEmpty
        case .anthropic:
            return !settings.claudeAPIKey.isEmpty
        }
    }

    private func testEnhancement() {
        guard !sampleInput.isEmpty else { return }
        guard hasRequiredAPIKey() else {
            testError = "API key not configured"
            return
        }

        isTesting = true
        testError = nil
        sampleOutput = ""

        Task {
            do {
                guard let model = AIEnhancementEngine.EnhancementModel(rawValue: settings.selectedEnhancementModel) else {
                    throw AIEnhancementEngine.EnhancementError.invalidResponse
                }

                let apiKey: String
                switch model.provider {
                case .openai:
                    apiKey = settings.openaiAPIKey
                case .anthropic:
                    apiKey = settings.claudeAPIKey
                }

                let customPrompt = settings.customEnhancementPrompt.isEmpty ? nil : settings.customEnhancementPrompt

                let enhanced = try await aiEngine.enhance(
                    sampleInput,
                    using: model,
                    apiKey: apiKey,
                    customPrompt: customPrompt
                )

                await MainActor.run {
                    sampleOutput = enhanced
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testError = error.localizedDescription
                    isTesting = false
                }
            }
        }
    }
}

struct Phase6FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isLocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

#Preview {
    AIEnhancementView()
        .frame(width: 700, height: 900)
}
