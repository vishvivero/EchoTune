//
//  HomeContentView.swift
//  EchoTune
//

import SwiftUI

struct HomeContentView: View {
    @Binding var selectedView: NavigationItem
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @ObservedObject private var analyticsManager = AnalyticsManager.shared
    @State private var showStatsDialog = false
    @State private var showReferralSheet = false

    private var stats: UsageStatistics {
        analyticsManager.statistics
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Welcome Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back, \(NSFullUserName())")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    // Quick Stats - Clickable
                    Button(action: {
                        showStatsDialog = true
                    }) {
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(calculateDaysUsed()) days")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.green)
                                Text("\(stats.totalTranscriptions)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "text.word.spacing")
                                    .foregroundColor(.blue)
                                Text("\(formatNumber(stats.totalWords))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "gauge.high")
                                    .foregroundColor(.purple)
                                Text("\(calculateAverageWPM()) WPM")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .help("Click to view detailed statistics")
                }
                .padding(.top, 32)

                // Referral Banner (Direct sale only - not allowed in App Store)
                #if !APPSTORE
                ReferralBanner(showReferralSheet: $showReferralSheet)
                #endif

                // Collapsible Shortcut Instruction Banner
                ShortcutInstructionBanner()

                // Time Saved Card - Enhanced
                if stats.totalWords > 0 {
                    // Keep typing WPM constant at 40 (average typing speed)
                    let typingWPM = 40.0

                    // Calculate actual speaking WPM based on user's data
                    // If user has recording time, calculate their actual WPM
                    // Otherwise use average speaking speed of 150 WPM
                    let speakingWPM: Double = {
                        if stats.totalRecordingTime > 0 {
                            let minutes = stats.totalRecordingTime / 60
                            let calculatedWPM = Double(stats.totalWords) / minutes
                            // Clamp between 80-300 WPM to avoid unrealistic values
                            return min(max(calculatedWPM, 80), 300)
                        }
                        return 150.0 // Default average speaking speed
                    }()

                    // Calculate dynamic speed factor
                    let speedFactor = speakingWPM / typingWPM

                    let typingTimeMinutes = Double(stats.totalWords) / typingWPM
                    let recordingTimeMinutes = stats.totalRecordingTime / 60
                    let timeSavedMinutes = typingTimeMinutes - recordingTimeMinutes

                    VStack(alignment: .leading, spacing: 20) {
                        // Main Achievement Card
                        HStack(alignment: .center, spacing: 20) {
                            // Large Icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green, Color.blue]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                    .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)

                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("You're **\(String(format: "%.1fx", speedFactor))** faster with EchoTune!")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Speaking at **\(Int(speakingWPM)) WPM** vs typing at **\(Int(typingWPM)) WPM**")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 12)

                        // Time Breakdown
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\u{23F1}\u{FE0F} Time Saved")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text(formatDetailedTime(timeSavedMinutes * 60))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.green)
                            }

                            Divider()
                                .frame(height: 40)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("\u{2328}\u{FE0F} Typing Would Take")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text(formatDetailedTime(typingTimeMinutes * 60))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.orange)
                            }

                            Divider()
                                .frame(height: 40)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("\u{1F3A4} Recording Time")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text(formatDetailedTime(stats.totalRecordingTime))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green.opacity(0.08), Color.blue.opacity(0.08)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                }

                // Usage Graph
                UsageGraphView(stats: stats)

                // Recent Transcriptions Section
                if !historyManager.transcriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Transcriptions")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()

                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedView = .history
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("View All (\(historyManager.transcriptions.count))")
                                        .font(.subheadline)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Open full history")
                        }

                        // Group transcriptions by date
                        ForEach(groupedTranscriptions.keys.sorted(by: >), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 12) {
                                // Date header
                                Text(formatDateHeader(date))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.top, 8)

                                // Transcriptions for this date
                                ForEach(groupedTranscriptions[date] ?? []) { item in
                                    CompactTranscriptionRow(item: item, onDelete: {
                                        historyManager.deleteTranscription(item)
                                    }, onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedView = .history
                                        }
                                    })
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showStatsDialog) {
            StatsDetailDialog(stats: stats)
        }
        #if !APPSTORE
        .sheet(isPresented: $showReferralSheet) {
            ReferralView()
        }
        #endif
    }

    // Group transcriptions by date (limit to 10 most recent for home page)
    private var groupedTranscriptions: [Date: [TranscriptionHistoryItem]] {
        let recentItems = Array(historyManager.transcriptions.prefix(10))
        return Dictionary(grouping: recentItems) { item in
            Calendar.current.startOfDay(for: item.date)
        }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%dm %ds", minutes, secs)
    }

    private func formatDetailedTime(_ seconds: TimeInterval) -> String {
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

    private func calculateTypingTime(words: Int) -> Double {
        // Average typing speed: 40 WPM
        let wordsPerMinute = 40.0
        return Double(words) / wordsPerMinute
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func calculateAverageWPM() -> Int {
        guard stats.totalRecordingTime > 0 else { return 0 }
        let minutes = stats.totalRecordingTime / 60
        return Int(Double(stats.totalWords) / minutes)
    }

    private func calculateDaysUsed() -> Int {
        let calendar = Calendar.current
        let startDate = appCoordinator.appState.trialStartDate
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return max(1, (components.day ?? 0) + 1) // At least 1 day
    }
}
