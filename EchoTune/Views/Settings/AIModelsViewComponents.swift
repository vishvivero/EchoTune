//
//  AIModelsViewComponents.swift
//  EchoTune
//
//  Supporting view components for AIModelsView.
//  Created by Vishnu Raj on 26/10/2025.
//

import SwiftUI
import Combine

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
                        Text(String(repeating: "\u{2605}", count: model.speedRating))
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    HStack(spacing: 4) {
                        Text("Accuracy:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(repeating: "\u{2605}", count: model.accuracyRating))
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
                    debugLog("\u{2705} Model downloaded: \(model.name)")
                    // Force refresh by updating the published property
                    self.modelManager.objectWillChange.send()
                case .failure(let error):
                    debugLog("\u{274C} Download failed: \(error)")
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

// MARK: - Model Loading Banner

struct ModelLoadingBanner: View {
    let modelName: String
    let progress: Double
    let stage: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Animated loading indicator
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Loading \(modelName)")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        // Estimated time for large models
                        if progress < 0.5 && progress > 0.1 {
                            Text("This may take a minute for large models")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(stage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.2))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
