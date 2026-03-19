//
//  ShareStatsComponents.swift
//  EchoTune
//
//  Helper view components for ShareStatsView
//

import SwiftUI
import AppKit

// MARK: - Simple Stat Card

struct SimpleStatCard: View {
    let icon: String
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Clean Share Button

struct CleanShareButton: View {
    let platform: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.primary)
                Text(platform)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats Card Preview

struct StatsCardPreview: View {
    let userName: String
    let totalWords: Int
    let timeSaved: Int
    let wordsPerMinute: Int
    let streak: Int

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.7, blue: 0.9),
                    Color(red: 0.3, green: 0.5, blue: 0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 30) {
                Spacer()

                // Logo
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.2), radius: 10)
                }

                // Title
                VStack(spacing: 8) {
                    Text("EchoTune")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)

                    Text("AI Voice Dictation")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Stats grid
                VStack(spacing: 20) {
                    Text(userName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)

                    // Big number stats
                    VStack(spacing: 16) {
                        StatBox(
                            value: "\(totalWords)",
                            label: "Words Dictated",
                            icon: "text.word.spacing"
                        )

                        HStack(spacing: 16) {
                            StatBox(
                                value: "\(timeSaved) min",
                                label: "Time Saved",
                                icon: "clock.fill"
                            )

                            StatBox(
                                value: "\(wordsPerMinute)",
                                label: "Words/Min",
                                icon: "speedometer"
                            )
                        }

                        StatBox(
                            value: "\(streak) days",
                            label: "Current Streak",
                            icon: "flame.fill"
                        )
                    }
                }
                .padding(30)
                .background(Color.white.opacity(0.15))
                .cornerRadius(20)
                .padding(.horizontal, 40)

                Spacer()

                // Footer
                Text("Get EchoTune • Voice Your Thoughts")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()
            }
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    ShareStatsView()
        .frame(width: 900, height: 700)
}
