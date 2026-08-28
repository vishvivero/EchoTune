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

    /// A lighter, faster alternative shown alongside the recommendation —
    /// hidden if the recommendation already *is* the lean model.
    private var leanModel: AIModel? {
        guard let lean = modelManager.availableModels.first(where: { $0.id == Self.leanModelID }) else { return nil }
        guard lean.id != recommendedModel?.id else { return nil }
        return lean
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Setup AI Engine")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("EchoTune transcribes your speech offline. Download the model recommended for your Mac, or pick the leaner, faster option.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 20)

            VStack(spacing: 16) {
                if let model = recommendedModel {
                    modelCard(model: model, badge: "Recommended for your Mac")
                } else {
                    ProgressView()
                        .frame(height: 120)
                }

                if let model = leanModel {
                    modelCard(model: model, badge: "Leaner & faster")
                }
            }
            .padding(.horizontal, 20)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Continue Button (Only shown if a model is successfully selected and loaded)
            if isModelActiveAndReady {
                Button(action: onNext) {
                    Text("Continue")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            errorMessage = nil
        }
    }

    private var isModelActiveAndReady: Bool {
        if let current = modelManager.currentModel {
            return whisperEngine.isAvailable && whisperEngine.loadedModelName == current.name
        }
        return false
    }

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
                        Circle()
                            .fill(OnboardingTheme.accent.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "cpu")
                            .font(.system(size: 18))
                            .foregroundColor(OnboardingTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(OnboardingTheme.accent)
                            .textCase(.uppercase)
                        Text(model.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("\(model.formattedSize) | \(model.language)")
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
                        .disabled(modelManager.isDownloading)
                    }
                }

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
                    // Selected but load failed/not loaded yet
                    Button(action: {
                        selectAndCompileModel(model)
                    }) {
                        Label("Compile Engine", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

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
                // A load failure on a model we believed was installed almost always means
                // the downloaded files are truncated/corrupted. Wipe it so the card reverts
                // to "Download" instead of retrying against permanently-broken files forever.
                modelManager.markModelCorruptedAndRemove(model)
                errorMessage = "\(model.name)'s files were incomplete or corrupted (\(error.localizedDescription)). They've been removed — please tap Download to fetch it again."
            }
        }
    }
}
