//
//  EchoProfileShareView.swift
//  EchoTune
//
//  Shareable "My Echo Profile" card — the growth engine for the Personal
//  Operating Model. Renders the user's local profile (stats, learned
//  corrections, favorite topics, coach insight) as a branded PNG that users
//  share to X / social, carrying the echotune.app brand to new eyes.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EchoProfileShareView: View {
    @StateObject private var memory = EchoMemoryManager.shared
    @ObservedObject private var learner = CorrectionLearner.shared
    @State private var selectedGradient = 0
    @State private var showCopiedToast = false
    @State private var toastMessage = ""
    @State private var showSharePicker = false
    @State private var renderedCardImage: NSImage?

    let gradients = [
        GradientOption(name: "Purple Nebula", colors: [Color.purple, Color.blue]),
        GradientOption(name: "Aurora Glow", colors: [Color.green, Color.blue]),
        GradientOption(name: "Sunset Flare", colors: [Color.orange, Color.red]),
        GradientOption(name: "Cyberpunk", colors: [Color.pink, Color.purple]),
        GradientOption(name: "Deep Ocean", colors: [Color.blue, Color.teal])
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share Your Echo Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Export a gorgeous card of what EchoTune has learned about you.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                HStack(alignment: .top, spacing: 24) {
                    // Left Pane: Settings
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Customize Card")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Background Theme")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(0..<gradients.count, id: \.self) { index in
                                Button(action: { selectedGradient = index }) {
                                    HStack {
                                        Circle()
                                            .fill(LinearGradient(colors: gradients[index].colors, startPoint: .leading, endPoint: .trailing))
                                            .frame(width: 20, height: 20)

                                        Text(gradients[index].name)
                                            .fontWeight(selectedGradient == index ? .medium : .regular)
                                        Spacer()
                                        if selectedGradient == index {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(selectedGradient == index ? Color.blue.opacity(0.08) : Color.clear)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        VStack(spacing: 12) {
                            Button(action: copyCardImage) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text("Copy Card as Image")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(renderedCardImage == nil)

                            Button(action: saveCardPNG) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save PNG…")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(renderedCardImage == nil)

                            Button(action: showShareSheet) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share…")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(renderedCardImage == nil)

                            Button(action: shareToX) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Share on X (Twitter)")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .frame(minWidth: 220, maxWidth: 280)
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05), lineWidth: 1))

                    // Right Pane: Preview
                    VStack(spacing: 16) {
                        Text("Card Preview")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        EchoProfileCardView(
                            gradientColors: gradients[selectedGradient].colors,
                            totalTranscriptions: memory.profile.totalTranscriptions,
                            speakingTime: formatDuration(memory.profile.totalDuration),
                            learnedWords: learner.learnedTotal,
                            topics: memory.profile.frequentTopics,
                            coach: memory.coachInsight?.message
                        )
                        .frame(maxWidth: 440, minHeight: 340)

                        if showCopiedToast {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(toastMessage)
                                    .font(.subheadline)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Text("Your profile stays 100% on-device. Only what you share leaves this Mac.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .onAppear { renderCard() }
            .onChange(of: selectedGradient) { _, _ in renderCard() }
        }
        .background(ShareSheetHost(image: $renderedCardImage, isPresented: $showSharePicker))
    }

    // MARK: - Card Export

    private func renderCard() {
        let card = EchoProfileCardView(
            gradientColors: gradients[selectedGradient].colors,
            totalTranscriptions: memory.profile.totalTranscriptions,
            speakingTime: formatDuration(memory.profile.totalDuration),
            learnedWords: learner.learnedTotal,
            topics: memory.profile.frequentTopics,
            coach: memory.coachInsight?.message
        )
        let renderer = ImageRenderer(content: card.frame(width: 880, height: 680))
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: 880, height: 680)
        if let cgImage = renderer.cgImage {
            renderedCardImage = NSImage(cgImage: cgImage, size: NSSize(width: 880, height: 680))
        }
    }

    private func copyCardImage() {
        guard let image = renderedCardImage else { return }
        let pb = NSPasteboard.general
        pb.declareTypes([.png, .tiff], owner: nil)
        if let tiff = image.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            if let pngData = rep.representation(using: .png, properties: [:]) {
                pb.setData(pngData, forType: .png)
            }
        }
        showToast("Card image copied to clipboard!")
    }

    private func saveCardPNG() {
        guard let image = renderedCardImage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "EchoTune-Profile.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let rep = NSBitmapImageRep(cgImage: cg)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: url)
                    showToast("Saved to \(url.lastPathComponent)")
                }
            }
        }
    }

    private func showShareSheet() {
        guard renderedCardImage != nil else { return }
        showSharePicker = true
    }

    private func shareToX() {
        let text = "EchoTune has learned \(learner.learnedTotal) word fix\(learner.learnedTotal == 1 ? "" : "es") for me and I've dictated \(memory.profile.totalTranscriptions) times. 🎙️🧠 100% offline personal AI."
        let link = "https://echotune.app"
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://twitter.com/intent/tweet?text=\(encodedText)&url=\(link)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
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
}

// MARK: - The Profile Card

struct EchoProfileCardView: View {
    let gradientColors: [Color]
    let totalTranscriptions: Int
    let speakingTime: String
    let learnedWords: Int
    let topics: [String]
    let coach: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)

            VStack(spacing: 22) {
                // Header
                HStack {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("EchoTune")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        Text("100% PRIVATE")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(6)
                }

                // "My Echo Profile" title
                VStack(spacing: 2) {
                    Text("MY ECHO PROFILE")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(2)
                    Text("What my AI knows about me")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ProfileStatBox(title: "Dictations", value: "\(totalTranscriptions)")
                    ProfileStatBox(title: "Speaking Time", value: speakingTime)
                    ProfileStatBox(title: "Words Learned", value: "\(learnedWords)")
                }

                // Topics
                if !topics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FREQUENT TOPICS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1.5)
                        HStack(spacing: 6) {
                            ForEach(topics.prefix(4), id: \.self) { topic in
                                Text(topic.capitalized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Coach Insight
                if let coach, !coach.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("ECHO COACH")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(1.5)
                        }
                        Text(coach)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                // Footer
                HStack {
                    Text("echotune.app · On-device dictation that remembers")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("🧠")
                        .font(.system(size: 14))
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.25))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("EchoTune profile card: \(totalTranscriptions) dictations, \(speakingTime) speaking time, \(learnedWords) words learned")
    }
}

// MARK: - Profile Stat Box

struct ProfileStatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}