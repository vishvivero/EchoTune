//
//  AIModelsView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 26/10/2025.
//

import SwiftUI
import Combine

struct AIModelsView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var whisperEngine = WhisperEngine.shared
    @State private var selectedCategory: ModelCategory = .recommended
    @State private var searchText = ""

    private var systemSpecs: SystemSpecs {
        SystemSpecsAnalyzer.shared.getSystemSpecs()
    }

    private var recommendedModel: AIModel? {
        SystemSpecsAnalyzer.shared.getRecommendedModel(from: modelManager.availableModels)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Model Loading Progress Banner
                if whisperEngine.isLoading {
                    ModelLoadingBanner(
                        modelName: whisperEngine.loadedModelName ?? "Model",
                        progress: whisperEngine.loadingProgress,
                        stage: whisperEngine.loadingStage
                    )
                }

                // Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI Models")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Model Selection Dropdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Model")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if !modelManager.installedModels.isEmpty {
                            Picker("", selection: Binding(
                                get: { modelManager.currentModel?.id ?? "" },
                                set: { newID in
                                    if let model = modelManager.installedModels.first(where: { $0.id == newID }) {
                                        _ = modelManager.setCurrentModel(model)
                                    }
                                }
                            )) {
                                ForEach(modelManager.installedModels) { model in
                                    HStack {
                                        Image(systemName: model.isBuiltIn ? "apple.logo" : "cpu")
                                        Text(model.name)
                                    }
                                    .tag(model.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 300)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        } else {
                            Text("No models installed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(Color(NSColor.controlBackgroundColor))

                // Recommended Model Banner
                if let recommended = recommendedModel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.title3)

                            Text("Recommended for Your Mac")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                        Text(SystemSpecsAnalyzer.shared.getRecommendationReason())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Image(systemName: recommended.isBuiltIn ? "apple.logo" : "cpu")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommended.name)
                                    .font(.body)
                                    .fontWeight(.semibold)

                                Text(recommended.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if modelManager.installedModels.contains(where: { $0.id == recommended.id }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Installed")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.blue.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                Divider()

                // Category Tabs
                HStack(spacing: 0) {
                    ForEach(ModelCategory.allCases.filter { $0 != .comingSoon }, id: \.self) { category in
                        CategoryTab(
                            title: category.rawValue,
                            isSelected: selectedCategory == category,
                            action: {
                                selectedCategory = category
                            }
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Model List
                LazyVStack(spacing: 16) {
                    if selectedCategory == .cloud {
                        // Show cloud models section
                        CloudModelsSection()
                    } else {
                        // Show local/coming soon models
                        if selectedCategory == .comingSoon {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles").foregroundColor(.purple)
                                Text("These models are coming soon and are shown here for visibility. They are not downloadable yet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
                        }

                        let models = filteredModels

                        if models.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No models in this category")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            .padding(.bottom, 60)
                        } else {
                            ForEach(models) { model in
                                ModelRow(model: model)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var filteredModels: [AIModel] {
        let models = modelManager.getModels(for: selectedCategory)

        if searchText.isEmpty {
            return models
        }

        return models.filter { model in
            model.name.localizedCaseInsensitiveContains(searchText) ||
            model.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func getTotalStorageUsed() -> String {
        let totalBytes = modelManager.installedModels.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

// MARK: - Preview

#Preview {
    AIModelsView()
        .frame(width: 900, height: 700)
}
