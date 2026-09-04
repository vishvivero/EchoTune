//
//  ShareStatsView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//  6.5.0: card exports as a real PNG (copy image / save / share sheet),
//  carries the user's referral QR + link, model badge, time-saved explainer.
//

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

struct ShareStatsView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var stats = TranscriptionStats()
    @StateObject private var whisperEngine = WhisperEngine.shared
    @State private var referral = ReferralManager.shared
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
        // ScrollView so the fixed panes scroll rather than force the resizable
        // window wider (which slid the centered sidebar). Pane widths below are
        // flexible so the content fits the ~719px detail pane without overflow.
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share Your Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Export a gorgeous card of your EchoTune statistics to share on social media.")
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

                    // Share Actions — the card exports as a PNG image now
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

                    // The Card — rendered offscreen to PNG for export
                    StatsCardView(
                        gradientColors: gradients[selectedGradient].colors,
                        words: appState.totalWordsTranscribed,
                        speakingTime: formatDuration(stats.totalSpeakingTime),
                        timeSaved: formatDuration(stats.timeSaved),
                        streak: appState.currentStreak,
                        modelBadge: modelBadgeText,
                        referralCode: referral.isRegistered && !referral.referralCode.isEmpty ? referral.referralCode : nil,
                        qrImage: makeQRCode()
                    )
                    .frame(maxWidth: 440, minHeight: 320)

                    if showCopiedToast {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toastMessage)
                                .font(.subheadline)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
                    } else {
                        Text("Time Saved assumes 40 wpm typing vs your speaking pace.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            }
        }
        .onAppear {
            stats.loadStats()
            renderCard()
        }
        .onChange(of: selectedGradient) { _, _ in
            renderCard()
        }
        .background(
            // Offscreen card rendered fresh whenever inputs change; PNG
            // generation happens in renderCard() via ImageRenderer.
            Color.clear.hidden()
        )
        // Share sheet
        .background(ShareSheetHost(image: $renderedCardImage, isPresented: $showSharePicker))
    }

    // MARK: - Card Export

    private func exportCardView() -> some View {
        StatsCardView(
            gradientColors: gradients[selectedGradient].colors,
            words: appState.totalWordsTranscribed,
            speakingTime: formatDuration(stats.totalSpeakingTime),
            timeSaved: formatDuration(stats.timeSaved),
            streak: appState.currentStreak,
            modelBadge: modelBadgeText,
            referralCode: referral.isRegistered && !referral.referralCode.isEmpty ? referral.referralCode : nil,
            qrImage: makeQRCode()
        )
    }

    /// Renders the stats card offscreen at 2× for crisp social media sharing.
    private func renderCard() {
        let card = exportCardView()
        let renderer = ImageRenderer(content: card
            .frame(width: 880, height: 660)
        )
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: 880, height: 660)
        if let cgImage = renderer.cgImage {
            renderedCardImage = NSImage(cgImage: cgImage, size: NSSize(width: 880, height: 660))
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
        panel.nameFieldStringValue = "EchoTune-Stats.png"
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

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }

    // MARK: - Helpers

    private var modelBadgeText: String {
        if let name = whisperEngine.loadedModelName, !name.isEmpty {
            return "100% offline · \(name)"
        }
        return "Local AI-Powered Dictation"
    }

    private func shareToX() {
        let text = "I've transcribed \(appState.totalWordsTranscribed) words and saved \(formatDuration(stats.timeSaved)) using EchoTune AI dictation! 🎙️✨"
        let link = referral.isRegistered && !referral.referralCode.isEmpty
            ? referral.referralLink : "https://echotune.app"
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://twitter.com/intent/tweet?text=\(encodedText)&url=\(link)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// QR code for the referral link (CIQRCodeGenerator), tinted white.
    private func makeQRCode() -> NSImage? {
        let link = referral.isRegistered && !referral.referralCode.isEmpty
            ? referral.referralLink : "https://echotune.app"
        guard let data = link.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 6, y: 6)) else { return nil }

        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: 120, height: 120))
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let mins = Int(interval / 60)
        let secs = Int(interval.truncatingRemainder(dividingBy: 60))
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - The Card (extracted so views can render it live AND offscreen for PNG)

struct StatsCardView: View {
    let gradientColors: [Color]
    let words: Int
    let speakingTime: String
    let timeSaved: String
    let streak: Int
    let modelBadge: String
    var referralCode: String?
    var qrImage: NSImage?

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)

            // Glass Card Body
            VStack(spacing: 24) {
                // Logo and Title
                HStack {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("EchoTune")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Text("PRO")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .cornerRadius(6)
                }

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    StatBox(title: "Words Transcribed", value: "\(words)")
                    StatBox(title: "Speaking Time", value: speakingTime)
                    StatBox(title: "Time Saved", value: timeSaved)
                    StatBox(title: "Daily Streak", value: "\(streak) Days")
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                // Footer — model badge + referral QR
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(modelBadge)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                        if let code = referralCode {
                            Text("echotune.app/refer?code=\(code)")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white)
                        } else {
                            Text("echotune.app")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    if let qr = qrImage {
                        Image(nsImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.25))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("EchoTune stats card: \(words) words transcribed, speaking time \(speakingTime), time saved \(timeSaved), streak \(streak) days")
    }
}

// MARK: - ImageRenderer host (offscreen render; keeps @State-driven redraws live)

struct ImageRendererHost<View: SwiftUI.View>: NSViewRepresentable {
    let card: View

    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Share Sheet host (NSSharingServicePicker anchored on the key window)

struct ShareSheetHost: NSViewRepresentable {
    @Binding var image: NSImage?
    @Binding var isPresented: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard isPresented, let image else { return }
        isPresented = false
        let picker = NSSharingServicePicker(items: [image])
        if let anchor = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        }
    }
}

// MARK: - Gradient Option
struct GradientOption {
    let name: String
    let colors: [Color]
}

// MARK: - Stat Box
struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
