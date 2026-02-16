//
//  LicenseManager.swift
//  EchoTune
//
//  License Activation and Management — Polar.sh Integration
//

import Foundation
import Security
import AppKit

@Observable
class LicenseManager {
    static let shared = LicenseManager()

    #if APPSTORE
    private let storeKit = StoreKitManager.shared
    #endif

    // MARK: - Polar Configuration
    private let polarAPIBase = "https://api.polar.sh"
    private let polarAccessToken = "polar_oat_gKSmjJdhTjHuaDXCNumdcyMDuh7DSPcEVt8On0iQZPp"
    private let soloProductId = "f50d3be4-616c-40aa-9b66-a38a0b565d6f"
    private let polarOrganizationId = "fedfb5b9-01c8-4178-a1cb-90b3f0e1e1ae"

    // State
    var isLicensed = false
    var licenseInfo: LicenseInfo?
    var trialExpiryDate: Date
    var isActivating = false
    var activationError: String?

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
        // Initialize trial period
        if let savedTrialStart = UserDefaults.standard.object(forKey: "trialStartDate") as? Date {
            trialExpiryDate = savedTrialStart.addingTimeInterval(trialDuration)
        } else {
            let startDate = Date()
            UserDefaults.standard.set(startDate, forKey: "trialStartDate")
            trialExpiryDate = startDate.addingTimeInterval(trialDuration)
        }

        // Check for existing license
        validateStoredLicense()

        debugLog("✓ LicenseManager initialized (Polar.sh)")
        debugLog("📅 Trial days remaining: \(trialDaysRemaining)")
    }

    // MARK: - Stored License Validation

    private func validateStoredLicense() {
        #if APPSTORE
        debugLog("⏳ App Store build — no license key check")
        #else
        guard let _ = getFromKeychain("licenseKey"),
              let licenseDataString = getFromKeychain("licenseData"),
              let licenseData = licenseDataString.data(using: .utf8),
              let storedInfo = try? JSONDecoder().decode(LicenseInfo.self, from: licenseData) else {
            debugLog("⏳ No stored license found")
            return
        }

        if storedInfo.isValid {
            isLicensed = true
            licenseInfo = storedInfo
            debugLog("✓ Valid license found: \(storedInfo.tier.rawValue)")

            // Re-validate with Polar in background (don't block startup)
            Task {
                await revalidateWithPolar(key: storedInfo.key)
            }
        } else {
            debugLog("❌ Stored license expired or invalid")
            clearStoredLicense()
        }
        #endif
    }

    // MARK: - License Activation

    func activateLicense(_ key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        #if APPSTORE
        completion(.failure(NSError(domain: "LicenseManager", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "License keys are not supported in App Store builds."])))
        return
        #else
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            completion(.failure(LicenseError.invalidFormat))
            return
        }

        debugLog("🔑 Activating license: \(maskLicenseKey(trimmedKey))")
        isActivating = true
        activationError = nil

        #if DEBUG
        if trimmedKey.hasPrefix("DEMO-") {
            let info = LicenseInfo(
                key: trimmedKey,
                tier: .solo,
                activatedOn: Date(),
                expiryDate: nil,
                deviceFingerprint: getDeviceFingerprint(),
                polarLicenseId: nil,
                customerEmail: nil
            )
            storeLicense(info)
            isLicensed = true
            licenseInfo = info
            isActivating = false
            completion(.success(info))
            debugLog("✓ Demo license activated")
            return
        }
        #endif

        // Validate with Polar.sh
        validateWithPolar(key: trimmedKey, completion: completion)
        #endif
    }

    #if !APPSTORE
    private func validateWithPolar(key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        let endpoint = "\(polarAPIBase)/v1/license-keys/validate"

        guard let url = URL(string: endpoint) else {
            isActivating = false
            completion(.failure(LicenseError.serverUnreachable))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(polarAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "key": key,
            "organization_id": polarOrganizationId,
            "label": getDeviceFingerprint()
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            isActivating = false
            completion(.failure(LicenseError.activationFailed))
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isActivating = false

                if let error = error {
                    debugLog("❌ Polar API error: \(error.localizedDescription)")
                    self.activationError = "Could not reach license server. Check your internet connection."
                    completion(.failure(LicenseError.serverUnreachable))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      let data = data else {
                    self.activationError = "Invalid response from license server."
                    completion(.failure(LicenseError.activationFailed))
                    return
                }

                if httpResponse.statusCode == 404 || httpResponse.statusCode == 422 {
                    debugLog("❌ Polar: Invalid license key (HTTP \(httpResponse.statusCode))")
                    self.activationError = "Invalid license key. Please check and try again."
                    completion(.failure(LicenseError.invalidFormat))
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    debugLog("❌ Polar: HTTP \(httpResponse.statusCode)")
                    self.activationError = "License activation failed (HTTP \(httpResponse.statusCode))."
                    completion(.failure(LicenseError.activationFailed))
                    return
                }

                // Parse response
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.activationError = "Invalid response from license server."
                    completion(.failure(LicenseError.activationFailed))
                    return
                }

                let status = json["status"] as? String ?? ""

                if status == "revoked" {
                    debugLog("❌ Polar: License revoked")
                    self.activationError = "This license has been revoked."
                    completion(.failure(LicenseError.licenseRevoked))
                    return
                }

                if status != "granted" && status != "activated" {
                    debugLog("❌ Polar: Unexpected status '\(status)'")
                    self.activationError = "License is not active (status: \(status))."
                    completion(.failure(LicenseError.activationFailed))
                    return
                }

                // Parse expiry if present
                var expiryDate: Date?
                if let expiresAt = json["expires_at"] as? String {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    expiryDate = formatter.date(from: expiresAt)
                    if expiryDate == nil {
                        // Try without fractional seconds
                        formatter.formatOptions = [.withInternetDateTime]
                        expiryDate = formatter.date(from: expiresAt)
                    }
                }

                // Parse customer email
                var customerEmail: String?
                if let customer = json["customer"] as? [String: Any] {
                    customerEmail = customer["email"] as? String
                }

                let polarId = json["id"] as? String

                let info = LicenseInfo(
                    key: key,
                    tier: .solo,
                    activatedOn: Date(),
                    expiryDate: expiryDate,
                    deviceFingerprint: self.getDeviceFingerprint(),
                    polarLicenseId: polarId,
                    customerEmail: customerEmail
                )

                self.storeLicense(info)
                self.isLicensed = true
                self.licenseInfo = info

                debugLog("✓ License activated via Polar.sh")
                if let email = customerEmail {
                    debugLog("   Customer: \(email)")
                }

                // Register in referral system
                if let email = customerEmail {
                    Task {
                        await ReferralManager.shared.register(
                            email: email,
                            polarLicenseKey: key,
                            polarCustomerId: nil,
                            referredByCode: UserDefaults.standard.string(forKey: "pendingReferralCode"),
                            licenseExpiresAt: expiryDate
                        )
                        // Clear pending referral code after use
                        UserDefaults.standard.removeObject(forKey: "pendingReferralCode")
                    }
                }

                completion(.success(info))
            }
        }.resume()
    }

    /// Background re-validation on app launch
    private func revalidateWithPolar(key: String) async {
        let endpoint = "\(polarAPIBase)/v1/license-keys/validate"

        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(polarAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = ["key": key, "organization_id": polarOrganizationId]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // Network error or server issue — keep current license (offline-friendly)
                debugLog("⚠️ Polar re-validation failed — keeping cached license")
                return
            }

            let status = json["status"] as? String ?? ""
            if status == "revoked" || status == "disabled" {
                await MainActor.run {
                    debugLog("❌ License revoked/disabled by Polar — deactivating")
                    self.isLicensed = false
                    self.licenseInfo = nil
                    self.clearStoredLicense()
                }
            } else {
                debugLog("✓ Polar re-validation passed (status: \(status))")
            }
        } catch {
            debugLog("⚠️ Polar re-validation network error — keeping cached license")
        }
    }
    #endif

    // MARK: - License Deactivation

    func deactivateLicense(completion: @escaping (Result<Void, Error>) -> Void) {
        #if APPSTORE
        completion(.failure(NSError(domain: "LicenseManager", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "License deactivation is not supported in App Store builds."])))
        return
        #else
        guard let _ = licenseInfo else {
            completion(.failure(LicenseError.noLicenseFound))
            return
        }

        debugLog("🔓 Deactivating license")

        clearStoredLicense()
        isLicensed = false
        licenseInfo = nil

        completion(.success(()))
        debugLog("✓ License deactivated")
        #endif
    }

    // MARK: - Storage

    #if !APPSTORE
    private func storeLicense(_ info: LicenseInfo) {
        do {
            saveToKeychain("licenseKey", value: info.key)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(info)
            if let dataString = String(data: data, encoding: .utf8) {
                saveToKeychain("licenseData", value: dataString)
                debugLog("✓ License stored securely in Keychain")
            }
        } catch {
            debugLog("❌ Failed to store license: \(error)")
        }
    }

    private func clearStoredLicense() {
        deleteFromKeychain("licenseKey")
        deleteFromKeychain("licenseData")
        debugLog("🗑️ License removed from Keychain")
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

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            debugLog("❌ Keychain save failed for \(key): \(status)")
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

        if status == errSecUserCanceled || status == errSecAuthFailed {
            return nil
        } else if status == errSecItemNotFound {
            return nil
        } else if status != errSecSuccess {
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

    // MARK: - Helpers

    func maskLicenseKey(_ key: String) -> String {
        let parts = key.split(separator: "-")
        if parts.count >= 4 {
            return "\(parts[0])-****-****-\(parts[parts.count - 1])"
        }
        if key.count > 8 {
            return "\(key.prefix(4))****\(key.suffix(4))"
        }
        return "****"
    }

    #if !APPSTORE
    private func getDeviceFingerprint() -> String {
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

    // MARK: - Pro Access

    var isPro: Bool {
        #if APPSTORE
        return storeKit.isProUnlocked
        #else
        return isLicensed
        #endif
    }

    func canUsePremiumFeatures() -> Bool {
        #if APPSTORE
        return storeKit.isProUnlocked || !isTrialExpired
        #else
        return isLicensed || !isTrialExpired
        #endif
    }

    func getRemainingFeatureUses() -> Int? {
        if isPro { return nil }
        if isTrialExpired { return 0 }

        let usedCount = UserDefaults.standard.integer(forKey: "trialUsageCount")
        let limit = 50
        return max(0, limit - usedCount)
    }

    func incrementTrialUsage() {
        guard !isPro else { return }
        let current = UserDefaults.standard.integer(forKey: "trialUsageCount")
        UserDefaults.standard.set(current + 1, forKey: "trialUsageCount")
    }

    // MARK: - Purchase

    func openPurchaseURL() {
        // Polar.sh checkout for Solo product
        let checkoutURL = "https://buy.polar.sh/polar_cl_WceepXgXX84woZwlMk3QyIZw79tHTl3PcpXGh0KA2Xo"
        if let url = URL(string: checkoutURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
