//
//  UsageGraphView.swift
//  EchoTune
//

import SwiftUI

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
