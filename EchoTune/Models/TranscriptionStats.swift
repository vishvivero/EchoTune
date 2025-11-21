//
//  TranscriptionStats.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Combine
import Foundation

class TranscriptionStats: ObservableObject {
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
        // In a real app, we would load from persistent storage
        // For now, we'll use sample data
        totalSpeakingTime = UserDefaults.standard.double(forKey: "totalSpeakingTime")
        estimatedTypingTime = UserDefaults.standard.double(forKey: "estimatedTypingTime")
        timeSaved = UserDefaults.standard.double(forKey: "timeSaved")
        wordsTranscribed = UserDefaults.standard.integer(forKey: "wordsTranscribed")
        sessionsCompleted = UserDefaults.standard.integer(forKey: "sessionsCompleted")
        averageWordsPerMinute = UserDefaults.standard.double(forKey: "averageWordsPerMinute")
        averageWordsPerSession = UserDefaults.standard.double(forKey: "averageWordsPerSession")
        
        // Generate sample data for chart if none exists
        if dailyUsage.isEmpty {
            generateSampleData()
        }
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
    
    private func generateSampleData() {
        // Generate sample data for the last 30 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        dailyUsage = (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            
            // Generate random data, with more recent days having higher usage
            let recencyFactor = Double(30 - dayOffset) / 30.0
            let randomFactor = Double.random(in: 0.5...1.5)
            let wordCount = Int(recencyFactor * randomFactor * 100)
            let sessionCount = max(1, Int(recencyFactor * randomFactor * 3))
            
            return DailyUsage(date: date, wordCount: wordCount, sessionCount: sessionCount)
        }.reversed()
    }
}

struct DailyUsage: Identifiable {
    let id = UUID()
    let date: Date
    var wordCount: Int
    var sessionCount: Int
}







