//
//  SetupStep.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct SetupStep: View {
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var whisperEngine = WhisperEngine.shared
    @State private var errorMessage: String? = nil
    @State private var isCompiling = false
    @State private var showAllModels = false
    let onNext: () -> Void

    private static let leanModelID = "openai_whisper-base"

    /// Best model for this specific Mac, based on RAM/CPU/chip generation.
    /// Onboarding never recommends Apple Speech, even on low-end hardware —
    /// it falls back to the lean Base model instead.
    private var recommendedModel: AIModel? {
        if let hardwareRecommended = SystemSpecsAnalyzer.shared.getRecommendedModel(from: modelManager.availableModels),
           !hardwareRecommended.isBuiltIn {
            return hardwareRecommended
        }
        return modelManager.availableModels.first { $0.id == Self.leanModelID }
    }

    /// Every locally-running model (excludes cloud models that need API keys —
    /// those live in Settings > AI & Models).
    private var localModels: [AIModel] {
        modelManager.availableModels.filter { $0.category == .local }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                OnboardingTheme.HeaderIconChip(systemName: "cpu.fill")

                Text("Choose AI Engine")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("We recommend the model below for your Mac — it's optional. You can try EchoTune right away with Apple Speech (no download), or pick from every available model.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let model = recommendedModel {
                        modelCard(model: model, badge: "Recommended for your \(SystemSpecsAnalyzer.shared.chipGeneration.displayName)")
                    } else {
                        ProgressView()
                            .frame(height: 120)
                    }

                    // "See what else is available" — full local model catalog
                    DisclosureGroup(isExpanded: $showAllModels) {
                        VStack(spacing: 8) {
                            ForEach(localModels) { model in
                                compactModelRow(model: model)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(OnboardingTheme.accent)
                            Text("See all \(localModels.count) available models")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(OnboardingTheme.accent.opacity(0.05))
                    )

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            // Continue — always available. If no model was chosen, EchoTune
            // runs on Apple Speech until the user picks one in Settings.
            VStack(spacing: 6) {
                Button(action: onNext) {
                    Text("Continue")
                        .frame(width: 200)
                }
                .buttonStyle(GradientProminentButtonStyle())
                .controlSize(.large)
                .disabled(modelManager.isDownloading)

                Text(modelManager.isDownloading
                     ? "Downloading \(modelManager.currentDownloadModel?.name ?? "model") — you can still continue…"
                     : "No download needed — EchoTune starts with Apple Speech.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            errorMessage = nil
        }
    }

    // MARK: - Compact row for the full catalog

    @ViewBuilder
    private func compactModelRow(model: AIModel) -> some View {
        let isInstalled = modelManager.isInstalledAndUsable(model)
        let isActive = modelManager.currentModel?.id == model.id
        let isDownloadingThis = modelManager.isDownloading && modelManager.currentDownloadModel?.id == model.id

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    if model.isBuiltIn {
                        Text("Built-in")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            .foregroundColor(.secondary)
                    }

                    if isActive {
                        Text("Active")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(OnboardingTheme.accent.opacity(0.15)))
                            .foregroundColor(OnboardingTheme.accent)
                    }

                    // Quiet chip-fit badge — helps people compare without noise
                    chipFitBadge(model: model)
                }

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(OnboardingTheme.accent)
                    Text(model.insight)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if model.isBuiltIn {
                Button("Select") {
                    let _ = modelManager.setCurrentModel(model)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isActive)
            } else if isInstalled {
                Button(isActive ? "Active" : "Select") {
                    let _ = modelManager.setCurrentModel(model)
                    selectAndCompileModel(model)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(OnboardingTheme.accent)
                .disabled(isActive)
            } else if isDownloadingThis {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Download") {
                    downloadModel(model)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(OnboardingTheme.accent)
                .disabled(modelManager.isDownloading)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Chip-fit badge

    private func chipFitBadge(model: AIModel) -> some View {
        let fit = SystemSpecsAnalyzer.shared.fitOf(model)
        let color: Color
        switch fit {
        case .best: color = Color.green
        case .good: color = OnboardingTheme.accent
        case .heavy: color = Color.orange
        }

        return Text(fit.label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundColor(color)
    }

    // MARK: - Recommended model card

    @ViewBuilder
    private func modelCard(model: AIModel, badge: String) -> some View {
        let isInstalled = modelManager.isInstalledAndUsable(model)
        let isActive = modelManager.currentModel?.id == model.id
        let isDownloadingThis = modelManager.isDownloading && modelManager.currentDownloadModel?.id == model.id
        let isLoadingThis = whisperEngine.isLoading && modelManager.currentModel?.id == model.id

        OnboardingCardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(OnboardingTheme.brandGradient)
                            .frame(width: 40, height: 40)
                            .shadow(color: OnboardingTheme.accent.opacity(0.3), radius: 5, x: 0, y: 3)
                        Image(systemName: "cpu")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(OnboardingTheme.accent)
                            .textCase(.uppercase)
                        Text(model.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("\(model.formattedSize)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isInstalled && isActive && whisperEngine.isAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    } else if isDownloadingThis {
                        ProgressView()
                            .controlSize(.small)
                    } else if isLoadingThis {
                        ProgressView()
                            .controlSize(.small)
                    } else if isInstalled {
                        Button(action: {
                            selectAndCompileModel(model)
                        }) {
                            Text("Select")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button(action: {
                            downloadModel(model)
                        }) {
                            Text("Download")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(OnboardingTheme.accent)
                        .disabled(modelManager.isDownloading)
                    }
                }

                // What this model is good at (instead of abstract stars)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(OnboardingTheme.accent)
                        .padding(.top, 1)

                    Text(model.insight)
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.top, 2)

                if isDownloadingThis {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: modelManager.downloadProgress)
                            .progressViewStyle(.linear)
                        HStack {
                            Text("Downloading \(model.name)...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(modelManager.downloadProgress * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(OnboardingTheme.accent)
                        }
                    }
                } else if isLoadingThis {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: whisperEngine.loadingProgress)
                            .progressViewStyle(.linear)
                        HStack {
                            Text(whisperEngine.loadingStage)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(whisperEngine.loadingProgress * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(OnboardingTheme.accent2)
                        }
                    }
                } else if isInstalled && isActive && !whisperEngine.isAvailable {
                    Button(action: {
                        selectAndCompileModel(model)
                    }) {
                        Label("Compile Engine", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(OnboardingTheme.accent)
                }
            }
        }
    }

    // MARK: - Actions

    private func downloadModel(_ model: AIModel) {
        errorMessage = nil
        modelManager.downloadModel(model) { result in
            switch result {
            case .success(let downloadedModel):
                selectAndCompileModel(downloadedModel)
            case .failure(let error):
                errorMessage = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    private func selectAndCompileModel(_ model: AIModel) {
        errorMessage = nil
        _ = modelManager.setCurrentModel(model)

        isCompiling = true
        whisperEngine.loadModel(model) { result in
            isCompiling = false
            switch result {
            case .success:
                debugLog("✓ Local model loaded successfully in onboarding setup")
            case .failure(let error):
                modelManager.markModelCorruptedAndRemove(model)
                errorMessage = "\(model.name)'s files were incomplete or corrupted (\(error.localizedDescription)). They've been removed — please tap Download to fetch it again."
            }
        }
    }
}