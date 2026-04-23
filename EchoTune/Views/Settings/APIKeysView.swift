//
//  APIKeysView.swift
//  EchoTune
//
//  Groq-first API key onboarding with optional Gemini support.
//

import SwiftUI

struct APIKeysView: View {
    @ObservedObject var settings = AppSettings.shared

    @State private var showGroqKey = false
    @State private var showGeminiKey = false
    @State private var testingProvider: String?
    @State private var testResult: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Keys")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Groq is the recommended setup: one key can power cloud transcription, AI enhancement, and meeting summaries. Gemini is optional if you want a second enhancement provider.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

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

                    Text("Recommended. Easiest setup for non-technical users. Powers Groq cloud transcription, Groq AI enhancement, and Groq meeting summaries.")
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
                        .buttonStyle(.borderless)

                        Button(action: { testKey("groq") }) {
                            if testingProvider == "groq" {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Test")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(settings.groqAPIKey.isEmpty || testingProvider == "groq")
                    }

                    if testingProvider == "groq", let testResult {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("✅") ? .green : .red)
                    }
                }
            } header: {
                Text("Recommended Setup")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack")
                            .foregroundColor(.blue)
                        Text("Google Gemini API")
                            .font(.headline)

                        Spacer()

                        Link("Get Free Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                            .font(.caption)
                    }

                    Text("Optional. Keep Gemini available as a secondary enhancement provider when you want to compare cleanup quality or use Google’s models instead of Groq.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        if showGeminiKey {
                            TextField("AIza...", text: $settings.geminiAPIKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("AIza...", text: $settings.geminiAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showGeminiKey.toggle() }) {
                            Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)

                        Button(action: { testKey("gemini") }) {
                            if testingProvider == "gemini" {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Test")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(settings.geminiAPIKey.isEmpty || testingProvider == "gemini")
                    }

                    if testingProvider == "gemini", let testResult {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("✅") ? .green : .red)
                    }
                }
            } header: {
                Text("Optional Secondary Provider")
            }

            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secure Storage")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Keys are stored in your Mac’s keychain. EchoTune only sends them to the provider you choose.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func testKey(_ provider: String) {
        testingProvider = provider
        testResult = nil

        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                switch provider {
                case "groq":
                    if settings.groqAPIKey.hasPrefix("gsk_") {
                        testResult = "✅ Groq key format looks valid"
                    } else {
                        testResult = "❌ Groq keys should usually start with gsk_"
                    }
                case "gemini":
                    if settings.geminiAPIKey.hasPrefix("AIza") {
                        testResult = "✅ Gemini key format looks valid"
                    } else if !settings.geminiAPIKey.isEmpty {
                        testResult = "✅ Gemini key saved — full validation happens on first use"
                    } else {
                        testResult = "❌ Add a Gemini key first"
                    }
                default:
                    testResult = "❌ Unknown provider"
                }
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if testingProvider == provider {
                    testingProvider = nil
                    testResult = nil
                }
            }
        }
    }
}

#Preview {
    APIKeysView()
        .frame(width: 600, height: 700)
}
