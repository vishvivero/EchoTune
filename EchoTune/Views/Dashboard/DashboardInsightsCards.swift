//
//  DashboardInsightsCards.swift
//  EchoTune
//
//  26-Week Activity Contribution Heatmap & 24-Hour Peak Dictation Hours cards
//  for the Dashboard Home view (#18).
//

import SwiftUI

struct DashboardInsightsCardsView: View {
    @ObservedObject private var history = TranscriptionHistoryManager.shared
    @State private var hoveredDayText: String? = nil

    private let weeksCount = 26

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            activityHeatmapCard
            peakHoursCard
        }
    }

    // MARK: - 26-Week Contribution Heatmap

    private var activityHeatmapCard: some View {
        let grid = buildHeatmapGrid()
        let maxDailyWords = max(grid.flatMap { $0 }.map(\.words).max() ?? 0, 100)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictation Consistency")
                        .font(.headline)
                    Text(hoveredDayText ?? "Last 6 months of daily voice activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    ForEach([0.0, 0.25, 0.55, 0.85, 1.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(cellColor(fraction: level))
                            .frame(width: 9, height: 9)
                    }
                    Text("More")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                ForEach(0..<grid.count, id: \.self) { weekIdx in
                    VStack(spacing: 4) {
                        ForEach(grid[weekIdx]) { cell in
                            let fraction = cell.words == 0 ? 0.0 : max(0.22, Double(cell.words) / Double(maxDailyWords))
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(cellColor(fraction: min(1.0, fraction)))
                                .frame(width: 11, height: 11)
                                .onHover { inside in
                                    if inside {
                                        hoveredDayText = "\(cell.label): \(cell.words.formatted()) words (\(cell.sessions) session\(cell.sessions == 1 ? "" : "s"))"
                                    } else if hoveredDayText?.hasPrefix(cell.label) == true {
                                        hoveredDayText = nil
                                    }
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - 24-Hour Peak Productivity Card

    private var peakHoursCard: some View {
        let hourly = buildHourlyWordCounts()
        let maxHour = max(hourly.max() ?? 0, 20)
        let peakIdx = hourly.enumerated().max(by: { $0.element < $1.element })?.offset ?? 9
        let hasAny = hourly.contains { $0 > 0 }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Peak Flow Hours")
                        .font(.headline)
                    Text(hasAny ? "Sharpest window around \(formatHour(peakIdx))" : "24-hour speaking rhythm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if hasAny {
                    Text(formatHour(peakIdx))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = hourly[hour]
                    let ratio = Double(count) / Double(maxHour)
                    let h = count == 0 ? 4.0 : max(7.0, CGFloat(ratio) * 76.0)
                    let isPeak = hasAny && hour == peakIdx

                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(isPeak ? Color.accentColor : Color.accentColor.opacity(count == 0 ? 0.14 : 0.42 + ratio * 0.45))
                            .frame(height: h)
                            .frame(maxWidth: .infinity)

                        if hour % 6 == 0 {
                            Text("\(hour)h")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        } else {
                            Color.clear.frame(height: 11)
                        }
                    }
                }
            }
            .frame(height: 92)
        }
        .padding(20)
        .frame(width: 280, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Data Aggregation

    private struct HeatmapCell: Identifiable {
        let id: String
        let label: String
        let words: Int
        let sessions: Int
    }

    private func buildHeatmapGrid() -> [[HeatmapCell]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: (words: Int, sessions: Int)] = [:]

        for item in history.transcriptions {
            let day = cal.startOfDay(for: item.date)
            let w = item.text.split(whereSeparator: \.isWhitespace).count
            let prev = byDay[day] ?? (0, 0)
            byDay[day] = (prev.words + w, prev.sessions + 1)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"

        let totalDays = weeksCount * 7
        guard let startDay = cal.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            return []
        }

        var columns: [[HeatmapCell]] = []
        for w in 0..<weeksCount {
            var col: [HeatmapCell] = []
            for d in 0..<7 {
                let offset = w * 7 + d
                let date = cal.date(byAdding: .day, value: offset, to: startDay) ?? today
                let bucket = byDay[date] ?? (0, 0)
                col.append(HeatmapCell(
                    id: "\(w)-\(d)",
                    label: formatter.string(from: date),
                    words: bucket.words,
                    sessions: bucket.sessions
                ))
            }
            columns.append(col)
        }
        return columns
    }

    private func buildHourlyWordCounts() -> [Int] {
        var counts = Array(repeating: 0, count: 24)
        let cal = Calendar.current
        for item in history.transcriptions {
            let hour = cal.component(.hour, from: item.date)
            if (0..<24).contains(hour) {
                counts[hour] += item.text.split(whereSeparator: \.isWhitespace).count
            }
        }
        return counts
    }

    private func cellColor(fraction: Double) -> Color {
        if fraction <= 0.001 {
            return Color.primary.opacity(0.07)
        }
        return Color.green.opacity(0.24 + fraction * 0.72)
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}
