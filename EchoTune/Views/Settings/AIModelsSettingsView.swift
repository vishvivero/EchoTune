//
//  AIModelsSettingsView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import Combine

struct AIModelsSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var whisperEngine = WhisperEngine.shared
    @State private var selectedProvider: CloudAPIKeyProvider = .groq

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: Local Whisper Models
                VStack(alignment: .leading, spacing: 14) {
                    Text("Local Models")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Run 100% on your device. Pick by what you need — a \"Best fit\" badge shows how well each model runs on your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(spacing: 10) {
                        ForEach(modelManager.availableModels.filter { $0.category == .local }) { model in
                            modelRow(model)
                        }
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06), lineWidth: 1))

                // Section 2: Cloud Model API Keys
                VStack(alignment: .leading, spacing: 14) {
                    Text("Cloud API Keys")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Stored securely in your macOS Keychain. Enables cloud-based Whisper execution and AI enhancement.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        // Provider dropdown
                        Picker("Provider", selection: $selectedProvider) {
                            ForEach(CloudAPIKeyProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 320, alignment: .leading)

                        // Single API-key field for the chosen provider
                        APIKeyField(
                            title: "\(selectedProvider.displayName) API Key",
                            placeholder: selectedProvider.placeholder,
                            text: bindingFor(selectedProvider)
                        )

                        // Link to get the key
                        Link("Get a \(selectedProvider.displayName) API key", destination: selectedProvider.keyURL)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.02))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Model Row (mirrors onboarding clarity)

    @ViewBuilder
    private func modelRow(_ model: AIModel) -> some View {
        let isInstalled = modelManager.isInstalledAndUsable(model)
        let isActive = modelManager.currentModel?.id == model.id
        let isDownloadingThis = modelManager.isDownloading && modelManager.currentDownloadModel?.id == model.id
        let isLoadingThis = whisperEngine.isLoading && modelManager.currentModel?.id == model.id

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Name + chips
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    if model.isBuiltIn {
                        chip("Built-in", color: .secondary)
                    }

                    if isActive {
                        chip("Active", color: .red)
                    }

                    fitBadge(model)
                }

                // Insight line (plain-English, from onboarding)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                        .padding(.top, 1)
                    Text(model.insight)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(model.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 12)

            // Action
            actionButton(for: model, isInstalled: isInstalled, isActive: isActive, isDownloadingThis: isDownloadingThis, isLoadingThis: isLoadingThis)
        }
        .padding(14)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            isActive ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.05),
            lineWidth: isActive ? 1.5 : 1
        ))
    }

    @ViewBuilder
    private func actionButton(for model: AIModel, isInstalled: Bool, isActive: Bool, isDownloadingThis: Bool, isLoadingThis: Bool) -> some View {
        if model.isBuiltIn {
            Button("Select") {
                let _ = modelManager.setCurrentModel(model)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isActive)
        } else if isInstalled {
            HStack(spacing: 8) {
                if isLoadingThis {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView(value: whisperEngine.loadingProgress)
                            .controlSize(.small)
                            .frame(width: 80)
                        Text(whisperEngine.loadingStage)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Button(isActive ? "Active" : "Select") {
                        let _ = modelManager.setCurrentModel(model)
                        whisperEngine.loadModel(model) { _ in }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isActive)
                }

                Button("Delete") {
                    let _ = modelManager.deleteModel(model)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .font(.caption)
            }
        } else {
            if isDownloadingThis {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: modelManager.downloadProgress)
                        .controlSize(.small)
                        .frame(width: 80)
                    Text("\(Int(modelManager.downloadProgress * 100))%")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Download") {
                    modelManager.downloadModel(model) { _ in }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(modelManager.isDownloading)
            }
        }
    }

    private func fitBadge(_ model: AIModel) -> some View {
        let badge = SystemSpecsAnalyzer.shared.fitBadgeLabel(for: model, availableModels: modelManager.availableModels)
        if badge.label.isEmpty { return AnyView(EmptyView()) }
        let color: Color = badge.isBest ? .green : (badge.isHeavy ? .orange : .accentColor)
        return AnyView(chip(badge.label, color: color))
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundColor(color)
    }

    // MARK: - Cloud API Key provider support

    private enum CloudAPIKeyProvider: String, CaseIterable, Identifiable {
        case groq
        case openai
        case deepgram
        case gemini

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .groq: return "Groq"
            case .openai: return "OpenAI"
            case .deepgram: return "Deepgram"
            case .gemini: return "Gemini"
            }
        }

        var placeholder: String {
            switch self {
            case .groq: return "gsk_..."
            case .openai: return "sk-..."
            case .deepgram: return "Insert Deepgram Key"
            case .gemini: return "Insert Gemini Key"
            }
        }

        var keyURL: URL {
            switch self {
            case .groq: return URL(string: "https://console.groq.com/keys")!
            case .openai: return URL(string: "https://platform.openai.com/api-keys")!
            case .deepgram: return URL(string: "https://console.deepgram.com/signup?jump=keys")!
            case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
            }
        }
    }

    private func bindingFor(_ provider: CloudAPIKeyProvider) -> Binding<String> {
        switch provider {
        case .groq: return $settings.groqAPIKey
        case .openai: return $settings.openaiAPIKey
        case .deepgram: return $settings.deepgramAPIKey
        case .gemini: return $settings.geminiAPIKey
        }
    }
}

struct APIKeyField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: { isVisible.toggle() }) {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
