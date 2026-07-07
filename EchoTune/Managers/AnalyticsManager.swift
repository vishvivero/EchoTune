//
//  AnalyticsManager.swift
//  EchoTune
//
//  Phase 5: Usage Statistics and Analytics
//

import Foundation
import Combine

// MARK: - Usage Statistics Model

struct UsageStatistics: Codable {
    var totalTranscriptions: Int = 0
    var totalWords: Int = 0
    var totalRecordingTime: TimeInterval = 0
    var averageTranscriptionTime: TimeInterval = 0
    var errorCount: Int = 0
    var lastUsedDate: Date?
    var firstUsedDate: Date?
    var dailyStats: [String: DailyStats] = [:]
    var errorBreakdown: [String: Int] = [:]

    var averageWordsPerTranscription: Int {
        guard totalTranscriptions > 0 else { return 0 }
        return totalWords / totalTranscriptions
    }

    var averageRecordingDuration: TimeInterval {
        guard totalTranscriptions > 0 else { return 0 }
        return totalRecordingTime / Double(totalTranscriptions)
    }

    var successRate: Double {
        guard (totalTranscriptions + errorCount) > 0 else { return 0 }
        return Double(totalTranscriptions) / Double(totalTranscriptions + errorCount)
    }
}

struct DailyStats: Codable {
    var transcriptionCount: Int = 0
    var wordCount: Int = 0
    var recordingTime: TimeInterval = 0
    var errorCount: Int = 0
}

// MARK: - Analytics Manager

class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    @Published private(set) var statistics = UsageStatistics()

    private let statsKey = "usageStatistics"
    private let dateFormatter: DateFormatter

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        loadStatistics()
        debugLog("✓ AnalyticsManager initialized")
        printSummary()
    }

    // MARK: - Recording Events

    func recordTranscription(
        duration: TimeInterval,
        wordCount: Int,
        transcriptionTime: TimeInterval
    ) {
        statistics.totalTranscriptions += 1
        statistics.totalWords += wordCount
        statistics.totalRecordingTime += duration
        statistics.lastUsedDate = Date()

        if statistics.firstUsedDate == nil {
            statistics.firstUsedDate = Date()
        }

        // Update average transcription time (running average)
        let oldAvg = statistics.averageTranscriptionTime
        let count = Double(statistics.totalTranscriptions)
        statistics.averageTranscriptionTime = ((oldAvg * (count - 1)) + transcriptionTime) / count

        // Update daily stats
        let today = dateFormatter.string(from: Date())
        var dailyStat = statistics.dailyStats[today] ?? DailyStats()
        dailyStat.transcriptionCount += 1
        dailyStat.wordCount += wordCount
        dailyStat.recordingTime += duration
        statistics.dailyStats[today] = dailyStat

        saveStatistics()

        debugLog("📊 Recorded transcription: \(wordCount) words, \(String(format: "%.1f", duration))s")
    }

    func recordError(type: String, context: String = "") {
        statistics.errorCount += 1

        // Update error breakdown
        statistics.errorBreakdown[type, default: 0] += 1

        // Update daily stats
        let today = dateFormatter.string(from: Date())
        var dailyStat = statistics.dailyStats[today] ?? DailyStats()
        dailyStat.errorCount += 1
        statistics.dailyStats[today] = dailyStat

        saveStatistics()

        debugLog("📊 Recorded error: \(type)")
    }

    // MARK: - Statistics Queries

    func getStatistics() -> UsageStatistics {
        return statistics
    }

    func getDailyStats(for date: Date) -> DailyStats? {
        let dateKey = dateFormatter.string(from: date)
        return statistics.dailyStats[dateKey]
    }

    func getWeeklyStats() -> [DailyStats] {
        let calendar = Calendar.current
        let today = Date()

        var weekStats: [DailyStats] = []

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateKey = dateFormatter.string(from: date)
                weekStats.append(statistics.dailyStats[dateKey] ?? DailyStats())
            }
        }

        return weekStats.reversed()
    }

    func getMonthlyStats() -> [DailyStats] {
        let calendar = Calendar.current
        let today = Date()

        var monthStats: [DailyStats] = []

        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateKey = dateFormatter.string(from: date)
                monthStats.append(statistics.dailyStats[dateKey] ?? DailyStats())
            }
        }

        return monthStats.reversed()
    }

    func getTotalUsageDays() -> Int {
        return statistics.dailyStats.count
    }

    func getTopErrors() -> [(String, Int)] {
        return statistics.errorBreakdown
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Data Management

    func resetStatistics() {
        statistics = UsageStatistics()
        saveStatistics()
        debugLog("📊 Statistics reset")
    }

    func exportStatistics() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(statistics)
            debugLog("📊 Statistics exported (\(data.count) bytes)")
            return data
        } catch {
            debugLog("❌ Failed to export statistics: \(error)")
            return nil
        }
    }

    func exportStatisticsAsCSV() -> String {
        var csv = "Date,Transcriptions,Words,Recording Time (s),Errors\n"

        let sortedDates = statistics.dailyStats.keys.sorted()

        for dateKey in sortedDates {
            if let stats = statistics.dailyStats[dateKey] {
                csv += "\(dateKey),"
                csv += "\(stats.transcriptionCount),"
                csv += "\(stats.wordCount),"
                csv += "\(String(format: "%.1f", stats.recordingTime)),"
                csv += "\(stats.errorCount)\n"
            }
        }

        debugLog("📊 Statistics exported as CSV (\(csv.count) chars)")
        return csv
    }

    // MARK: - Storage

    private func saveStatistics() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(statistics)

            if let dataString = String(data: data, encoding: .utf8) {
                UserDefaults.standard.set(dataString, forKey: statsKey)
            }
        } catch {
            debugLog("❌ Failed to save statistics: \(error)")
        }
    }

    private func loadStatistics() {
        guard let dataString = UserDefaults.standard.string(forKey: statsKey),
              let data = dataString.data(using: .utf8) else {
            debugLog("📊 No saved statistics found")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            statistics = try decoder.decode(UsageStatistics.self, from: data)
            debugLog("✓ Statistics loaded")
        } catch {
            debugLog("❌ Failed to load statistics: \(error)")
        }
    }

    // MARK: - Helpers

    private func printSummary() {
        debugLog("📊 Statistics Summary:")
        debugLog("   Total transcriptions: \(statistics.totalTranscriptions)")
        debugLog("   Total words: \(statistics.totalWords)")
        debugLog("   Total recording time: \(String(format: "%.1f", statistics.totalRecordingTime))s")
        debugLog("   Average words/transcription: \(statistics.averageWordsPerTranscription)")
        debugLog("   Success rate: \(String(format: "%.1f%%", statistics.successRate * 100))")
        debugLog("   Total errors: \(statistics.errorCount)")
        debugLog("   Days used: \(getTotalUsageDays())")
    }

    func printDetailedReport() {
        debugLog("\n📊 Detailed Analytics Report")
        debugLog("=" * 60)

        debugLog("\nOverall Statistics:")
        debugLog("  Total Transcriptions: \(statistics.totalTranscriptions)")
        debugLog("  Total Words: \(statistics.totalWords)")
        debugLog("  Total Recording Time: \(formatDuration(statistics.totalRecordingTime))")
        debugLog("  Average Transcription Time: \(String(format: "%.2f", statistics.averageTranscriptionTime))s")
        debugLog("  Average Words per Transcription: \(statistics.averageWordsPerTranscription)")
        debugLog("  Average Recording Duration: \(String(format: "%.1f", statistics.averageRecordingDuration))s")
        debugLog("  Success Rate: \(String(format: "%.1f%%", statistics.successRate * 100))")
        debugLog("  Total Errors: \(statistics.errorCount)")
        debugLog("  Days Used: \(getTotalUsageDays())")

        if let firstUsed = statistics.firstUsedDate {
            debugLog("  First Used: \(dateFormatter.string(from: firstUsed))")
        }

        if let lastUsed = statistics.lastUsedDate {
            debugLog("  Last Used: \(dateFormatter.string(from: lastUsed))")
        }

        // Top errors
        let topErrors = getTopErrors()
        if !topErrors.isEmpty {
            debugLog("\nTop Errors:")
            for (i, (errorType, count)) in topErrors.enumerated() {
                debugLog("  \(i + 1). \(errorType): \(count) occurrences")
            }
        }

        // Weekly stats
        debugLog("\nLast 7 Days:")
        let weekStats = getWeeklyStats()
        let calendar = Calendar.current
        for (i, stats) in weekStats.enumerated() {
            if let date = calendar.date(byAdding: .day, value: -(6 - i), to: Date()) {
                let dateStr = dateFormatter.string(from: date)
                debugLog("  \(dateStr): \(stats.transcriptionCount) transcriptions, \(stats.wordCount) words")
            }
        }

        debugLog("=" * 60)
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

// MARK: - String Repeat Extension

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
