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

// MARK: - Category Tab

struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .blue : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                        Color.blue.opacity(0.1) :
                        Color.clear
                )
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Row

struct ModelRow: View {
    @ObservedObject var modelManager = ModelManager.shared
    let model: AIModel

    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var showInfoAlert = false
    @State private var alertMessage = ""

    // Check if model is installed by checking the manager's installed models
    private var isModelInstalled: Bool {
        modelManager.installedModels.contains(where: { $0.id == model.id })
    }

    var body: some View {
        HStack(spacing: 16) {
            // Model Icon
            ZStack {
                Circle()
                    .fill(isModelInstalled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: model.isBuiltIn ? "apple.logo" : "cpu")
                    .font(.title3)
                    .foregroundColor(isModelInstalled ? .blue : .gray)
            }

            // Model Info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.body)
                        .fontWeight(.semibold)

                    if model.language == "Multilingual" {
                        Label(model.language, systemImage: "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Label(model.language, systemImage: "textformat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Ratings
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Speed:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(repeating: "★", count: model.speedRating))
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    HStack(spacing: 4) {
                        Text("Accuracy:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(repeating: "★", count: model.accuracyRating))
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                if model.category == .comingSoon {
                    // Coming Soon badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Coming Soon")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                } else if isModelInstalled && !isDownloading {
                    // Set as Default button
                    if modelManager.currentModel?.id != model.id {
                        Button(action: {
                            _ = modelManager.setCurrentModel(model)
                        }) {
                            Text("Set as Default")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Default badge
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Default")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // Delete button (only for non-default and non-built-in models)
                    if modelManager.currentModel?.id != model.id && !model.isBuiltIn {
                        Button(action: {
                            _ = modelManager.deleteModel(model)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Download button or progress / Cloud connect
                    if isDownloading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)

                            Text("\(Int(downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        if model.category == .cloud {
                            CloudConnectControls(model: model)
                        } else if modelManager.canDownload(model) {
                            Button(action: {
                                downloadModel()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .alert(alertMessage, isPresented: $showInfoAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func downloadModel() {
        isDownloading = true
        downloadProgress = 0.0

        modelManager.downloadModel(model, progressHandler: { progress in
            DispatchQueue.main.async {
                self.downloadProgress = progress
            }
        }) { result in
            DispatchQueue.main.async {
                self.isDownloading = false

                switch result {
                case .success:
                    debugLog("✅ Model downloaded: \(model.name)")
                    // Force refresh by updating the published property
                    self.modelManager.objectWillChange.send()
                case .failure(let error):
                    debugLog("❌ Download failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Cloud Connect Controls
struct CloudConnectControls: View {
    @ObservedObject var modelManager = ModelManager.shared
    let model: AIModel

    @State private var apiKey: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if modelManager.isCloudEnabled(model) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    Text("Connected").font(.caption).foregroundColor(.green)
                    if modelManager.currentModel?.id != model.id {
                        Button("Use") { _ = modelManager.setCurrentModel(model) }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    } else {
                        Text("Default").font(.caption).foregroundColor(.secondary)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Label("Connect", systemImage: "chevron.down")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    if let url = modelManager.apiKeyURL(for: model) {
                        Link("Get API key", destination: url)
                            .font(.caption)
                    }
                }

                if isExpanded {
                    HStack(spacing: 6) {
                        SecureField("Enter API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                        Button("Save") {
                            modelManager.saveApiKey(apiKey, for: model)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onAppear { apiKey = modelManager.apiKey(for: model) }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIModelsView()
        .frame(width: 900, height: 700)
}
