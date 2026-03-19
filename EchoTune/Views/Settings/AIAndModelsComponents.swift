//
//  AIAndModelsComponents.swift
//  EchoTune
//
//  Supporting view components for AIAndModelsView
//  ModelRowView, WhisperModelRow, CloudModelRow, APIKeyField,
//  FeatureCheckmark, LocalModelManagementRow
//

import SwiftUI

// MARK: - Supporting Views

struct ModelRowView: View {
    let name: String
    let description: String
    let badge: String
    let badgeColor: Color
    let isDefault: Bool
    let isInstalled: Bool
    let onSetDefault: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .fontWeight(.medium)

                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDefault {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Default")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else if isInstalled {
                Button("Set as Default") {
                    onSetDefault()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct WhisperModelRow: View {
    let size: String
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared

    var modelId: String { "whisper-\(size)" }
    var displayName: String {
        "Whisper " + size.capitalized
    }
    var sizeText: String {
        switch size {
        case "tiny": return "74 MB"
        case "base": return "142 MB"
        case "small": return "466 MB"
        case "medium": return "1.5 GB"
        case "large-v3": return "2.9 GB"
        default: return ""
        }
    }
    var badge: String {
        switch size {
        case "tiny": return "Fastest"
        case "medium": return "Recommended"
        case "large-v3": return "Most Accurate"
        default: return ""
        }
    }

    var isInstalled: Bool {
        modelManager.installedModels.contains(where: { $0.id == modelId })
    }

    var body: some View {
        ModelRowView(
            name: "\(displayName) (\(sizeText))",
            description: isInstalled ? "Downloaded" : "Not downloaded",
            badge: badge,
            badgeColor: size == "medium" ? .blue : .gray,
            isDefault: settings.defaultTranscriptionModel == modelId,
            isInstalled: isInstalled,
            onSetDefault: { settings.defaultTranscriptionModel = modelId }
        )
    }
}

struct CloudModelRow: View {
    let name: String
    let description: String
    let badge: String
    let badgeColor: Color
    let modelId: String
    let requiresKey: Bool
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .fontWeight(.medium)

                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if requiresKey {
                    Text("⚠️ API key required")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if settings.defaultTranscriptionModel == modelId {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Default")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else if !requiresKey {
                Button("Set as Default") {
                    settings.defaultTranscriptionModel = modelId
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Add API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct APIKeyField: View {
    let title: String
    @Binding var key: String
    @Binding var showKey: Bool
    let linkURL: String
    let linkText: String
    let icon: String
    let iconColor: Color
    let isTesting: Bool
    let testResult: String?
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Link(linkText, destination: URL(string: linkURL)!)
                    .font(.caption)
            }

            HStack {
                if showKey {
                    TextField("Enter API key", text: $key)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Enter API key", text: $key)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)

                Button(action: onTest) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Test")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(key.isEmpty || isTesting)
            }

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(result.contains("✓") ? .green : .red)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor).opacity(0.2))
        .cornerRadius(8)
    }
}

struct FeatureCheckmark: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
}

struct LocalModelManagementRow: View {
    let model: AIModel
    @ObservedObject private var modelManager = ModelManager.shared

    var isDownloaded: Bool {
        modelManager.installedModels.contains(where: { $0.id == model.id })
    }

    var body: some View {
        HStack {
            Text(model.name)
                .font(.subheadline)

            Spacer()

            if isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Downloaded")
                        .font(.caption)
                }
            } else {
                Button("Download") {
                    downloadModel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(ByteCountFormatter.string(fromByteCount: Int64(model.size), countStyle: .file))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func downloadModel() {
        modelManager.downloadModel(model) { result in
            switch result {
            case .success:
                debugLog("Model downloaded successfully")
            case .failure(let error):
                debugLog("Failed to download model: \(error)")
            }
        }
    }
}

#Preview {
    AIAndModelsView()
}
