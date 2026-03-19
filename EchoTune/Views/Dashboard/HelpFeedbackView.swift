//
//  HelpFeedbackView.swift
//  EchoTune
//

import SwiftUI

// MARK: - Help & Feedback View

struct HelpFeedbackView: View {
    @State private var showEmailSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help & Feedback")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Get support or share your feedback with us")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Quick Help Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Help")
                        .font(.title2)
                        .fontWeight(.semibold)

                    HelpCard(
                        icon: "mic.circle.fill",
                        title: "How to use voice dictation",
                        description: "Press the global shortcut (\u{2318}\u{21E7}Space by default) or click 'Quick Record' to start dictating. Speak clearly and the text will be automatically typed.",
                        color: .blue
                    )

                    HelpCard(
                        icon: "cpu",
                        title: "Choosing the right model",
                        description: "Visit AI Models page to see recommended models for your Mac. Smaller models are faster, larger models are more accurate.",
                        color: .green
                    )

                    HelpCard(
                        icon: "keyboard",
                        title: "Customizing shortcuts",
                        description: "Go to Settings to customize keyboard shortcuts, transcription behavior, and other preferences.",
                        color: .orange
                    )
                }

                Divider()

                // Contact Support Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contact Support")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Have a question or issue? Send us an email and we'll get back to you as soon as possible.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: openFeedbackEmail) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Feedback Email")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    if showEmailSent {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Email client opened!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                    }
                }

                Divider()

                // Resources Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Resources")
                        .font(.title2)
                        .fontWeight(.semibold)

                    ResourceLink(
                        icon: "book.fill",
                        title: "Documentation",
                        url: "https://echotune.app/docs"
                    )

                    ResourceLink(
                        icon: "questionmark.circle.fill",
                        title: "FAQ",
                        url: "https://echotune.app/faq"
                    )

                    ResourceLink(
                        icon: "video.fill",
                        title: "Video Tutorials",
                        url: "https://echotune.app/tutorials"
                    )
                }
            }
            .padding(32)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func openFeedbackEmail() {
        // Gather system information
        let systemSpecs = SystemSpecsAnalyzer.shared.getSystemSpecs()
        let permissionsManager = PermissionsManager.shared
        let modelManager = ModelManager.shared
        let settings = AppSettings.shared

        let body = """
        [Please describe your issue or feedback above this line]

        ---
        System Information (auto-generated):
        - macOS: \(systemSpecs.macOSVersion)
        - Processor: \(systemSpecs.processorName)
        - RAM: \(String(format: "%.1f", systemSpecs.totalRAMInGB)) GB
        - Architecture: \(systemSpecs.isAppleSilicon ? "Apple Silicon" : "Intel")

        Permissions:
        - Microphone: \(permissionsManager.hasMicrophonePermission ? "\u{2713}" : "\u{2717}")
        - Accessibility: \(permissionsManager.hasAccessibilityPermission ? "\u{2713}" : "\u{2717}")

        Current Model: \(modelManager.currentModel?.name ?? "None")
        Installed Models: \(modelManager.installedModels.count)

        Settings:
        - Launch at startup: \(settings.launchAtStartup ? "On" : "Off")
        - Sound effects: \(settings.playSoundOnStartStop ? "On" : "Off")
        - Auto punctuation: \(settings.autoPunctuation ? "On" : "Off")
        """

        let subject = "EchoTune Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let mailtoString = "mailto:hi@echotune.app?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailtoString) {
            NSWorkspace.shared.open(url)
            showEmailSent = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showEmailSent = false
            }
        }
    }
}

// MARK: - Help Card

struct HelpCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Resource Link

struct ResourceLink: View {
    let icon: String
    let title: String
    let url: String

    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
