//
//  StatisticsSettingsView.swift
//  EchoTune
//
//  Phase 5: Usage Statistics Dashboard
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

struct StatisticsSettingsView: View {
    @State private var analyticsManager = AnalyticsManager.shared
    @State private var statistics: UsageStatistics
    @State private var weeklyStats: [DailyStats]
    @State private var showExportDialog = false

    init() {
        let manager = AnalyticsManager.shared
        _statistics = State(initialValue: manager.getStatistics())
        _weeklyStats = State(initialValue: manager.getWeeklyStats())
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Track your voice dictation usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            // Overview Section
            overviewSection

            // Charts Section
            chartsSection

            // Details Section
            detailsSection

            // Actions Section
            actionsSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshStatistics()
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        Section("Overview") {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    StatCard(
                        title: "Transcriptions",
                        value: "\(statistics.totalTranscriptions)",
                        icon: "mic.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Total Words",
                        value: "\(statistics.totalWords)",
                        icon: "text.bubble.fill",
                        color: .green
                    )
                }

                HStack(spacing: 20) {
                    StatCard(
                        title: "Success Rate",
                        value: "\(Int(statistics.successRate * 100))%",
                        icon: "checkmark.circle.fill",
                        color: .purple
                    )

                    StatCard(
                        title: "Days Used",
                        value: "\(analyticsManager.getTotalUsageDays())",
                        icon: "calendar.fill",
                        color: .orange
                    )
                }
            }
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        Section("Last 7 Days") {
            VStack(alignment: .leading, spacing: 16) {
                // Transcriptions chart
                Text("Transcriptions per Day")
                    .font(.headline)

                if #available(macOS 13.0, *) {
                    Chart {
                        ForEach(0..<weeklyStats.count, id: \.self) { index in
                            BarMark(
                                x: .value("Day", dayLabel(for: index)),
                                y: .value("Count", weeklyStats[index].transcriptionCount)
                            )
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel()
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                } else {
                    // Fallback for older macOS versions
                    SimpleBarChart(data: weeklyStats.map { Double($0.transcriptionCount) })
                        .frame(height: 180)
                }

                Divider()

                // Words chart
                Text("Words per Day")
                    .font(.headline)

                if #available(macOS 13.0, *) {
                    Chart {
                        ForEach(0..<weeklyStats.count, id: \.self) { index in
                            BarMark(
                                x: .value("Day", dayLabel(for: index)),
                                y: .value("Words", weeklyStats[index].wordCount)
                            )
                            .foregroundStyle(Color.green.gradient)
                        }
                    }
                    .frame(height: 180)
                } else {
                    // Fallback for older macOS versions
                    SimpleBarChart(data: weeklyStats.map { Double($0.wordCount) })
                        .frame(height: 180)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section("Details") {
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(
                    label: "Average Words per Transcription",
                    value: "\(statistics.averageWordsPerTranscription)"
                )

                DetailRow(
                    label: "Average Recording Duration",
                    value: String(format: "%.1f seconds", statistics.averageRecordingDuration)
                )

                DetailRow(
                    label: "Average Transcription Time",
                    value: String(format: "%.2f seconds", statistics.averageTranscriptionTime)
                )

                DetailRow(
                    label: "Total Recording Time",
                    value: formatDuration(statistics.totalRecordingTime)
                )

                if statistics.errorCount > 0 {
                    Divider()

                    DetailRow(
                        label: "Total Errors",
                        value: "\(statistics.errorCount)",
                        valueColor: .red
                    )

                    // Top errors
                    let topErrors = analyticsManager.getTopErrors()
                    if !topErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Most Common Errors:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(topErrors, id: \.0) { error, count in
                                HStack {
                                    Text("• \(error)")
                                        .font(.caption)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                if let firstUsed = statistics.firstUsedDate {
                    Divider()

                    DetailRow(
                        label: "First Used",
                        value: formatDate(firstUsed)
                    )
                }

                if let lastUsed = statistics.lastUsedDate {
                    DetailRow(
                        label: "Last Used",
                        value: formatDate(lastUsed)
                    )
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section("Actions") {
            VStack(spacing: 12) {
                HStack {
                    Button("Export as JSON") {
                        exportJSON()
                    }
                    .buttonStyle(.bordered)

                    Button("Export as CSV") {
                        exportCSV()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }

                HStack {
                    Button("Reset Statistics") {
                        resetStatistics()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)

                    Spacer()
                }

                Text("Resetting will permanently delete all usage statistics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func refreshStatistics() {
        statistics = analyticsManager.getStatistics()
        weeklyStats = analyticsManager.getWeeklyStats()
    }

    private func exportJSON() {
        guard let data = analyticsManager.exportStatistics() else {
            print("Failed to export statistics")
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "echotune_statistics.json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try data.write(to: url)
                    print("✓ Statistics exported to \(url.path)")
                } catch {
                    print("❌ Failed to save: \(error)")
                }
            }
        }
    }

    private func exportCSV() {
        let csv = analyticsManager.exportStatisticsAsCSV()
        guard let data = csv.data(using: .utf8) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "echotune_statistics.csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try data.write(to: url)
                    print("✓ Statistics exported to \(url.path)")
                } catch {
                    print("❌ Failed to save: \(error)")
                }
            }
        }
    }

    private func resetStatistics() {
        let alert = NSAlert()
        alert.messageText = "Reset Statistics?"
        alert.informativeText = "This will permanently delete all usage statistics. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            analyticsManager.resetStatistics()
            refreshStatistics()
            print("✓ Statistics reset")
        }
    }

    // MARK: - Helpers

    private func dayLabel(for index: Int) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: -(6 - index), to: Date()) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
        .font(.body)
    }
}

// Simple bar chart fallback for older macOS versions
struct SimpleBarChart: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<data.count, id: \.self) { index in
                    let maxValue = data.max() ?? 1
                    let height = maxValue > 0 ? (data[index] / maxValue) * geometry.size.height * 0.9 : 0

                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: height)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StatisticsSettingsView()
        .frame(width: 600, height: 600)
}
