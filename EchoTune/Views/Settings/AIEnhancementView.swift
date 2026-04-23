//
//  AIEnhancementView.swift
//  EchoTune
//
//  Groq-first AI enhancement configuration.
//

import SwiftUI

struct AIEnhancementView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var aiEngine = AIEnhancementEngine.shared

    @State private var sampleInput = "Um, like, I just wanted to say that, uh, the meeting yesterday was really good and, you know, we should definitely do it again."
    @State private var sampleOutput = ""
    @State private var isTesting = false
    @State private var testError: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Enhancement")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Improve transcription quality with Groq or Gemini. Groq is the recommended default because it is easier to onboard and already fits EchoTune’s cloud workflow.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                Toggle("Enable AI Enhancement", isOn: $settings.aiEnhancementEnabled)
                    .toggleStyle(.switch)
            } footer: {
                Text("When enabled, transcriptions can be cleaned up before they are inserted, while the original transcript is still preserved in history.")
                    .font(.caption)
            }

            if settings.aiEnhancementEnabled {
                Section {
                    Picker("AI Model", selection: $settings.selectedEnhancementModel) {
                        ForEach(AIEnhancementEngine.EnhancementModel.allCases) { model in
                            Text(model.displayName)
                                .tag(model.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if let model = AIEnhancementEngine.EnhancementModel(rawValue: settings.selectedEnhancementModel) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                switch model.provider {
                                case .groq:
                                    Text("Requires: Groq API Key")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(settings.groqAPIKey.isEmpty ? "⚠️ Not configured" : "✅ Configured")
                                        .font(.caption2)
                                        .foregroundColor(settings.groqAPIKey.isEmpty ? .orange : .green)
                                case .google:
                                    Text("Requires: Google Gemini API Key")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(settings.geminiAPIKey.isEmpty ? "⚠️ Not configured" : "✅ Configured")
                                        .font(.caption2)
                                        .foregroundColor(settings.geminiAPIKey.isEmpty ? .orange : .green)
                                }
                            }

                            Spacer()

                            Button(action: {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SwitchToSettingsTab"),
                                    object: nil,
                                    userInfo: ["tab": "apikeys"]
                                )
                            }) {
                                Text("Manage Keys →")
                                    .font(.caption)
                            }
                            .buttonStyle(.link)
                        }
                    }
                } header: {
                    Text("Model Selection")
                } footer: {
                    Text("Start with Groq. Keep Gemini available if you want a secondary cleanup model to compare against.")
                        .font(.caption)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Phase6FeatureRow(
                            icon: "text.bubble",
                            title: "Remove Fillers",
                            description: "Cuts um, uh, like, you know",
                            isEnabled: true,
                            isLocked: true
                        )

                        Divider()

                        Phase6FeatureRow(
                            icon: "textformat.abc",
                            title: "Fix Grammar & Spelling",
                            description: "Corrects wording while preserving intent",
                            isEnabled: true,
                            isLocked: true
                        )

                        Divider()

                        Phase6FeatureRow(
                            icon: "sparkles",
                            title: "Improve Clarity",
                            description: "Makes dictation easier to read and send",
                            isEnabled: true,
                            isLocked: true
                        )

                        Divider()

                        Phase6FeatureRow(
                            icon: "checkmark.shield",
                            title: "Safe Fallback",
                            description: "If enhancement fails, EchoTune keeps the original transcript",
                            isEnabled: true,
                            isLocked: true
                        )
                    }
                } header: {
                    Text("Always Included")
                }

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
                            Text("Leave blank to use EchoTune’s default cleanup prompt")
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
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test AI Enhancement")
                            .font(.headline)

                        Text("Input")
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

                            Text("Enhanced Output")
                                .font(.caption)
                                .foregroundColor(.green)

                            Text(sampleOutput)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(6)
                        }

                        if let testError {
                            Text("Error: \(testError)")
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

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("How It Works")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)

                    Text("• AI enhancement runs after speech recognition, not instead of it")
                    Text("• Groq is the easiest onboarding path and is recommended first")
                    Text("• Gemini remains available as a secondary provider")
                    Text("• Original transcription is preserved in history")
                    Text("• If AI fails, EchoTune falls back to the original transcript")
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
        case .groq:
            return !settings.groqAPIKey.isEmpty
        case .google:
            return !settings.geminiAPIKey.isEmpty
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

                let apiKey = settings.apiKey(for: model.provider)
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
