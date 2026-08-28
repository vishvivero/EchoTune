//
//  LicenseInfo.swift
//  EchoTune
//
//  Phase 1: License Model
//

import Combine
import Foundation

struct LicenseInfo: Codable {
    let key: String
    let tier: LicenseTier
    let activatedOn: Date
    let expiryDate: Date?
    let deviceFingerprint: String

    var isValid: Bool {
        if let expiry = expiryDate {
            return Date() < expiry
        }
        return true // No expiry = lifetime license
    }

    var isLifetime: Bool {
        expiryDate == nil
    }
}

// MARK: - License Tier

enum LicenseTier: String, Codable {
    case individual = "Individual"
    case pro = "Pro"

    var maxDevices: Int {
        switch self {
        case .individual: return 1
        case .pro: return 3
        }
    }

    var features: [String] {
        switch self {
        case .individual:
            return [
                "Unlimited transcriptions",
                "All models included",
                "One-time purchase for 1 Mac"
            ]
        case .pro:
            return [
                "Unlimited transcriptions",
                "All models included",
                "One-time purchase for up to 3 Macs"
            ]
        }
    }

    var price: String {
        switch self {
        case .individual: return "£29.99"
        case .pro: return "£49.99"
        }
    }
}

// MARK: - License Error

enum LicenseError: LocalizedError {
    case invalidFormat
    case noLicenseFound
    case activationFailed
    case serverUnreachable
    case alreadyActivated
    case deviceLimitReached
    case licenseExpired

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid license key format. Please check and try again."
        case .noLicenseFound:
            return "No license found on this device."
        case .activationFailed:
            return "License activation failed. Please check your key and try again."
        case .serverUnreachable:
            return "Unable to reach activation server. Please check your internet connection."
        case .alreadyActivated:
            return "This license is already activated on this device."
        case .deviceLimitReached:
            return "Device limit reached. Please deactivate another device first."
        case .licenseExpired:
            return "This license has expired."
        }
    }
}
