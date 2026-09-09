//
//  EchoProfileView.swift
//  EchoTune
//
//  Displays the user's Personal Operating Model profile and coach insight.
//

import SwiftUI

struct EchoProfileView: View {
    @ObservedObject private var memory = EchoMemoryManager.shared
    @ObservedObject private var learner = CorrectionLearner.shared
    @State private var showClearConfirmation = false
    @State private var showShare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(OnboardingTheme.brandGradient)
                Text("Echo Profile")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showShare = true
                } label: {
                    Label("Share Card", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                Button("Done") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)
            }
            .padding(.bottom, 4)
            .sheet(isPresented: $showShare) {
                EchoProfileShareView()
                    .frame(width: 720, height: 560)
            }

            Divider()

            if memory.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No transcriptions yet")
                        .font(.headline)
                    Text("Start dictating to build your Echo profile.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                // Profile stats
                VStack(alignment: .leading, spacing: 8) {
                    statRow(label: "Total transcriptions", value: "\(memory.profile.totalTranscriptions)")
                    statRow(label: "Total speaking time", value: formatDuration(memory.profile.totalDuration))
                    statRow(label: "Average length", value: String(format: "%.1f words", memory.profile.averageLength))
                    if let model = memory.profile.mostUsedModel {
                        statRow(label: "Most used model", value: model)
                    }
                    if !memory.profile.frequentTopics.isEmpty {
                        statRow(label: "Frequent topics", value: memory.profile.frequentTopics.joined(separator: ", "))
                    }
                    statRow(label: "Words Echo learned", value: "\(learner.learnedTotal)")
                }
                .padding(.vertical, 8)

                Divider()

                // Coach insight
                VStack(alignment: .leading, spacing: 6) {
                    Label("Echo Coach", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.accentColor)

                    if let insight = memory.coachInsight {
                        Text(insight.message)
                            .font(.body)
                            .foregroundColor(.primary)
                    } else {
                        Text("No insight yet.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Divider()

                // Actions
                HStack {
                    Button("Clear Profile") {
                        showClearConfirmation = true
                    }
                    .foregroundColor(.red)
                    .confirmationDialog(
                        "Clear all Echo memory?",
                        isPresented: $showClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear", role: .destructive) {
                            memory.clearAll()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will delete all stored transcriptions and profile data.")
                    }
                    Spacer()
                    Text("Profile updated: \(memory.profile.lastUpdated, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 480, height: 430)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(.primary)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

// MARK: - Window Controller

class EchoProfileWindowController: NSWindowController {
    convenience init() {
        let view = EchoProfileView()
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Echo Profile"
        window.setContentSize(NSSize(width: 480, height: 430))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
}