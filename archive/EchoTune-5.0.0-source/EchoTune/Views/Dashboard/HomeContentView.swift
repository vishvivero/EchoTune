//
//  HomeContentView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//

import SwiftUI

struct HomeContentView: View {
    @Binding var selectedView: NavigationItem
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @ObservedObject private var analyticsManager = AnalyticsManager.shared
    @State private var showStatsDialog = false

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
                                Text("⏱️ Time Saved")
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
                                Text("⌨️ Typing Would Take")
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
                                Text("🎤 Recording Time")
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

                            Text("\(historyManager.transcriptions.count) total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
        #if APPSTORE
        .sheet(isPresented: $appCoordinator.showPurchaseSheet) {
            PurchaseView()
        }
        #endif
    }

    // Group transcriptions by date
    private var groupedTranscriptions: [Date: [TranscriptionHistoryItem]] {
        Dictionary(grouping: historyManager.transcriptions) { item in
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

// MARK: - Compact Transcription Row

struct CompactTranscriptionRow: View {
    let item: TranscriptionHistoryItem
    let onDelete: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    // Text content
                    Text(item.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(isHovering ? nil : 3)
                        .animation(.easeInOut, value: isHovering)

                    // Time and word count
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatTime(item.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "text.word.spacing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(wordCount) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDuration(item.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Actions on hover
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: { copyToClipboard() }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")

                        if let onDelete = onDelete {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.body)
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var wordCount: Int {
        item.text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }
}

// MARK: - Placeholder Content Views

struct UsageGraphView: View {
    let stats: UsageStatistics
    @State private var selectedPeriod: TimePeriod = .oneMonth

    enum TimePeriod: String, CaseIterable {
        case oneDay = "1D"
        case fiveDays = "5D"
        case twoWeeks = "2W"
        case oneMonth = "1M"

        var days: Int {
            switch self {
            case .oneDay: return 1
            case .fiveDays: return 5
            case .twoWeeks: return 14
            case .oneMonth: return 30
            }
        }
    }

    // Get daily data for the selected period
    private var dailyData: [(date: String, wordCount: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [(String, Int)] = []

        // Go backwards from today for the selected number of days
        for dayOffset in (0..<selectedPeriod.days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dateString = dateFormatter.string(from: date)
                let wordCount = stats.dailyStats[dateString]?.wordCount ?? 0
                data.append((dateString, wordCount))
            }
        }

        return data
    }

    // Get the maximum word count for scaling
    private var maxWordCount: Int {
        let max = dailyData.map { $0.wordCount }.max() ?? 1
        return max > 0 ? max : 100 // Minimum scale of 100 for empty data
    }

    // Calculate actual days with data
    private var daysWithData: Int {
        dailyData.filter { $0.wordCount > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Usage Over Time")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Time period selector
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Button(action: {
                            selectedPeriod = period
                        }) {
                            Text(period.rawValue)
                                .font(.caption)
                                .fontWeight(selectedPeriod == period ? .semibold : .regular)
                                .foregroundColor(selectedPeriod == period ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedPeriod == period ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Graph area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 200)

                if dailyData.isEmpty || dailyData.allSatisfy({ $0.wordCount == 0 }) {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No data yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Start using EchoTune to see your usage statistics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        // Simple bar chart visualization
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array(dailyData.enumerated()), id: \.offset) { index, dayData in
                                VStack(spacing: 4) {
                                    let wordCount = dayData.wordCount
                                    let barHeight = wordCount > 0 ?
                                        max(20, CGFloat(wordCount) / CGFloat(maxWordCount) * 140) : 10

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            wordCount > 0 ?
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.6)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ) :
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: barHeight)

                                    // Show day labels based on period
                                    if selectedPeriod.days <= 7 {
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else if index % max(1, selectedPeriod.days / 5) == 0 {
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        Text("Words transcribed per day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Stats summary below graph
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(formatNumber(stats.totalWords))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg per Day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let avgPerDay = daysWithData > 0 ? stats.totalWords / daysWithData : 0
                    Text("\(formatNumber(avgPerDay))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Stats Detail Dialog

struct StatsDetailDialog: View {
    let stats: UsageStatistics
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

                                Text("\(calculateDaysUsed())")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Day Streak")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("You've been using EchoTune for \(calculateDaysUsed()) \(calculateDaysUsed() == 1 ? "day" : "days")!")
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

    private func calculateDaysUsed() -> Int {
        let calendar = Calendar.current
        let startDate = AppState.shared.trialStartDate
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return max(1, (components.day ?? 0) + 1)
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

// MARK: - Shortcut Instruction Banner (Collapsible)

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

