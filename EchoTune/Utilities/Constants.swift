//
//  Constants.swift
//  EchoTune
//
//  Phase 1: Application Constants
//

import Combine
import Foundation

enum Constants {
    // App Info
    static let appName = "EchoTune"
    static let appVersion = "1.0.0"
    static let buildNumber = "1"

    // URLs
    static let websiteURL = "https://echotune.app"
    static let purchaseURL = "https://echotune.app/purchase"
    static let supportURL = "https://echotune.app/support"
    static let privacyPolicyURL = "https://echotune.app/privacy"
    static let documentationURL = "https://echotune.app/docs"

    // Trial
    static let trialDurationDays = 7
    static let trialTranscriptionLimit = 5 // Per day in limited mode

    // License
    static let licenseKeyFormat = "^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$"

    // Performance
    static let maxRecordingDurationSeconds: TimeInterval = 300 // 5 minutes
    static let audioSampleRate: Double = 16000 // 16kHz for Whisper

    // Models
    enum Models {
        static let fast = ("tiny.en", 27)
        static let balanced = ("base.en", 140)
        static let accurate = ("small.en", 550)
    }

    // UserDefaults Keys
    enum UserDefaultsKeys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let trialStartDate = "trialStartDate"
        static let totalTranscriptions = "totalTranscriptions"
        static let totalWordsTranscribed = "totalWordsTranscribed"
        static let lastModelUsed = "lastModelUsed"
    }

    // Keychain Keys
    enum KeychainKeys {
        static let licenseKey = "licenseKey"
        static let deviceFingerprint = "deviceFingerprint"
    }

    // Notifications
    enum NotificationNames {
        static let recordingStateChanged = "recordingStateChanged"
        static let licenseStatusChanged = "licenseStatusChanged"
        static let modelLoadingProgress = "modelLoadingProgress"
    }
}
