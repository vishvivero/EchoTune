//
//  CloudModelsSection.swift
//  EchoTune
//
//  Cloud models configuration UI
//

import SwiftUI

struct CloudModelsSection: View {
    @ObservedObject private var cloudManager = CloudModelsManager.shared
    @State private var expandedModels: Set<String> = []

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.blue)
                Text("Cloud transcription models require an API key from the provider")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)

            // Models list
            ForEach(cloudManager.availableModels) { model in
                CloudModelCard(
                    model: model,
                    isExpanded: expandedModels.contains(model.id),
                    onToggleExpand: {
                        if expandedModels.contains(model.id) {
                            expandedModels.remove(model.id)
                        } else {
                            expandedModels.insert(model.id)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Cloud Model Card

struct CloudModelCard: View {
    let model: CloudModel
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @ObservedObject private var cloudManager = CloudModelsManager.shared
    @State private var apiKey: String = ""
    @State private var showingSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Matching local models style
            Button(action: onToggleExpand) {
                HStack(spacing: 16) {
                    // Provider icon - matching local models
                    ZStack {
                        Circle()
                            .fill(cloudManager.hasAPIKey(for: model.id) ? providerColor.opacity(0.1) : Color.gray.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: "cloud.fill")
                            .font(.title3)
                            .foregroundColor(cloudManager.hasAPIKey(for: model.id) ? providerColor : .gray)
                    }

                    // Model Info - matching local models
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(model.name)
                                .font(.body)
                                .fontWeight(.semibold)

                            Text(model.provider.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            if !isExpanded {
                                Text(model.pricing)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text(model.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)

                        // Features preview when collapsed
                        if !isExpanded {
                            HStack(spacing: 8) {
                                ForEach(model.features.prefix(2), id: \.self) { feature in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text(feature)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                if model.features.count > 2 {
                                    Text("+\(model.features.count - 2) more")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Spacer()

                    // Action buttons - matching local models
                    HStack(spacing: 12) {
                        if cloudManager.hasAPIKey(for: model.id) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Configured")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(20)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    // Features
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(model.features, id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(feature)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Pricing
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.orange)
                        Text("Pricing: \(model.pricing)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)

                    Divider()

                    // API Key configuration
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Button(action: {
                                if let url = URL(string: model.apiKeyUrl) {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Get API Key")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 12) {
                            SecureField("Enter your API key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)

                            Button(action: saveAPIKey) {
                                HStack(spacing: 4) {
                                    if showingSaved {
                                        Image(systemName: "checkmark")
                                        Text("Saved")
                                    } else {
                                        Text("Save")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey.isEmpty)
                        }

                        if cloudManager.hasAPIKey(for: model.id) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key configured")
                                    .font(.caption)
                                    .foregroundColor(.green)

                                Spacer()

                                Button("Remove", role: .destructive) {
                                    cloudManager.removeAPIKey(for: model.id)
                                    apiKey = ""
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            if let savedKey = cloudManager.getAPIKey(for: model.id) {
                apiKey = savedKey
            }
        }
    }

    private var providerColor: Color {
        switch model.provider {
        case .groq: return .orange
        }
    }

    private func saveAPIKey() {
        cloudManager.setAPIKey(apiKey, for: model.id)
        showingSaved = true

        // Hide "Saved" message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingSaved = false
        }
    }
}
