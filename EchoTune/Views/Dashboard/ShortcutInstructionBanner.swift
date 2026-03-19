//
//  ShortcutInstructionBanner.swift
//  EchoTune
//

import SwiftUI

struct ShortcutInstructionBanner: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var isExpanded = false
    @State private var testText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hold down **\(appCoordinator.shortcutManager.getCurrentShortcutString())** to dictate")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Test your microphone and keyboard shortcut")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.blue)
                            Text("Click in the text area below")
                                .font(.subheadline)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.blue)
                            Text("Hold down \(appCoordinator.shortcutManager.getCurrentShortcutString()) and speak")
                                .font(.subheadline)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.blue)
                            Text("Release the key to see your transcription")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Test text area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Try it here:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            if !testText.isEmpty {
                                Button(action: {
                                    testText = ""
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("Clear")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        TextEditor(text: $testText)
                            .font(.body)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )

                        if testText.isEmpty {
                            Text("Click here and hold \(appCoordinator.shortcutManager.getCurrentShortcutString()) to start dictating...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    // Tip
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Tip: This works in any app - email, messages, docs, code editors, and more!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}
