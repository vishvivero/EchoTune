//
//  DashboardInsightsCards.swift
//  EchoTune
//
//  ET-763 · consistency heatmap + speaking-rhythm bars.
//
//  WHY THIS EXISTS
//  ---------------
//  "You have dictated 12,480 words" is a number, not a habit. Two things make the
//  habit visible:
//
//    · a 26-week × 7-day heatmap, so a streak (or a gap) is obvious at a glance
//    · a 24-hour rhythm bar chart, so you learn when you actually dictate
//
//  Everything is derived from data already on disk — `AnalyticsManager` daily
//  buckets for the heatmap and history timestamps for the hour histogram. No new
//  persistence, no network.
//

import SwiftUI

// MARK: - Data model (pure, testable)

/// One cell of the consistency heatmap.
struct HeatmapDay: Identifiable, Equatable {
    let date: Date
    let wordCount: Int
    let sessionCount: Int

    var id: Date { date }
    var isEmpty: Bool { wordCount == 0 && sessionCount == 0 }
}

/// Computes the dashboard insight data. Pure functions so the layout maths are
/// covered by tests rather than eyeballed in the UI.
enum DashboardInsights {

    /// Number of weeks shown in the heatmap (≈ six months).
    static let weeks = 26

    /// Builds a `weeks × 7` grid ending on the week containing `today`.
    ///
    /// The grid is column-major: each inner array is one week, Sunday-first, so
    /// the view can lay it out as columns of seven cells — the GitHub layout.
    /// Days in the future relative to `today` are omitted from the last column.
    static func heatmap(
        today: Date = Date(),
        dailyStats: [String: DailyStats],
        historyDates: [Date] = [],
        calendar: Calendar = .current
    ) -> [[HeatmapDay]] {
        // Sessions per day, from history timestamps.
        var sessionsByDay: [Date: Int] = [:]
        for date in historyDates {
            let day = calendar.startOfDay(for: date)
            sessionsByDay[day, default: 0] += 1
        }

        let todayStart = calendar.startOfDay(for: today)

        // Walk back to the Sunday that starts the first displayed week.
        let weekdayOfToday = calendar.component(.weekday, from: todayStart) // 1 = Sunday
        let endOfCurrentWeek = calendar.date(byAdding: .day, value: 7 - weekdayOfToday, to: todayStart) ?? todayStart
        let gridEnd = endOfCurrentWeek
        let gridStart = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: gridEnd) ?? gridEnd

        let keyFormatter = dayKeyFormatter(calendar: calendar)
        var result: [[HeatmapDay]] = []

        var weekStart = gridStart
        for _ in 0..<weeks {
            var column: [HeatmapDay] = []
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                if day > todayStart {
                    // Future days in the current week: keep the cell so the grid
                    // stays rectangular, but render it as empty.
                    column.append(HeatmapDay(date: day, wordCount: 0, sessionCount: 0))
                    continue
                }
                let key = keyFormatter.string(from: day)
                let stat = dailyStats[key]
                column.append(HeatmapDay(
                    date: day,
                    wordCount: stat?.wordCount ?? 0,
                    sessionCount: sessionsByDay[day] ?? stat?.transcriptionCount ?? 0
                ))
            }
            result.append(column)
            weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        }

        return result
    }

    /// Word-count histogram for each hour of the day (0...23).
    static func hourlyRhythm(historyDates: [Date], wordCounts: [Int] = [], calendar: Calendar = .current) -> [Int] {
        var buckets = [Int](repeating: 0, count: 24)
        for (index, date) in historyDates.enumerated() {
            let hour = calendar.component(.hour, from: date)
            guard buckets.indices.contains(hour) else { continue }
            // Falling back to 1 per session keeps the chart useful when word
            // counts are unavailable.
            let weight = index < wordCounts.count ? max(0, wordCounts[index]) : 1
            buckets[hour] += weight
        }
        return buckets
    }

    /// The busiest hours, most active first.
    static func peakHours(_ buckets: [Int], limit: Int = 3) -> [(hour: Int, words: Int)] {
        buckets.enumerated()
            .map { (hour: $0.offset, words: $0.element) }
            .filter { $0.words > 0 }
            .sorted { $0.words > $1.words }
            .prefix(limit)
            .map { $0 }
    }

    /// Heatmap intensity bucket 0...4, relative to the busiest day in the grid.
    static func intensity(forWordCount count: Int, busiest: Int) -> Int {
        guard count > 0, busiest > 0 else { return 0 }
        let ratio = Double(count) / Double(busiest)
        switch ratio {
        case ..<0.15: return 1
        case ..<0.35: return 2
        case ..<0.65: return 3
        default: return 4
        }
    }

    /// Human-readable hour label, e.g. `9 AM`, `12 PM`, `11 PM`.
    static func hourLabel(_ hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        let suffix = normalized < 12 ? "AM" : "PM"
        let display = normalized % 12 == 0 ? 12 : normalized % 12
        return "\(display) \(suffix)"
    }

    static func dayKeyFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

// MARK: - Heatmap card

struct ConsistencyHeatmapCard: View {
    let dailyStats: [String: DailyStats]
    let historyDates: [Date]
    var today: Date = Date()

    @State private var hovered: HeatmapDay?

    private var grid: [[HeatmapDay]] { DashboardInsights.heatmap(today: today, dailyStats: dailyStats, historyDates: historyDates) }

    private var busiest: Int {
        grid.flatMap { $0 }.map(\.wordCount).max() ?? 0
    }

    private var totalWords: Int { grid.flatMap { $0 }.reduce(0) { $0 + $1.wordCount } }
    private var activeDays: Int { grid.flatMap { $0 }.filter { !$0.isEmpty }.count }

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Consistency")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(activeDays) active days · \(totalWords.formatted()) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Hover readout — fixed height so the card does not jump.
            HStack(spacing: 6) {
                if let hovered, !hovered.isEmpty {
                    Text(hovered.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("\(hovered.wordCount.formatted()) words")
                        .font(.caption)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("\(hovered.sessionCount) session\(hovered.sessionCount == 1 ? "" : "s")")
                        .font(.caption)
                } else {
                    Text(hovered == nil ? "Hover a day for details" : "No dictation that day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .frame(height: 14)

            HStack(alignment: .top, spacing: 6) {
                // Weekday rail: Mon / Wed / Fri only, to stay compact.
                VStack(alignment: .trailing, spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(weekdayLabel(row))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(height: cellSize)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: cellSpacing) {
                                ForEach(week) { day in
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(color(for: day))
                                        .frame(width: cellSize, height: cellSize)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2.5)
                                                .stroke(Color.primary.opacity(hovered == day ? 0.55 : 0), lineWidth: 1)
                                        )
                                        .onHover { inside in
                                            if inside {
                                                hovered = day
                                            } else if hovered == day {
                                                hovered = nil
                                            }
                                        }
                                        .accessibilityLabel(accessibilityLabel(for: day))
                                }
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 9, height: 9)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func weekdayLabel(_ row: Int) -> String {
        switch row {
        case 1: return "M"
        case 3: return "W"
        case 5: return "F"
        default: return ""
        }
    }

    private func color(for day: HeatmapDay) -> Color {
        let level = DashboardInsights.intensity(forWordCount: day.wordCount, busiest: busiest)
        return colorForLevel(level)
    }

    private func colorForLevel(_ level: Int) -> Color {
        let base = Color.accentColor
        switch level {
        case 0: return Color.primary.opacity(0.06)
        case 1: return base.opacity(0.22)
        case 2: return base.opacity(0.42)
        case 3: return base.opacity(0.68)
        default: return base.opacity(0.95)
        }
    }

    private func accessibilityLabel(for day: HeatmapDay) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = formatter.string(from: day.date)
        if day.isEmpty { return "\(date), no dictation" }
        return "\(date), \(day.wordCount) words in \(day.sessionCount) sessions"
    }
}

// MARK: - Speaking rhythm card

struct SpeakingRhythmCard: View {
    let historyDates: [Date]

    private var buckets: [Int] { DashboardInsights.hourlyRhythm(historyDates: historyDates) }
    private var peaks: [(hour: Int, words: Int)] { DashboardInsights.peakHours(buckets) }
    private var busiest: Int { buckets.max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("When you dictate")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("Last 24-hour rhythm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if historyDates.isEmpty {
                Text("Dictate a few times and your peak hours will appear here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 70)
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        let value = buckets[hour]
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(barColor(hour: hour))
                                .frame(height: barHeight(value))
                            // Label only a few hours to keep it readable at 960pt.
                            Text(hourLabelIfNeeded(hour))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(height: 9)
                        }
                        .frame(maxWidth: .infinity)
                        .help("\(DashboardInsights.hourLabel(hour)) — \(value) word\(value == 1 ? "" : "s")")
                    }
                }
                .frame(height: 88)
            }

            if !peaks.isEmpty {
                HStack(spacing: 8) {
                    Text("Peak:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(Array(peaks.enumerated()), id: \.offset) { _, peak in
                        Text(DashboardInsights.hourLabel(peak.hour))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.15))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func barHeight(_ value: Int) -> CGFloat {
        guard busiest > 0, value > 0 else { return 2 }
        let ratio = Double(value) / Double(busiest)
        return max(3, CGFloat(ratio) * 64)
    }

    private func barColor(hour: Int) -> Color {
        peaks.contains { $0.hour == hour } ? Color.accentColor : Color.accentColor.opacity(0.45)
    }

    private func hourLabelIfNeeded(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 6: return "6a"
        case 12: return "12p"
        case 18: return "6p"
        default: return ""
        }
    }
}
// MARK: - Section container

/// Stacks the two insight cards under the usage graph, side by side when the
/// dashboard window is wide enough and stacked when it is not.
struct DashboardInsightsSection: View {
    let dailyStats: [String: DailyStats]
    let historyDates: [Date]

    @State private var stacked = false

    var body: some View {
        Group {
            if stacked {
                VStack(spacing: 16) {
                    ConsistencyHeatmapCard(dailyStats: dailyStats, historyDates: historyDates)
                    SpeakingRhythmCard(historyDates: historyDates)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    ConsistencyHeatmapCard(dailyStats: dailyStats, historyDates: historyDates)
                    SpeakingRhythmCard(historyDates: historyDates)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { stacked = proxy.size.width < 820 }
                    .onChange(of: proxy.size.width) { _, width in stacked = width < 820 }
            }
        )
    }
}
