//
//  ShareStatsView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//

import SwiftUI
import AppKit

struct ShareStatsView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var stats = TranscriptionStats()
    @State private var selectedGradient = 0
    @State private var showCopiedToast = false
    
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
                    
                    // Share Actions
                    VStack(spacing: 12) {
                        Button(action: copyCardToClipboard) {
                            HStack {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Copy Stats")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
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
                    
                    // The Card
                    ZStack {
                        // Background
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: gradients[selectedGradient].colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
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
                                StatBox(title: "Words Transcribed", value: "\(appState.totalWordsTranscribed)")
                                StatBox(title: "Speaking Time", value: formatDuration(stats.totalSpeakingTime))
                                StatBox(title: "Time Saved", value: formatDuration(stats.timeSaved))
                                StatBox(title: "Daily Streak", value: "\(appState.currentStreak) Days")
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            // Footer
                            HStack {
                                Text("Local AI-Powered Dictation")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Text("echotune.app")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(28)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.25))
                                .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).opacity(0.1))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .padding(24)
                    }
                    .frame(maxWidth: 440, minHeight: 320)
                    
                    if showCopiedToast {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Stats copied to clipboard!")
                                .font(.subheadline)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
                    } else {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            }
        }
        .onAppear {
            stats.loadStats()
        }
    }
    
    private func copyCardToClipboard() {
        // Render view simulation: In an AppKit environment, we put a notification and copy a simulated URL or text representation, or write a success toast.
        // Copy formatted markdown/text to clipboard as fallback, and trigger success notification
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: nil)
        
        let statsText = """
        🎙️ My EchoTune AI Dictation Stats:
        • Words Transcribed: \(appState.totalWordsTranscribed)
        • Speaking Time: \(formatDuration(stats.totalSpeakingTime))
        • Time Saved: \(formatDuration(stats.timeSaved))
        • Daily Streak: \(appState.currentStreak) Days
        Sent via EchoTune.app
        """
        pb.setString(statsText, forType: .string)
        
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
    
    private func shareToX() {
        let text = "I've transcribed \(appState.totalWordsTranscribed) words and saved \(formatDuration(stats.timeSaved)) using EchoTune AI dictation! 🎙️✨"
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://twitter.com/intent/tweet?text=\(encodedText)&url=https://echotune.app"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
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
