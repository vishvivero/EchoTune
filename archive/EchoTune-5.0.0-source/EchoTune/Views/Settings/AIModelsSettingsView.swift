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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: Local Whisper Models
                VStack(alignment: .leading, spacing: 12) {
                    Text("Local Whisper Models")
                        .font(.headline)
                    
                    Text("Local models run 100% on your device, ensuring maximum privacy and no network dependency.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(modelManager.availableModels.filter { $0.category == .local }) { model in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(model.name)
                                            .fontWeight(.semibold)
                                        
                                        if model.isBuiltIn {
                                            Text("Built-in")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if modelManager.currentModel?.id == model.id {
                                            Text("Active")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    
                                    HStack(spacing: 12) {
                                        Text("Size: \(model.formattedSize)")
                                        Text("Speed: \(model.speedRatingStars)")
                                        Text("Accuracy: \(model.accuracyRatingStars)")
                                    }
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer(minLength: 20)
                                
                                // Action button
                                if model.isBuiltIn {
                                    Button("Select") {
                                        let _ = modelManager.setCurrentModel(model)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(modelManager.currentModel?.id == model.id)
                                } else if modelManager.isInstalledAndUsable(model) {
                                    HStack(spacing: 8) {
                                        Button("Select") {
                                            let _ = modelManager.setCurrentModel(model)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(modelManager.currentModel?.id == model.id)
                                        
                                        Button("Delete") {
                                            let _ = modelManager.deleteModel(model)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(.red)
                                    }
                                } else {
                                    if modelManager.isDownloading && modelManager.currentDownloadModel?.id == model.id {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            ProgressView(value: modelManager.downloadProgress)
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
                                        .disabled(modelManager.isDownloading)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.01))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                
                // Section 2: Cloud Model API Keys
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cloud Model API Keys")
                        .font(.headline)
                    
                    Text("Stored securely in your macOS Keychain. Enables cloud-based Whisper execution.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        APIKeyField(title: "Groq API Key", placeholder: "gsk_...", text: $settings.groqAPIKey)
                        APIKeyField(title: "OpenAI API Key", placeholder: "sk-...", text: $settings.openaiAPIKey)
                        APIKeyField(title: "Deepgram API Key", placeholder: "Insert Deepgram Key", text: $settings.deepgramAPIKey)
                        APIKeyField(title: "Gemini API Key", placeholder: "Insert Gemini Key", text: $settings.geminiAPIKey)
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.01))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            }
            .padding(.bottom, 20)
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
