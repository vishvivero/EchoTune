//
//  ReferralManager.swift
//  EchoTune
//
//  Referral System — Supabase Backend
//  Rules:
//    - Referred friend gets 3 months bonus
//    - Referrer gets +1 month per successful referral
//    - 12 referrals = free year
//

import Foundation
import AppKit

@Observable
class ReferralManager {
    static let shared = ReferralManager()

    // MARK: - Supabase Config
    private let supabaseURL = "https://mdcnmfbogxixjfwordxy.supabase.co"
    private var supabaseAnonKey: String {
        // Stored in UserDefaults after first setup, or hardcoded for beta
        UserDefaults.standard.string(forKey: "supabaseAnonKey") ?? Self.defaultAnonKey
    }
    // TODO: Replace with actual anon key from Supabase dashboard
    private static let defaultAnonKey = "REPLACE_WITH_ANON_KEY"

    // MARK: - State
    var referralCode: String = ""
    var totalReferrals: Int = 0
    var bonusDaysEarned: Int = 0
    var licenseExpiresAt: Date?
    var referrals: [ReferralEntry] = []
    var referralsToFreeYear: Int = 12
    var isRegistered: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    // Computed
    var referralLink: String {
        "https://echotune.app/refer?code=\(referralCode)"
    }

    var betaCheckoutWithReferral: String {
        "https://buy.polar.sh/polar_cl_tEci7bd2fPc1ocQpEIBJ3hcASSTzfPrEd8Q3R13WwsA?metadata[referral_code]=\(referralCode)"
    }

    var progressToFreeYear: Double {
        min(1.0, Double(totalReferrals) / 12.0)
    }

    var hasFreeYear: Bool {
        totalReferrals >= 12
    }

    // MARK: - Persistence Keys
    private let kReferralCode = "echotune_referral_code"
    private let kIsRegistered = "echotune_referral_registered"

    private init() {
        // Load cached state
        referralCode = UserDefaults.standard.string(forKey: kReferralCode) ?? ""
        isRegistered = UserDefaults.standard.bool(forKey: kIsRegistered)

        if isRegistered && !referralCode.isEmpty {
            // Refresh stats in background
            Task { await refreshStats() }
        }
    }

    // MARK: - Registration

    /// Register the current user in the referral system
    /// Call this after successful Polar license activation
    func register(
        email: String,
        polarLicenseKey: String? = nil,
        polarCustomerId: String? = nil,
        referredByCode: String? = nil,
        licenseExpiresAt: Date? = nil
    ) async -> Bool {
        guard !email.isEmpty else { return false }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var params: [String: Any] = [
            "p_email": email
        ]
        if let key = polarLicenseKey { params["p_polar_license_key"] = key }
        if let cid = polarCustomerId { params["p_polar_customer_id"] = cid }
        if let ref = referredByCode, !ref.isEmpty { params["p_referred_by"] = ref }
        if let exp = licenseExpiresAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            params["p_license_expires_at"] = formatter.string(from: exp)
        }

        // Get device fingerprint
        params["p_device_fingerprint"] = getDeviceFingerprint()

        guard let result: RegisterResult = await callRPC("register_beta_user", params: params) else {
            return false
        }

        await MainActor.run {
            self.referralCode = result.referral_code
            self.totalReferrals = result.total_referrals
            self.bonusDaysEarned = result.bonus_days_earned
            self.licenseExpiresAt = result.parsedExpiryDate
            self.isRegistered = true

            // Cache
            UserDefaults.standard.set(result.referral_code, forKey: kReferralCode)
            UserDefaults.standard.set(true, forKey: kIsRegistered)
        }

        debugLog("✓ Referral system registered: \(result.referral_code)")
        return true
    }

    // MARK: - Stats

    func refreshStats() async {
        guard !referralCode.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        guard let result: StatsResult = await callRPC("get_referral_stats", params: [
            "p_referral_code": referralCode
        ]) else { return }

        guard result.success else {
            debugLog("❌ Referral stats error: \(result.error ?? "unknown")")
            return
        }

        await MainActor.run {
            self.totalReferrals = result.total_referrals ?? 0
            self.bonusDaysEarned = result.bonus_days_earned ?? 0
            self.referralsToFreeYear = result.referrals_to_free_year ?? 12
            self.licenseExpiresAt = result.parsedExpiryDate
            self.referrals = result.referrals ?? []
        }

        debugLog("✓ Referral stats refreshed: \(totalReferrals) referrals, \(bonusDaysEarned) bonus days")
    }

    // MARK: - Sharing

    func copyReferralLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(referralLink, forType: .string)
    }

    func copyCheckoutLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(betaCheckoutWithReferral, forType: .string)
    }

    func shareViaEmail(to email: String) {
        let subject = "Try EchoTune — Get 3 Free Months! 🎙️"
        let body = """
        Hey!

        I've been using EchoTune for voice dictation and it's incredible — privacy-first, runs locally on your Mac.

        Use my referral link to get 3 FREE months of beta access:
        \(betaCheckoutWithReferral)

        My referral code: \(referralCode)

        Cheers!
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }

    func shareToX() {
        let text = """
        Been using @EchoTuneApp for voice dictation — privacy-first, runs locally on Mac 🎙️

        Get 3 FREE months with my link: \(betaCheckoutWithReferral)

        #productivity #AI #voicetyping
        """

        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://twitter.com/intent/tweet?text=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Supabase RPC

    private func callRPC<T: Decodable>(_ function: String, params: [String: Any]) async -> T? {
        let urlString = "\(supabaseURL)/rest/v1/rpc/\(function)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return nil
            }

            if httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? ""
                debugLog("❌ Supabase RPC \(function) HTTP \(httpResponse.statusCode): \(body)")
                errorMessage = "Server error (\(httpResponse.statusCode))"
                return nil
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(T.self, from: data)
            return result

        } catch {
            debugLog("❌ Supabase RPC \(function) error: \(error)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

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
}

// MARK: - Models

struct RegisterResult: Decodable {
    let success: Bool
    let user_id: String?
    let referral_code: String
    let bonus_days_earned: Int
    let total_referrals: Int
    let license_expires_at: String?
    let is_new: Bool?
    let referred_by: String?

    var parsedExpiryDate: Date? {
        guard let str = license_expires_at else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: str)
        }()
    }
}

struct StatsResult: Decodable {
    let success: Bool
    let error: String?
    let referral_code: String?
    let total_referrals: Int?
    let bonus_days_earned: Int?
    let license_expires_at: String?
    let referrals_to_free_year: Int?
    let referrals: [ReferralEntry]?

    var parsedExpiryDate: Date? {
        guard let str = license_expires_at else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: str)
        }()
    }
}

struct ReferralEntry: Decodable, Identifiable {
    let email: String
    let status: String
    let bonus_days: Int?
    let created_at: String?
    let activated_at: String?

    var id: String { email + (created_at ?? "") }

    var maskedEmail: String { email }  // Already masked by server

    var createdDate: Date? {
        guard let str = created_at else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str)
    }

    var statusEmoji: String {
        switch status {
        case "rewarded": return "✅"
        case "activated": return "🟢"
        case "pending": return "⏳"
        case "expired": return "❌"
        default: return "❓"
        }
    }
}
