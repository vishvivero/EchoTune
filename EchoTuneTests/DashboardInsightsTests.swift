import Foundation
import Testing
@testable import EchoTune

/// ET-763 · consistency heatmap + speaking-rhythm maths.
struct DashboardInsightsTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 1 // Sunday, matching the GitHub layout
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    private func key(_ d: Date) -> String {
        DashboardInsights.dayKeyFormatter(calendar: calendar).string(from: d)
    }

    // MARK: Heatmap shape

    @Test func heatmapIsTwentySixWeeksOfSevenDays() {
        let grid = DashboardInsights.heatmap(
            today: date(2026, 11, 23),
            dailyStats: [:],
            calendar: calendar
        )
        #expect(grid.count == 26, "26-week window")
        #expect(grid.allSatisfy { $0.count == 7 }, "every column is a full week")
    }

    @Test func heatmapEndsOnTheWeekContainingToday() throws {
        let today = date(2026, 11, 23) // Monday
        let grid = DashboardInsights.heatmap(today: today, dailyStats: [:], calendar: calendar)
        let lastWeek = try #require(grid.last)
        let containsToday = lastWeek.contains { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(containsToday, "today must appear in the final column")
    }

    @Test func heatmapColumnsAreSundayFirst() {
        let grid = DashboardInsights.heatmap(
            today: date(2026, 11, 23),
            dailyStats: [:],
            calendar: calendar
        )
        for week in grid {
            for day in week {
                _ = day // shape check below
            }
            #expect(calendar.component(.weekday, from: week[0].date) == 1, "column starts on Sunday")
        }
    }

    @Test func futureDaysAreEmpty() {
        let today = date(2026, 11, 23)
        let grid = DashboardInsights.heatmap(today: today, dailyStats: [:], calendar: calendar)
        let future = grid.flatMap { $0 }.filter { $0.date > calendar.startOfDay(for: today) }
        #expect(future.allSatisfy { $0.isEmpty }, "days after today carry no data")
    }

    // MARK: Heatmap data mapping

    @Test func wordCountsComeFromDailyStats() throws {
        let today = date(2026, 11, 23)
        let target = date(2026, 11, 20)
        let stats = [key(target): DailyStats(transcriptionCount: 4, wordCount: 812, recordingTime: 90, errorCount: 0)]

        let grid = DashboardInsights.heatmap(today: today, dailyStats: stats, calendar: calendar)
        let cell = try #require(grid.flatMap { $0 }.first { calendar.isDate($0.date, inSameDayAs: target) })
        #expect(cell.wordCount == 812)
        #expect(cell.sessionCount == 4)
    }

    @Test func sessionCountFallsBackToHistoryDates() throws {
        let today = date(2026, 11, 23)
        let day = date(2026, 11, 21, 9)
        let grid = DashboardInsights.heatmap(
            today: today,
            dailyStats: [:],
            historyDates: [day, day.addingTimeInterval(3600), day.addingTimeInterval(7200)],
            calendar: calendar
        )
        let cell = try #require(grid.flatMap { $0 }.first { calendar.isDate($0.date, inSameDayAs: day) })
        #expect(cell.sessionCount == 3)
    }

    // MARK: Intensity buckets

    @Test func intensityScalesWithTheBusiestDay() {
        #expect(DashboardInsights.intensity(forWordCount: 0, busiest: 100) == 0)
        #expect(DashboardInsights.intensity(forWordCount: 10, busiest: 100) == 1)
        #expect(DashboardInsights.intensity(forWordCount: 30, busiest: 100) == 2)
        #expect(DashboardInsights.intensity(forWordCount: 50, busiest: 100) == 3)
        #expect(DashboardInsights.intensity(forWordCount: 100, busiest: 100) == 4)
        #expect(DashboardInsights.intensity(forWordCount: 5, busiest: 0) == 0, "no data at all")
    }

    // MARK: Rhythm

    @Test func hourlyRhythmBucketsByHourOfDay() {
        let dates = [
            date(2026, 11, 20, 9),
            date(2026, 11, 21, 9),
            date(2026, 11, 22, 14)
        ]
        let buckets = DashboardInsights.hourlyRhythm(historyDates: dates, calendar: calendar)
        #expect(buckets.count == 24)
        #expect(buckets[9] == 2)
        #expect(buckets[14] == 1)
        #expect(buckets[3] == 0)
    }

    @Test func hourlyRhythmUsesWordCountsWhenGiven() {
        let dates = [date(2026, 11, 20, 9), date(2026, 11, 21, 9)]
        let buckets = DashboardInsights.hourlyRhythm(
            historyDates: dates,
            wordCounts: [100, 250],
            calendar: calendar
        )
        #expect(buckets[9] == 350)
    }

    @Test func peakHoursAreSortedAndLimited() {
        var buckets = [Int](repeating: 0, count: 24)
        buckets[8] = 10
        buckets[17] = 90
        buckets[13] = 40
        let peaks = DashboardInsights.peakHours(buckets, limit: 2)
        #expect(peaks.count == 2)
        #expect(peaks[0].hour == 17)
        #expect(peaks[1].hour == 13)
    }

    @Test func peakHoursIgnoresEmptyBuckets() {
        let peaks = DashboardInsights.peakHours([Int](repeating: 0, count: 24))
        #expect(peaks.isEmpty)
    }

    // MARK: Labels

    @Test func hourLabelsReadLikeAClock() {
        #expect(DashboardInsights.hourLabel(0) == "12 AM")
        #expect(DashboardInsights.hourLabel(9) == "9 AM")
        #expect(DashboardInsights.hourLabel(12) == "12 PM")
        #expect(DashboardInsights.hourLabel(13) == "1 PM")
        #expect(DashboardInsights.hourLabel(23) == "11 PM")
        #expect(DashboardInsights.hourLabel(25) == "1 AM", "hours wrap rather than crash")
    }

    @Test func emptyStateIsSafe() {
        let grid = DashboardInsights.heatmap(today: date(2026, 11, 23), dailyStats: [:], calendar: calendar)
        #expect(grid.flatMap { $0 }.allSatisfy { $0.isEmpty })
        #expect(DashboardInsights.hourlyRhythm(historyDates: [], calendar: calendar).allSatisfy { $0 == 0 })
    }
}
