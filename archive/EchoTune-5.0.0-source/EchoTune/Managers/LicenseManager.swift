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
    //
    // License checks go through Polar's customer-portal endpoints, which are
    // designed for public clients and need no secret token — only the
    // organization id, which is not sensitive.
    private let polarAPIBase = "https://api.polar.sh"
    private let soloProductId = "f50d3be4-616c-40aa-9b66-a38a0b565d6f"
    private let polarOrganizationId = "fedfb5b9-01c8-4178-a1cb-90b3f0e1e1ae"
    private let polarStorefrontURL = "https://polar.sh/HelixNotus/products"

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
        // The trial clock is anchored in the Keychain so deleting UserDefaults
        // can't restart it. The anchor is set exactly once: from an existing
        // UserDefaults start date (upgrade path) or from "now" on first launch.
        trialExpiryDate = .distantFuture // placeholder; resolved below

        let anchorFormatter = ISO8601DateFormatter()
        if let anchorString = getFromKeychain("trialStartAnchor"),
           let anchorDate = anchorFormatter.date(from: anchorString) {
            trialExpiryDate = anchorDate.addingTimeInterval(trialDuration)
            // Keep the UserDefaults copy in sync for consumers that read it.
            UserDefaults.standard.set(anchorDate, forKey: "trialStartDate")
        } else {
            let startDate = (UserDefaults.standard.object(forKey: "trialStartDate") as? Date) ?? Date()
            saveToKeychain("trialStartAnchor", value: anchorFormatter.string(from: startDate))
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
        // Must match storeLicense's .iso8601 date encoding or the decode always fails.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let _ = getFromKeychain("licenseKey"),
              let licenseDataString = getFromKeychain("licenseData"),
              let licenseData = licenseDataString.data(using: .utf8),
              let storedInfo = try? decoder.decode(LicenseInfo.self, from: licenseData) else {
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
                tier: .individual,
                activatedOn: Date(),
                expiryDate: nil,
                deviceFingerprint: getDeviceFingerprint()
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

    // MARK: - Polar Customer-Portal Client

    /// Decoded subset of Polar's ValidatedLicenseKey response.
    private struct PolarKeyState: Decodable {
        let status: String          // "granted" | "revoked" | "disabled"
        let expiresAt: Date?
        let customerEmail: String?

        private enum CodingKeys: String, CodingKey {
            case status
            case expiresAt = "expires_at"
            case customer
        }
        private enum CustomerKeys: String, CodingKey {
            case email
        }

        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: CodingKeys.self)
            status = try root.decode(String.self, forKey: .status)
            expiresAt = Self.parseTimestamp(try root.decodeIfPresent(String.self, forKey: .expiresAt))
            if let customer = try? root.nestedContainer(keyedBy: CustomerKeys.self, forKey: .customer) {
                customerEmail = try customer.decodeIfPresent(String.self, forKey: .email)
            } else {
                customerEmail = nil
            }
        }

        private static func parseTimestamp(_ raw: String?) -> Date? {
            guard let raw else { return nil }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: raw) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: raw)
        }
    }

    private enum PolarLookupError: Error {
        case unknownKey
        case httpFailure(Int)
    }

    /// Asks Polar's public customer-portal endpoint about a key. Requires no
    /// authentication — validated as safe for desktop clients by Polar's docs.
    private func fetchKeyState(_ key: String) async throws -> PolarKeyState {
        var request = URLRequest(url: URL(string: "\(polarAPIBase)/v1/customer-portal/license-keys/validate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode([
            "key": key,
            "organization_id": polarOrganizationId
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseError.serverUnreachable
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(PolarKeyState.self, from: data)
        case 404, 422:
            throw PolarLookupError.unknownKey
        default:
            throw PolarLookupError.httpFailure(http.statusCode)
        }
    }

    private func validateWithPolar(key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        Task {
            do {
                let state = try await fetchKeyState(key)

                await MainActor.run {
                    self.isActivating = false

                    guard state.status == "granted" else {
                        let reason = state.status == "revoked"
                            ? "This license has been revoked."
                            : "This license is not active (status: \(state.status))."
                        self.activationError = reason
                        completion(.failure(LicenseError.activationFailed))
                        return
                    }

                    let info = LicenseInfo(
                        key: key,
                        tier: .individual,
                        activatedOn: Date(),
                        expiryDate: state.expiresAt,
                        deviceFingerprint: self.getDeviceFingerprint()
                    )

                    self.storeLicense(info)
                    self.isLicensed = true
                    self.licenseInfo = info
                    debugLog("✓ License activated via Polar")

                    if let email = state.customerEmail {
                        Task {
                            await ReferralManager.shared.register(
                                email: email,
                                polarLicenseKey: key,
                                polarCustomerId: nil,
                                referredByCode: UserDefaults.standard.string(forKey: "pendingReferralCode"),
                                licenseExpiresAt: state.expiresAt
                            )
                            UserDefaults.standard.removeObject(forKey: "pendingReferralCode")
                        }
                    }

                    completion(.success(info))
                }
            } catch PolarLookupError.unknownKey {
                await MainActor.run {
                    self.isActivating = false
                    self.activationError = "Invalid license key. Please check and try again."
                    completion(.failure(LicenseError.invalidFormat))
                }
            } catch let PolarLookupError.httpFailure(code) {
                await MainActor.run {
                    self.isActivating = false
                    self.activationError = "License activation failed (HTTP \(code))."
                    completion(.failure(LicenseError.activationFailed))
                }
            } catch {
                await MainActor.run {
                    self.isActivating = false
                    self.activationError = "Could not reach license server. Check your internet connection."
                    completion(.failure(LicenseError.serverUnreachable))
                }
            }
        }
    }

    /// Background re-check on launch. Deliberately forgiving: only an explicit
    /// revoked/disabled verdict removes the cached license — network trouble
    /// never locks a paying user out.
    private func revalidateWithPolar(key: String) async {
        do {
            let state = try await fetchKeyState(key)
            if state.status == "revoked" || state.status == "disabled" {
                await MainActor.run {
                    debugLog("❌ Polar reports license \(state.status) — deactivating")
                    self.isLicensed = false
                    self.licenseInfo = nil
                    self.clearStoredLicense()
                }
            } else {
                debugLog("✓ Polar re-validation passed")
            }
        } catch PolarLookupError.unknownKey {
            // Definitive server verdict (key deleted, e.g. after a refund) —
            // not a network blip. Remove the cached license.
            await MainActor.run {
                debugLog("❌ Polar reports license key no longer exists — deactivating")
                self.isLicensed = false
                self.licenseInfo = nil
                self.clearStoredLicense()
            }
        } catch {
            debugLog("⚠️ Polar re-validation unavailable — keeping cached license")
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

    @discardableResult
    func openPurchaseURL() -> Bool {
        // Checkout-session creation needs an organization secret, which a
        // desktop client must never embed — send buyers to the storefront,
        // where Polar hosts the checkout itself.
        guard let url = URL(string: polarStorefrontURL) else { return false }
        debugLog("🛒 Opening Polar storefront")
        return NSWorkspace.shared.open(url)
    }
}
