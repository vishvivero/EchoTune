//
//  TranscriptionStats.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Combine
import Foundation

class TranscriptionStats: ObservableObject {
    static let shared = TranscriptionStats()

    // Time metrics
    @Published var totalSpeakingTime: TimeInterval = 0
    @Published var estimatedTypingTime: TimeInterval = 0
    @Published var timeSaved: TimeInterval = 0
    
    // Count metrics
    @Published var wordsTranscribed: Int = 0
    @Published var sessionsCompleted: Int = 0
    @Published var averageWordsPerMinute: Double = 0
    @Published var averageWordsPerSession: Double = 0
    
    // Historical data for chart
    @Published var dailyUsage: [DailyUsage] = []
    
    // Calculate efficiency multiplier
    var efficiencyMultiplier: Double {
        guard totalSpeakingTime > 0 else { return 0 }
        return estimatedTypingTime / totalSpeakingTime
    }
    
    init() {
        loadStats()
    }
    
    func loadStats() {
        totalSpeakingTime = UserDefaults.standard.double(forKey: "totalSpeakingTime")
        estimatedTypingTime = UserDefaults.standard.double(forKey: "estimatedTypingTime")
        timeSaved = UserDefaults.standard.double(forKey: "timeSaved")
        wordsTranscribed = UserDefaults.standard.integer(forKey: "wordsTranscribed")
        sessionsCompleted = UserDefaults.standard.integer(forKey: "sessionsCompleted")
        averageWordsPerMinute = UserDefaults.standard.double(forKey: "averageWordsPerMinute")
        averageWordsPerSession = UserDefaults.standard.double(forKey: "averageWordsPerSession")
        // No persisted daily usage: leave dailyUsage empty so views show their empty states.
    }
    
    func saveStats() {
        UserDefaults.standard.set(totalSpeakingTime, forKey: "totalSpeakingTime")
        UserDefaults.standard.set(estimatedTypingTime, forKey: "estimatedTypingTime")
        UserDefaults.standard.set(timeSaved, forKey: "timeSaved")
        UserDefaults.standard.set(wordsTranscribed, forKey: "wordsTranscribed")
        UserDefaults.standard.set(sessionsCompleted, forKey: "sessionsCompleted")
        UserDefaults.standard.set(averageWordsPerMinute, forKey: "averageWordsPerMinute")
        UserDefaults.standard.set(averageWordsPerSession, forKey: "averageWordsPerSession")
    }
    
    func recordTranscription(duration: TimeInterval, wordCount: Int) {
        // Update total speaking time
        totalSpeakingTime += duration
        
        // Estimate typing time (assume 40 WPM average typing speed)
        let typingTimeForThisSession = Double(wordCount) / 40.0 * 60.0
        estimatedTypingTime += typingTimeForThisSession
        
        // Calculate time saved
        timeSaved = estimatedTypingTime - totalSpeakingTime
        
        // Update word count
        wordsTranscribed += wordCount
        
        // Update session count
        sessionsCompleted += 1
        
        // Update averages
        if totalSpeakingTime > 0 {
            averageWordsPerMinute = Double(wordsTranscribed) / (totalSpeakingTime / 60.0)
        }
        
        if sessionsCompleted > 0 {
            averageWordsPerSession = Double(wordsTranscribed) / Double(sessionsCompleted)
        }
        
        // Update daily usage
        updateDailyUsage(wordCount: wordCount)
        
        // Save stats
        saveStats()
    }
    
    private func updateDailyUsage(wordCount: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let index = dailyUsage.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            dailyUsage[index].wordCount += wordCount
            dailyUsage[index].sessionCount += 1
        } else {
            dailyUsage.append(DailyUsage(date: today, wordCount: wordCount, sessionCount: 1))
        }
        
        // Keep only last 30 days
        if dailyUsage.count > 30 {
            dailyUsage = Array(dailyUsage.suffix(30))
        }
    }
    
}

struct DailyUsage: Identifiable {
    let id = UUID()
    let date: Date
    var wordCount: Int
    var sessionCount: Int
}







