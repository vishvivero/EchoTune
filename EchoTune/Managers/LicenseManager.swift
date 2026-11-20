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

    // MARK: - Polar & Storefront Configuration
    //
    // License checks go through Polar's customer-portal endpoints, which are
    // designed for public clients and need no secret token — only the
    // organization id, which is not sensitive.
    // All purchase CTAs route through https://echotune.app/buy so checkout
    // destinations can be updated without shipping a new app binary.
    static let purchaseURLString = "https://echotune.app/buy"

    private let polarAPIBase = "https://api.polar.sh"
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
        if trialExpiryDate == .distantFuture { return 7 }
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: trialExpiryDate).day ?? 0
        return max(0, remaining)
    }

    // Storage
    private let serviceName = "com.echotune.app"
    private let trialDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private init() {
        // The 7-day trial clock is anchored in Keychain so deleting UserDefaults
        // cannot reset it. On fresh installs, the clock starts when onboarding
        // finishes; existing installs preserve their saved anchor immediately.
        trialExpiryDate = .distantFuture

        let anchorFormatter = ISO8601DateFormatter()
        if let anchorString = getFromKeychain("trialStartAnchor"),
           let anchorDate = anchorFormatter.date(from: anchorString) {
            trialExpiryDate = anchorDate.addingTimeInterval(trialDuration)
            UserDefaults.standard.set(anchorDate, forKey: "trialStartDate")
        } else if let legacyDate = UserDefaults.standard.object(forKey: "trialStartDate") as? Date {
            _ = saveToKeychain("trialStartAnchor", value: anchorFormatter.string(from: legacyDate))
            trialExpiryDate = legacyDate.addingTimeInterval(trialDuration)
        } else if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            let startDate = Date()
            _ = saveToKeychain("trialStartAnchor", value: anchorFormatter.string(from: startDate))
            UserDefaults.standard.set(startDate, forKey: "trialStartDate")
            trialExpiryDate = startDate.addingTimeInterval(trialDuration)
        } else {
            // Defer starting the 7-day trial until onboarding finishes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OnboardingCompleted"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.startTrialIfNeeded()
            }
        }

        // Check for existing license
        validateStoredLicense()

        debugLog("✓ LicenseManager initialized (Polar.sh)")
        debugLog("📅 Trial days remaining: \(trialDaysRemaining)")
    }

    /// Starts the 7-day trial once when onboarding completes (idempotent).
    func startTrialIfNeeded() {
        let anchorFormatter = ISO8601DateFormatter()
        if let anchorString = getFromKeychain("trialStartAnchor"),
           let anchorDate = anchorFormatter.date(from: anchorString) {
            trialExpiryDate = anchorDate.addingTimeInterval(trialDuration)
            return
        }
        let startDate = Date()
        _ = saveToKeychain("trialStartAnchor", value: anchorFormatter.string(from: startDate))
        UserDefaults.standard.set(startDate, forKey: "trialStartDate")
        trialExpiryDate = startDate.addingTimeInterval(trialDuration)
        debugLog("📅 Started 7-day trial anchor after onboarding")
    }

    // MARK: - Stored License Validation

    private func validateStoredLicense() {
        #if APPSTORE
        debugLog("⏳ App Store build — no license key check")
        #else
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
                await revalidateWithPolar(stored: storedInfo)
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
                deviceFingerprint: getDeviceFingerprint(),
                activationId: "demo-activation"
            )
            guard storeLicense(info) else {
                isActivating = false
                activationError = LicenseError.storageFailed.errorDescription
                completion(.failure(LicenseError.storageFailed))
                return
            }
            isLicensed = true
            licenseInfo = info
            isActivating = false
            completion(.success(info))
            debugLog("✓ Demo license activated")
            return
        }
        #endif

        validateWithPolar(key: trimmedKey, completion: completion)
        #endif
    }

    #if !APPSTORE

    // MARK: - Polar Customer-Portal Client

    private struct PolarKeyState: Decodable {
        let status: String          // "granted" | "revoked" | "disabled"
        let expiresAt: Date?
        let limitActivations: Int?
        let customerEmail: String?

        private enum CodingKeys: String, CodingKey {
            case status
            case expiresAt = "expires_at"
            case limitActivations = "limit_activations"
            case customer
        }
        private enum CustomerKeys: String, CodingKey {
            case email
        }

        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: CodingKeys.self)
            status = try root.decode(String.self, forKey: .status)
            expiresAt = Self.parseTimestamp(try root.decodeIfPresent(String.self, forKey: .expiresAt))
            limitActivations = try root.decodeIfPresent(Int.self, forKey: .limitActivations)
            if let customer = try? root.nestedContainer(keyedBy: CustomerKeys.self, forKey: .customer) {
                customerEmail = try customer.decodeIfPresent(String.self, forKey: .email)
            } else {
                customerEmail = nil
            }
        }

        fileprivate static func parseTimestamp(_ raw: String?) -> Date? {
            guard let raw else { return nil }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: raw) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: raw)
        }
    }

    private struct PolarActivationResponse: Decodable {
        let id: String
    }

    private enum PolarLookupError: Error {
        case unknownKey
        case deviceLimitReached
        case httpFailure(Int)
    }

    private func fetchKeyState(_ key: String, activationId: String? = nil) async throws -> PolarKeyState {
        var request = URLRequest(url: URL(string: "\(polarAPIBase)/v1/customer-portal/license-keys/validate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        var payload: [String: String] = [
            "key": key,
            "organization_id": polarOrganizationId
        ]
        if let activationId, !activationId.isEmpty {
            payload["activation_id"] = activationId
        }
        request.httpBody = try JSONEncoder().encode(payload)

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

    /// Claims a per-device Polar activation slot when `limit_activations` is enabled on the benefit.
    private func activateDeviceOnPolar(key: String, fingerprint: String) async throws -> String {
        var request = URLRequest(url: URL(string: "\(polarAPIBase)/v1/customer-portal/license-keys/activate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let label = Host.current().localizedName ?? "Mac"
        let body: [String: Any] = [
            "key": key,
            "organization_id": polarOrganizationId,
            "label": label,
            "meta": ["fingerprint": fingerprint]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseError.serverUnreachable
        }

        switch http.statusCode {
        case 200, 201:
            let decoded = try JSONDecoder().decode(PolarActivationResponse.self, from: data)
            return decoded.id
        case 403, 422:
            throw PolarLookupError.deviceLimitReached
        case 404:
            throw PolarLookupError.unknownKey
        default:
            throw PolarLookupError.httpFailure(http.statusCode)
        }
    }

    private func deactivateDeviceOnPolar(key: String, activationId: String) async {
        guard let url = URL(string: "\(polarAPIBase)/v1/customer-portal/license-keys/deactivate") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONEncoder().encode([
            "key": key,
            "organization_id": polarOrganizationId,
            "activation_id": activationId
        ])
        _ = try? await URLSession.shared.data(for: request)
    }

    private func validateWithPolar(key: String, completion: @escaping (Result<LicenseInfo, Error>) -> Void) {
        Task {
            do {
                let state = try await fetchKeyState(key)

                guard state.status == "granted" else {
                    await MainActor.run {
                        self.isActivating = false
                        let reason = state.status == "revoked"
                            ? "This license has been revoked."
                            : "This license is not active (status: \(state.status))."
                        self.activationError = reason
                        completion(.failure(LicenseError.activationFailed))
                    }
                    return
                }

                let fingerprint = self.getDeviceFingerprint()
                var activationId: String? = nil
                if let limit = state.limitActivations, limit > 0 {
                    activationId = try await self.activateDeviceOnPolar(key: key, fingerprint: fingerprint)
                }

                let inferredTier: LicenseTier = (state.limitActivations ?? 1) >= 3 ? .pro : .individual
                let info = LicenseInfo(
                    key: key,
                    tier: inferredTier,
                    activatedOn: Date(),
                    expiryDate: state.expiresAt,
                    deviceFingerprint: fingerprint,
                    activationId: activationId
                )

                await MainActor.run {
                    self.isActivating = false

                    guard self.storeLicense(info) else {
                        self.activationError = LicenseError.storageFailed.errorDescription
                        completion(.failure(LicenseError.storageFailed))
                        return
                    }

                    self.isLicensed = true
                    self.licenseInfo = info
                    debugLog("✓ License activated via Polar (tier=\(inferredTier.rawValue))")

                    if ReferralManager.shared.isConfigured, let email = state.customerEmail {
                        Task {
                            _ = await ReferralManager.shared.register(
                                email: email,
                                polarLicenseKey: nil,
                                polarCustomerId: nil,
                                referredByCode: UserDefaults.standard.string(forKey: "pendingReferralCode"),
                                licenseExpiresAt: state.expiresAt
                            )
                            UserDefaults.standard.removeObject(forKey: "pendingReferralCode")
                        }
                    }

                    completion(.success(info))
                }
            } catch PolarLookupError.deviceLimitReached {
                await MainActor.run {
                    self.isActivating = false
                    self.activationError = LicenseError.deviceLimitReached.errorDescription
                    completion(.failure(LicenseError.deviceLimitReached))
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

    /// Background re-check on launch. Forgiving on network errors; enforces
    /// server-side revocations, deletions, and device activation limits.
    private func revalidateWithPolar(stored: LicenseInfo) async {
        do {
            let state = try await fetchKeyState(stored.key, activationId: stored.activationId)
            if state.status == "revoked" || state.status == "disabled" {
                await MainActor.run {
                    debugLog("❌ Polar reports license \(state.status) — deactivating")
                    self.isLicensed = false
                    self.licenseInfo = nil
                    self.clearStoredLicense()
                    AppCoordinator.shared.updateLicenseState()
                }
                return
            }

            // Seamless upgrade path: if the Polar benefit enforces device activations
            // and this pre-7.5.4 install didn't record an activationId yet, claim one.
            if stored.activationId == nil, let limit = state.limitActivations, limit > 0 {
                if let claimedId = try? await activateDeviceOnPolar(key: stored.key, fingerprint: stored.deviceFingerprint) {
                    var updated = stored
                    updated.activationId = claimedId
                    _ = await MainActor.run {
                        self.licenseInfo = updated
                        return self.storeLicense(updated)
                    }
                }
            }
            debugLog("✓ Polar re-validation passed")
        } catch PolarLookupError.unknownKey {
            await MainActor.run {
                debugLog("❌ Polar reports license/activation no longer valid — deactivating")
                self.isLicensed = false
                self.licenseInfo = nil
                self.clearStoredLicense()
                AppCoordinator.shared.updateLicenseState()
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
        guard let current = licenseInfo else {
            completion(.failure(LicenseError.noLicenseFound))
            return
        }

        debugLog("🔓 Deactivating license")
        Task {
            if let activationId = current.activationId, !activationId.isEmpty, !current.key.hasPrefix("DEMO-") {
                await deactivateDeviceOnPolar(key: current.key, activationId: activationId)
            }
            await MainActor.run {
                self.clearStoredLicense()
                self.isLicensed = false
                self.licenseInfo = nil
                completion(.success(()))
                debugLog("✓ License deactivated")
            }
        }
        #endif
    }

    // MARK: - Storage

    #if !APPSTORE
    @discardableResult
    private func storeLicense(_ info: LicenseInfo) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(info)
            guard let dataString = String(data: data, encoding: .utf8) else { return false }

            let savedKey = saveToKeychain("licenseKey", value: info.key)
            let savedData = saveToKeychain("licenseData", value: dataString)
            if savedKey && savedData {
                debugLog("✓ License stored securely in Keychain")
                return true
            }
            return false
        } catch {
            debugLog("❌ Failed to encode license: \(error)")
            return false
        }
    }

    private func clearStoredLicense() {
        deleteFromKeychain("licenseKey")
        deleteFromKeychain("licenseData")
        debugLog("🗑️ License removed from Keychain")
    }

    // MARK: - Keychain Helpers

    private var testKeychainStore: [String: String] = [:]

    private var isTestHost: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestSessionIdentifier"] != nil
    }

    @discardableResult
    private func saveToKeychain(_ key: String, value: String) -> Bool {
        if isTestHost {
            testKeychainStore[key] = value
            return true
        }
        guard let data = value.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            debugLog("❌ Keychain save failed for \(key): \(status)")
            return false
        }
        return true
    }

    private func getFromKeychain(_ key: String) -> String? {
        if isTestHost {
            return testKeychainStore[key]
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func deleteFromKeychain(_ key: String) {
        if isTestHost {
            testKeychainStore.removeValue(forKey: key)
            return
        }
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
        )?.takeRetainedValue() as? String else {
            return UUID().uuidString
        }

        return uuid
    }
    #endif

    // MARK: - Pro Access & 7-Day Trial

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
        return nil // Trial is a clean 7-day unlimited evaluation
    }

    func incrementTrialUsage() {
        // Retained for binary/API compatibility; trial is gated solely by the 7-day window.
    }

    // MARK: - Purchase

    @discardableResult
    func openPurchaseURL() -> Bool {
        guard let url = URL(string: Self.purchaseURLString) else { return false }
        debugLog("🛒 Opening EchoTune purchase page: \(Self.purchaseURLString)")
        return NSWorkspace.shared.open(url)
    }
}
