//
//  ShareStatsView.swift
//  EchoTune
//
//  Share your stats on social media
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShareStatsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var generatedImage: NSImage?
    @State private var isGenerating = false
    @State private var userName: String = ""
    @State private var isCaptionExpanded = false

    private var totalWords: Int {
        appState.totalWordsTranscribed
    }

    private var timeSavedInMinutes: Int {
        let typingWPM = 40.0
        let speakingWPM = 150.0 // Average speaking speed

        if totalWords > 0 {
            let minutesTyping = Double(totalWords) / typingWPM
            let minutesSpeaking = Double(totalWords) / speakingWPM
            return Int(minutesTyping - minutesSpeaking)
        }
        return 0
    }

    private var wordsPerMinute: Int {
        // Rough estimate based on average speaking speed
        return 150
    }

    private var currentStreak: Int {
        // Calculate days since first use (same as homepage)
        let calendar = Calendar.current
        let startDate = appState.trialStartDate
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return max(1, (components.day ?? 0) + 1) // At least 1 day
    }

    private var shareableText: String {
        """
        Boosting my productivity with EchoTune! 🚀

        📊 My Stats:
        • \(totalWords) words dictated
        • \(timeSavedInMinutes) minutes saved
        • \(currentStreak) day streak

        Voice typing is transforming how I work! #productivity #AI #voicetyping #EchoTune
        """
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Simple header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Share Stats")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Share your productivity achievements")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // Two-column layout
                HStack(alignment: .top, spacing: 24) {
                    // Left column - Stats and Actions
                    VStack(alignment: .leading, spacing: 20) {
                        // Simple stats grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            SimpleStatCard(icon: "text.word.spacing", value: "\(totalWords)", title: "Words")
                            SimpleStatCard(icon: "clock.fill", value: "\(timeSavedInMinutes) min", title: "Time Saved")
                            SimpleStatCard(icon: "speedometer", value: "\(wordsPerMinute)", title: "Words/Min")
                            SimpleStatCard(icon: "flame.fill", value: "\(currentStreak) days", title: "Streak")
                        }

                        // Share buttons
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Share On")
                                .font(.headline)

                            VStack(spacing: 8) {
                                CleanShareButton(platform: "X (Twitter)", icon: "xmark", action: { shareToX() })
                                CleanShareButton(platform: "LinkedIn", icon: "link", action: { shareToLinkedIn() })
                                CleanShareButton(platform: "Reddit", icon: "text.bubble.fill", action: { shareToReddit() })
                                CleanShareButton(platform: "Instagram", icon: "camera.fill", action: { shareToInstagram() })
                            }
                        }
                        .padding(20)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)

                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: downloadImage) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download Image")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            // Expandable Caption Section
                            VStack(spacing: 0) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isCaptionExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Caption for Social Posts")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .rotationEffect(.degrees(isCaptionExpanded ? 90 : 0))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .foregroundColor(.primary)
                                    .cornerRadius(isCaptionExpanded ? 0 : 10)
                                    .cornerRadius(10, corners: isCaptionExpanded ? [.topLeft, .topRight] : [.allCorners])
                                }
                                .buttonStyle(.plain)

                                if isCaptionExpanded {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ScrollView {
                                            Text(shareableText)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .textSelection(.enabled)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(12)
                                                .background(Color(NSColor.textBackgroundColor))
                                                .cornerRadius(6)
                                        }
                                        .frame(maxHeight: 120)

                                        Button(action: copyShareText) {
                                            HStack {
                                                Image(systemName: "doc.on.doc.fill")
                                                Text("Copy to Clipboard")
                                                    .fontWeight(.medium)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                            if isGenerating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Generating...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(20)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: 420)

                    // Right column - Name and Preview
                    VStack(alignment: .leading, spacing: 20) {
                        // User name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Name")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Enter name", text: $userName)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preview")
                                .font(.headline)

                            GeometryReader { geometry in
                                StatsCardPreview(
                                    userName: userName.isEmpty ? NSFullUserName() : userName,
                                    totalWords: totalWords,
                                    timeSaved: timeSavedInMinutes,
                                    wordsPerMinute: wordsPerMinute,
                                    streak: currentStreak
                                )
                                .aspectRatio(2/3, contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .frame(maxWidth: 320)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            userName = NSFullUserName()
        }
    }

    // MARK: - Helper Methods

    private func copyShareText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shareableText, forType: .string)

        // Show brief success feedback
        let alert = NSAlert()
        alert.messageText = "Text Copied!"
        alert.informativeText = "The shareable text has been copied to your clipboard. You can now paste it into LinkedIn or any other platform."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func generateStatsImage() -> NSImage? {
        let width: CGFloat = 800
        let height: CGFloat = 1200

        let view = StatsCardPreview(
            userName: userName.isEmpty ? NSFullUserName() : userName,
            totalWords: totalWords,
            timeSaved: timeSavedInMinutes,
            wordsPerMinute: wordsPerMinute,
            streak: currentStreak
        )
        .frame(width: width, height: height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // Retina resolution

        guard let nsImage = renderer.nsImage else {
            return nil
        }

        return nsImage
    }

    private func downloadImage() {
        isGenerating = true

        DispatchQueue.main.async {
            guard let image = self.generateStatsImage() else {
                self.isGenerating = false

                let alert = NSAlert()
                alert.messageText = "Error"
                alert.informativeText = "Failed to generate image. Please try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }

            self.generatedImage = image
            self.saveImageToDownloads(image)
            self.isGenerating = false
        }
    }

    private func saveImageToDownloads(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "EchoTune-Stats-\(Date().timeIntervalSince1970).png"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }

    private func shareToX() {
        // Generate image first
        if let image = generateStatsImage() {
            generatedImage = image

            // Save temporarily for sharing
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("echotune-stats.png")
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: tempURL)
            }
        }

        let shareText = """
        I've been boosting my productivity with @EchoTuneApp! 🚀

        ✍️ \(totalWords) words dictated
        ⏱️ \(timeSavedInMinutes) minutes saved
        🔥 \(currentStreak) day streak

        Voice typing has never been easier! #productivity #AI #VoiceTyping #macOS #ProductivityTool #AITools #DictationApp #TechTools #WorkSmarter #EchoTune
        """

        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://twitter.com/intent/tweet?text=\(encodedText)"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func shareToLinkedIn() {
        if let image = generateStatsImage() {
            generatedImage = image
        }

        // LinkedIn doesn't support pre-filling posts via URL, so we'll just open LinkedIn
        let urlString = "https://www.linkedin.com/feed/"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        // Copy share text to clipboard
        let shareText = """
        Boosting my productivity with EchoTune! 🚀

        📊 My Stats:
        • \(totalWords) words dictated
        • \(timeSavedInMinutes) minutes saved
        • \(currentStreak) day streak

        Voice typing is transforming how I work. Download the image and share your productivity wins!

        #productivity #AI #voicetyping
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shareText, forType: .string)
    }

    private func shareToReddit() {
        // Save image first
        if let image = generateStatsImage() {
            generatedImage = image

            // Save to Downloads for manual upload
            let tempURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.appendingPathComponent("EchoTune-Stats.png")
            if let url = tempURL,
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }

        let shareText = "Boosting my productivity with EchoTune! 🚀 \(totalWords) words dictated, \(timeSavedInMinutes) minutes saved, \(currentStreak) day streak. Voice typing has never been easier!"

        let title = "My EchoTune Productivity Stats"
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Open Reddit submit page
        let urlString = "https://www.reddit.com/submit?title=\(encodedTitle)&text=\(encodedText)"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        // Alert user about image
        let alert = NSAlert()
        alert.messageText = "Reddit Post"
        alert.informativeText = "Your stats have been pre-filled! The image has been saved to Downloads - you can upload it manually to your Reddit post."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func shareToInstagram() {
        if let image = generateStatsImage() {
            generatedImage = image

            // Save to Downloads
            let tempURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.appendingPathComponent("EchoTune-Stats.png")
            if let url = tempURL,
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }

        // Try to open Instagram app (if installed on Mac)
        if let instagramURL = URL(string: "instagram://") {
            if NSWorkspace.shared.urlForApplication(toOpen: instagramURL) != nil {
                NSWorkspace.shared.open(instagramURL)
            }
        }

        // Show instructions since Instagram doesn't support direct web/desktop posting
        let alert = NSAlert()
        alert.messageText = "Share to Instagram"
        alert.informativeText = "The stats image has been saved to your Downloads folder.\n\nTo share:\n1. Open Instagram on your phone\n2. Create a new post\n3. Upload the image from your device\n\nOr use AirDrop to transfer the image to your phone!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Downloads Folder")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open Downloads folder
            if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                NSWorkspace.shared.open(downloadsURL)
            }
        }
    }
}
