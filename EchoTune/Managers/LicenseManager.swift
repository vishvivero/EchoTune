//
//  LicenseManager.swift
//  EchoTune
//
//  Phase 4: License Activation and Management
//

import Foundation
import Security
import AppKit

@Observable
class LicenseManager {
    static let shared = LicenseManager()

    #if APPSTORE
    // For App Store builds, we also check StoreKit purchases
    private let storeKit = StoreKitManager.shared
    #endif

    // State
    var isLicensed = false
    var licenseInfo: LicenseInfo?
    var trialExpiryDate: Date
    var isTrialExpired: Bool {
        Date() > trialExpiryDate
    }
    var trialDaysRemaining: Int {
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: trialExpiryDate).day ?? 0
        return max(0, remaining)
    }

    // Storage
    private let serviceName = "com.echotune.app"
    private let trialDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private init() {
        // Initialize trial period ONLY after onboarding is complete.
        // This prevents the trial clock from ticking during first-launch setup.
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if let savedTrialStart = UserDefaults.standard.object(forKey: "trialStartDate") as? Date {
            // Trial was already started (user completed onboarding previously)
            trialExpiryDate = savedTrialStart.addingTimeInterval(trialDuration)
        } else if hasCompletedOnboarding {
            // Edge case: onboarding done but no trial date (shouldn't happen, but be safe)
            let startDate = Date()
            UserDefaults.standard.set(startDate, forKey: "trialStartDate")
            trialExpiryDate = startDate.addingTimeInterval(trialDuration)
        } else {
            // Onboarding not complete yet — don't start the trial.
            // Set a far-future expiry so trial checks pass during onboarding.
            trialExpiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
        }

        // Check for existing license
        validateStoredLicense()

        print("✓ LicenseManager initialized")
        print("📅 Trial days remaining: \(trialDaysRemaining)")
    }

    /// Called when onboarding completes to actually start the trial clock.
    /// If the trial was already started, this is a no-op.
    func startTrialIfNeeded() {
        guard UserDefaults.standard.object(forKey: "trialStartDate") == nil else { return }
        let startDate = Date()
        UserDefaults.standard.set(startDate, forKey: "trialStartDate")
        trialExpiryDate = startDate.addingTimeInterval(trialDuration)
        print("🎯 Trial started after onboarding: \(trialDaysRemaining) days remaining")
    }

    // MARK: - License Validation

    private func validateStoredLicense() {
        #if APPSTORE
        // App Store builds: Don't check keychain (no license keys allowed)
        print("⏳ No stored license found (App Store build)")
        #else
        // Direct sale builds: Check keychain for license
        guard let _ = getFromKeychain("licenseKey"),
              let licenseDataString = getFromKeychain("licenseData"),
              let licenseData = licenseDataString.data(using: .utf8),
              let storedInfo = try? JSONDecoder().decode(LicenseInfo.self, from: licenseData) else {
            print("⏳ No stored license found")
            return
        }

        // Validate license
        if storedInfo.isValid {
            isLicensed = true
            licenseInfo = storedInfo
            print("✓ Valid license found: \(storedInfo.tier.rawValue)")
        } else {
            print("❌ Stored license expired or invalid")
            clearStoredLicense()
        }
        #endif
    }

    // MARK: - License Activation

    func activateLicense(_ key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        #if APPSTORE
        // App Store builds: License keys not supported
        completion(.failure(NSError(domain: "LicenseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "License keys are not supported in App Store builds. Please purchase via In-App Purchase."])))
        return
        #else
        // Validate format
        guard isValidLicenseFormat(key) else {
            completion(.failure(LicenseError.invalidFormat))
            return
        }

        print("🔑 Activating license: \(maskLicenseKey(key))")

        // For demo: simple validation
        // In production, you'd call Keygen or your license server
        if key.hasPrefix("DEMO-") {
            // Demo license for testing
            let info = LicenseInfo(
                key: key,
                tier: .pro,
                activatedOn: Date(),
                expiryDate: nil, // Lifetime
                deviceFingerprint: getDeviceFingerprint()
            )

            storeLicense(info)
            isLicensed = true
            licenseInfo = info

            completion(.success(info))
            print("✓ Demo license activated")
        } else {
            // Real validation (would be async API call)
            validateLicenseWithServer(key: key, completion: completion)
        }
        #endif
    }

    #if !APPSTORE
    private func validateLicenseWithServer(key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        // Simulate API call
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // In production, call Keygen API here
            // For now, accept specific format keys

            if key.count == 23 && key.filter({ $0 == "-" }).count == 3 {
                let info = LicenseInfo(
                    key: key,
                    tier: .individual,
                    activatedOn: Date(),
                    expiryDate: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year
                    deviceFingerprint: self.getDeviceFingerprint()
                )

                DispatchQueue.main.async {
                    self.storeLicense(info)
                    self.isLicensed = true
                    self.licenseInfo = info
                    completion(.success(info))
                    print("✓ License activated: \(info.tier.rawValue)")
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(LicenseError.activationFailed))
                    print("❌ License activation failed")
                }
            }
        }
    }
    #endif

    // MARK: - License Deactivation

    func deactivateLicense(completion: @escaping (Result<Void, Error>) -> Void) {
        #if APPSTORE
        // App Store builds: License keys not supported
        completion(.failure(NSError(domain: "LicenseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "License deactivation is not supported in App Store builds."])))
        return
        #else
        guard let _ = licenseInfo else {
            completion(.failure(LicenseError.noLicenseFound))
            return
        }

        print("🔓 Deactivating license")

        // In production, call API to deactivate on server
        // For now, just remove local storage

        clearStoredLicense()
        isLicensed = false
        licenseInfo = nil

        completion(.success(()))
        print("✓ License deactivated")
        #endif
    }

    // MARK: - Storage

    #if !APPSTORE
    private func storeLicense(_ info: LicenseInfo) {
        do {
            // Store key
            saveToKeychain("licenseKey", value: info.key)

            // Store full info
            let encoder = JSONEncoder()
            let data = try encoder.encode(info)
            if let dataString = String(data: data, encoding: .utf8) {
                saveToKeychain("licenseData", value: dataString)
                print("✓ License stored securely")
            }
        } catch {
            print("❌ Failed to store license: \(error)")
        }
    }

    private func clearStoredLicense() {
        deleteFromKeychain("licenseKey")
        deleteFromKeychain("licenseData")
        print("🗑️ License removed from storage")
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(_ key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ Keychain save failed for \(key): \(status)")
        }
    }

    private func getFromKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Handle different error cases
        if status == errSecUserCanceled {
            print("ℹ️ User canceled keychain access for \(key) - this is normal, continuing without license")
            return nil
        } else if status == errSecAuthFailed {
            print("ℹ️ Keychain auth failed for \(key) - continuing without license")
            return nil
        } else if status == errSecItemNotFound {
            // Item doesn't exist - this is normal for new installations
            return nil
        } else if status != errSecSuccess {
            print("ℹ️ Keychain access status \(status) for \(key) - continuing without license")
            return nil
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func deleteFromKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
    #endif

    // MARK: - Validation Helpers

    // Available in all builds for display purposes
    func maskLicenseKey(_ key: String) -> String {
        let parts = key.split(separator: "-")
        if parts.count == 4 {
            return "\(parts[0])-****-****-\(parts[3])"
        }
        return "****-****-****-****"
    }

    #if !APPSTORE
    private func isValidLicenseFormat(_ key: String) -> Bool {
        // Format: XXXXX-XXXXX-XXXXX-XXXXX
        let pattern = "^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    private func getDeviceFingerprint() -> String {
        // Get hardware UUID
        let service = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, service)
        defer { IOObjectRelease(platformExpert) }

        guard let uuid = IORegistryEntryCreateCFProperty(
            platformExpert,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as? String else {
            return UUID().uuidString
        }

        return uuid
    }
    #endif

    // MARK: - Trial Management

    /// Check if user has Pro features (either via license key or App Store purchase)
    var isPro: Bool {
        #if APPSTORE
            // App Store builds: ONLY check StoreKit IAP (no license keys allowed)
            return storeKit.isProUnlocked
        #else
            // Direct sale builds: Check license keys
            return isLicensed
        #endif
    }

    func canUsePremiumFeatures() -> Bool {
        #if APPSTORE
            // App Store builds: ONLY check StoreKit IAP + trial
            return storeKit.isProUnlocked || !isTrialExpired
        #else
            // Direct sale builds: Check license keys + trial
            return isLicensed || !isTrialExpired
        #endif
    }

    func getRemainingFeatureUses() -> Int? {
        if isPro {
            return nil // Unlimited
        }

        if isTrialExpired {
            return 0
        }

        // Trial users get limited uses
        let usedCount = UserDefaults.standard.integer(forKey: "trialUsageCount")
        let limit = 50 // 50 transcriptions during trial
        return max(0, limit - usedCount)
    }

    func incrementTrialUsage() {
        guard !isPro else { return }

        let current = UserDefaults.standard.integer(forKey: "trialUsageCount")
        UserDefaults.standard.set(current + 1, forKey: "trialUsageCount")
    }

    // MARK: - Purchase

    func openPurchaseURL() {
        if let url = URL(string: "https://echotune.app/purchase") {
            NSWorkspace.shared.open(url)
        }
    }
}
