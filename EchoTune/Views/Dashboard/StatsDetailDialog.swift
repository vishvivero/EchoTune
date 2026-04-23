//
//  StatsDetailDialog.swift
//  EchoTune
//

import SwiftUI

struct StatsDetailDialog: View {
    let stats: UsageStatistics
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header with close button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Stats")
                            .font(.system(size: 32, weight: .bold))

                        Text("Keep up the great work!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }

                // Streak Card - Prominent
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.red]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            VStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)

                                Text("\(appState.currentStreak)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Streak")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(streakSummaryText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                }

                // Key Stats - 2x3 Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatDetailCardEnhanced(
                        title: "Transcriptions",
                        value: "\(stats.totalTranscriptions)",
                        icon: "doc.text.fill",
                        color: .blue,
                        trend: "+\(stats.totalTranscriptions)"
                    )

                    StatDetailCardEnhanced(
                        title: "Words",
                        value: formatNumber(stats.totalWords),
                        icon: "text.alignleft",
                        color: .green,
                        trend: "Total"
                    )

                    StatDetailCardEnhanced(
                        title: "Recording Time",
                        value: formatTime(stats.totalRecordingTime),
                        icon: "clock.fill",
                        color: .orange,
                        trend: "Active"
                    )

                    StatDetailCardEnhanced(
                        title: "Speaking Speed",
                        value: "\(calculateSpeakingWPM()) WPM",
                        icon: "gauge.high",
                        color: .purple,
                        trend: "Average"
                    )

                    StatDetailCardEnhanced(
                        title: "Time Saved",
                        value: formatTime(calculateTimeSaved()),
                        icon: "bolt.fill",
                        color: .yellow,
                        trend: "vs. typing"
                    )

                    StatDetailCardEnhanced(
                        title: "Efficiency",
                        value: String(format: "%.1fx", calculateSpeedFactor()),
                        icon: "arrow.up.circle.fill",
                        color: .pink,
                        trend: "Faster"
                    )
                }

                Spacer(minLength: 20)
            }
            .padding(32)
        }
        .frame(width: 650, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func calculateSpeakingWPM() -> Int {
        guard stats.totalRecordingTime > 0 else { return 150 } // Default to 150 WPM
        let minutes = stats.totalRecordingTime / 60
        let calculatedWPM = Double(stats.totalWords) / minutes
        // Clamp between 80-300 WPM to avoid unrealistic values
        return Int(min(max(calculatedWPM, 80), 300))
    }

    private var streakSummaryText: String {
        let streak = appState.currentStreak
        let activeDays = max(1, stats.dailyStats.count)
        if streak > 0 {
            return "You're on a \(streak)-day streak and have used EchoTune on \(activeDays) \(activeDays == 1 ? "day" : "days") overall."
        }
        return "No active streak right now — but you already have \(activeDays) \(activeDays == 1 ? "day" : "days") of usage history."
    }

    private func calculateTypingTime(words: Int) -> Double {
        let typingWPM = 40.0 // Average typing speed
        return Double(words) / typingWPM
    }

    private func calculateTimeSaved() -> TimeInterval {
        let typingTimeMinutes = calculateTypingTime(words: stats.totalWords)
        let recordingTimeMinutes = stats.totalRecordingTime / 60
        let timeSavedMinutes = typingTimeMinutes - recordingTimeMinutes
        return timeSavedMinutes * 60
    }

    private func calculateSpeedFactor() -> Double {
        let typingWPM = 40.0 // Average typing speed

        // Calculate actual speaking WPM based on user's data
        let speakingWPM: Double = {
            if stats.totalRecordingTime > 0 {
                let minutes = stats.totalRecordingTime / 60
                let calculatedWPM = Double(stats.totalWords) / minutes
                // Clamp between 80-300 WPM to avoid unrealistic values
                return min(max(calculatedWPM, 80), 300)
            }
            return 150.0 // Default average speaking speed
        }()

        return speakingWPM / typingWPM
    }
}

// MARK: - Stat Detail Card

struct StatDetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Stat Detail Card

struct StatDetailCardEnhanced: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }

                Spacer()

                Text(trend)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}
