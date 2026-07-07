//
//  HelpFeedbackView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//

import SwiftUI
import AppKit

struct HelpFeedbackView: View {
    @State private var expandedFaq: Int? = nil
    
    let faqs = [
        FaqItem(
            question: "How do I configure keyboard shortcuts?",
            answer: "Open Settings and select the 'Hotkeys' tab. You can enable modifiers (e.g. Control, Option, Command) or record custom key combinations for triggering dictation and enhancing text."
        ),
        FaqItem(
            question: "Does EchoTune transcribe entirely offline?",
            answer: "Yes! By default, EchoTune uses local Whisper engines (Apple Speech or WhisperKit) running directly on your Mac's CPU/Neural Engine. Your voice data never leaves your device unless you explicitly configure Groq or Deepgram cloud API keys."
        ),
        FaqItem(
            question: "Why isn't text inserting directly into my text editor?",
            answer: "Direct text insertion requires Accessibility permissions. Go to System Settings -> Privacy & Security -> Accessibility and verify that EchoTune is checked. If it is checked, try unchecking and checking it again."
        ),
        FaqItem(
            question: "How do I improve transcription accuracy for jargon?",
            answer: "Open the 'Dictionary' tab from the sidebar. You can teach the model how to correctly spell custom names, terminology, and abbreviations, or define auto-replacement rules (e.g., spoken 'btw' replaced with 'by the way')."
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Help & Support")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Find answers to common questions or reach out to our team.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
                
                // Resources Panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("Helpful Resources")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ResourceCard(
                            title: "User Guide & Docs",
                            description: "Learn how to use power features and keyboard shortcuts.",
                            icon: "book.fill",
                            url: "https://echotune.app/docs"
                        )
                        ResourceCard(
                            title: "Troubleshooting",
                            description: "Resolve common input device and TCC permission errors.",
                            icon: "exclamationmark.shield.fill",
                            url: "https://echotune.app/troubleshoot"
                        )
                        ResourceCard(
                            title: "Frequently Asked Questions",
                            description: "General product features, licenses, and privacy answers.",
                            icon: "questionmark.circle.fill",
                            url: "https://echotune.app/faq"
                        )
                        ResourceCard(
                            title: "Privacy & Security",
                            description: "Read about our offline-first local data privacy policy.",
                            icon: "hand.raised.fill",
                            url: "https://echotune.app/privacy"
                        )
                    }
                }
                
                // FAQ Panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("Frequently Asked Questions")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        ForEach(0..<faqs.count, id: \.self) { index in
                            FaqRow(
                                item: faqs[index],
                                isExpanded: expandedFaq == index,
                                onTap: {
                                    withAnimation {
                                        expandedFaq = expandedFaq == index ? nil : index
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Contact Support Card
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Still need help?")
                            .font(.headline)
                        Text("Send us an email with diagnostic logs included. We will get back to you within 24 hours.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: openSupportEmail) {
                        Label("Contact Support", systemImage: "envelope.fill")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.15), lineWidth: 1))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    private func openSupportEmail() {
        let systemSpecs = SystemSpecsAnalyzer.shared.getSystemSpecs()
        let permissionsManager = PermissionsManager.shared
        let modelManager = ModelManager.shared
        let settings = AppSettings.shared

        let body = """
        [Please describe your issue or feedback above this line]

        ---
        System Information (auto-generated):

        Hardware:
        - Processor: \(systemSpecs.processorName)
        - Cores: \(systemSpecs.processorCount)
        - RAM: \(String(format: "%.1f", systemSpecs.totalRAMInGB)) GB
        - Architecture: \(systemSpecs.isAppleSilicon ? "Apple Silicon" : "Intel")

        Software:
        - macOS: \(systemSpecs.macOSVersion)
        - EchoTune Version: \(Bundle.main.appVersionString)

        Permissions:
        - Microphone: \(permissionsManager.hasMicrophonePermission ? "Granted" : "Not Granted")
        - Accessibility: \(permissionsManager.hasAccessibilityPermission ? "Granted" : "Not Granted")

        Current Settings:
        - Default Model: \(modelManager.currentModel?.name ?? "None")
        - Installed Models: \(modelManager.installedModels.map { $0.name }.joined(separator: ", "))
        - Auto Punctuation: \(settings.autoPunctuation ? "On" : "Off")
        - Smart Capitalization: \(settings.smartCapitalization ? "On" : "Off")
        - Insert Space After Text: \(settings.insertSpaceAfterText ? "On" : "Off")
        """

        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoString = "mailto:support@echotune.app?subject=EchoTune%20Support%20Request&body=\(encodedBody)"

        if let mailtoURL = URL(string: mailtoString) {
            NSWorkspace.shared.open(mailtoURL)
        }
    }
}

// MARK: - FAQ Item
struct FaqItem {
    let question: String
    let answer: String
}

// MARK: - FAQ Row
struct FaqRow: View {
    let item: FaqItem
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack {
                    Text(item.question)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(item.answer)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.top, 4)
                    .lineSpacing(4)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.01))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.04), lineWidth: 1))
    }
}

// MARK: - Resource Card
struct ResourceCard: View {
    let title: String
    let description: String
    let icon: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let targetURL = URL(string: url) {
                NSWorkspace.shared.open(targetURL)
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .font(.body)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.primary.opacity(0.01))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.04), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
