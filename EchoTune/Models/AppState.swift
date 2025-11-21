//
//  AppState.swift
//  EchoTune
//
//  Phase 1: Application State Management
//

import Combine
import Foundation
import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()

    // Recording State
    @Published var recordingState: RecordingState = .idle

    // License State
    var isLicensed: Bool = false
    var licenseInfo: LicenseInfo?

    // Trial State
    var trialStartDate: Date
    var trialExpiryDate: Date
    var isTrialExpired: Bool {
        Date() > trialExpiryDate
    }
    var trialDaysRemaining: Int {
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: trialExpiryDate).day ?? 0
        return max(0, remaining)
    }

    // Model State
    var isModelLoaded: Bool = false
    var modelLoadingProgress: Double = 0.0

    // Permission State
    var hasMicrophonePermission: Bool = false
    var hasAccessibilityPermission: Bool = false

    // Statistics (for user)
    var totalTranscriptions: Int = 0
    var totalWordsTranscribed: Int = 0

    // Streak tracking
    @Published var currentStreak: Int = 0
    private var lastUsageDate: Date?
    private var streakDates: [Date] = []

    private init() {
        // Initialize trial period
        let savedTrialStart = UserDefaults.standard.object(forKey: "trialStartDate") as? Date
        let startDate = savedTrialStart ?? Date()

        // Initialize properties
        trialStartDate = startDate

        // Trial duration: 7 days
        let trialDuration: TimeInterval = 7 * 24 * 60 * 60
        trialExpiryDate = startDate.addingTimeInterval(trialDuration)

        // Save trial start if it's new
        if savedTrialStart == nil {
            UserDefaults.standard.set(startDate, forKey: "trialStartDate")
        }

        // Load statistics
        totalTranscriptions = UserDefaults.standard.integer(forKey: "totalTranscriptions")
        totalWordsTranscribed = UserDefaults.standard.integer(forKey: "totalWordsTranscribed")

        // Load streak data
        lastUsageDate = UserDefaults.standard.object(forKey: "lastUsageDate") as? Date
        if let savedDatesData = UserDefaults.standard.data(forKey: "streakDates"),
           let decoded = try? JSONDecoder().decode([Date].self, from: savedDatesData) {
            streakDates = decoded
        }

        // Calculate current streak
        currentStreak = calculateStreak()

        print("✓ AppState initialized - Trial days remaining: \(trialDaysRemaining)")
    }

    func incrementTranscriptionCount(wordCount: Int) {
        totalTranscriptions += 1
        totalWordsTranscribed += wordCount

        UserDefaults.standard.set(totalTranscriptions, forKey: "totalTranscriptions")
        UserDefaults.standard.set(totalWordsTranscribed, forKey: "totalWordsTranscribed")

        // Update streak
        updateStreak()
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if we've already recorded today
        if let lastDate = lastUsageDate {
            let lastDay = calendar.startOfDay(for: lastDate)

            // If already recorded today, don't add again
            if lastDay == today {
                return
            }
        }

        // Add today to streak dates
        if !streakDates.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
            streakDates.append(today)
            streakDates.sort()
        }

        lastUsageDate = Date()

        // Save to UserDefaults
        UserDefaults.standard.set(lastUsageDate, forKey: "lastUsageDate")
        if let encoded = try? JSONEncoder().encode(streakDates) {
            UserDefaults.standard.set(encoded, forKey: "streakDates")
        }

        // Recalculate streak
        currentStreak = calculateStreak()
    }

    private func calculateStreak() -> Int {
        guard !streakDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sortedDates = streakDates.sorted(by: >)

        // Check if the most recent date is today or yesterday
        guard let mostRecent = sortedDates.first else { return 0 }
        let daysDiff = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0

        // If more than 1 day has passed, streak is broken
        if daysDiff > 1 {
            return 0
        }

        // Count consecutive days backwards from most recent
        var streak = 1
        var currentDate = mostRecent

        for date in sortedDates.dropFirst() {
            let diff = calendar.dateComponents([.day], from: date, to: currentDate).day ?? 0

            if diff == 1 {
                streak += 1
                currentDate = date
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case loadingModel(String)  // String is the model name
    case recording
    case processing
    case error(String)

    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .loadingModel(let modelName):
            return "Loading \(modelName)..."
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var iconName: String {
        switch self {
        case .idle:
            return "mic.fill"
        case .loadingModel:
            return "arrow.down.circle.fill"
        case .recording:
            return "mic.circle.fill"
        case .processing:
            return "waveform.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .primary
        case .loadingModel:
            return .orange
        case .recording:
            return .red
        case .processing:
            return .blue
        case .error:
            return .orange
        }
    }
}
