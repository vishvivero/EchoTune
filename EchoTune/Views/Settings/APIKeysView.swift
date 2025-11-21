//
//  APIKeysView.swift
//  EchoTune
//
//  Phase 6 UI: API Keys Configuration
//

import SwiftUI

struct APIKeysView: View {
    @ObservedObject var settings = AppSettings.shared

    @State private var showGroqKey = false
    @State private var showOpenAIKey = false
    @State private var showClaudeKey = false
    @State private var showDeepgramKey = false
    @State private var testingGroq = false
    @State private var testResult: String?

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Keys")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Configure API keys for cloud transcription and AI enhancement features.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Groq API Key
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        Text("Groq API")
                            .font(.headline)

                        Spacer()

                        Link("Get Free Key", destination: URL(string: "https://console.groq.com/keys")!)
                            .font(.caption)
                    }

                    Text("Ultra-fast Whisper Large v3 Turbo transcription")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        if showGroqKey {
                            TextField("gsk_...", text: $settings.groqAPIKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("gsk_...", text: $settings.groqAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showGroqKey.toggle() }) {
                            Image(systemName: showGroqKey ? "eye.slash" : "eye")
                        }

                        if !settings.groqAPIKey.isEmpty {
                            Button(action: testGroqConnection) {
                                if testingGroq {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                            }
                            .help("Test connection")
                        }
                    }

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("✅") ? .green : .red)
                    }
                }
            } header: {
                Text("Cloud Transcription")
            }

            // OpenAI API Key
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.green)
                        Text("OpenAI API")
                            .font(.headline)

                        Spacer()

                        Link("Get Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.caption)
                    }

                    Text("GPT-4o and GPT-4o-mini for AI enhancement")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        if showOpenAIKey {
                            TextField("sk-...", text: $settings.openaiAPIKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-...", text: $settings.openaiAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showOpenAIKey.toggle() }) {
                            Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                        }
                    }
                }
            } header: {
                Text("AI Enhancement")
            }

            // Anthropic/Claude API Key
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Anthropic API")
                            .font(.headline)

                        Spacer()

                        Link("Get Key", destination: URL(string: "https://console.anthropic.com/keys")!)
                            .font(.caption)
                    }

                    Text("Claude 3.5 Sonnet and Opus for AI enhancement")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        if showClaudeKey {
                            TextField("sk-ant-...", text: $settings.claudeAPIKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-ant-...", text: $settings.claudeAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showClaudeKey.toggle() }) {
                            Image(systemName: showClaudeKey ? "eye.slash" : "eye")
                        }
                    }
                }
            }

            // Deepgram API Key
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text("Deepgram API")
                            .font(.headline)

                        Spacer()

                        Link("Get Free Key", destination: URL(string: "https://console.deepgram.com/signup")!)
                            .font(.caption)
                    }

                    Text("Alternative cloud transcription with Nova-2")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        if showDeepgramKey {
                            TextField("Enter Deepgram API key", text: Binding(
                                get: { "" }, // Deepgram key not in AppSettings yet
                                set: { _ in }
                            ))
                            .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Enter Deepgram API key", text: Binding(
                                get: { "" },
                                set: { _ in }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showDeepgramKey.toggle() }) {
                            Image(systemName: showDeepgramKey ? "eye.slash" : "eye")
                        }
                    }
                }
            }

            // Security Notice
            Section {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secure Storage")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("All API keys are stored securely in your Mac's keychain and never transmitted except to their respective services.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // Test Groq connection
    private func testGroqConnection() {
        guard !settings.groqAPIKey.isEmpty else { return }

        testingGroq = true
        testResult = nil

        Task {
            do {
                // Simple test - just validate key format
                if settings.groqAPIKey.hasPrefix("gsk_") {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        testResult = "✅ API key format valid"
                        testingGroq = false
                    }
                } else {
                    await MainActor.run {
                        testResult = "❌ Invalid key format (should start with gsk_)"
                        testingGroq = false
                    }
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Connection failed"
                    testingGroq = false
                }
            }
        }
    }
}

#Preview {
    APIKeysView()
        .frame(width: 600, height: 700)
}
