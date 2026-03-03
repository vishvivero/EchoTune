import Foundation
import Supabase

// MARK: - Referral Data Models

struct BetaUser: Codable {
  let id: String
  let email: String
  let referral_code: String
  let license_type: String
  let license_expires_at: String
  let joined_at: String
}

struct ReferralRecord: Codable {
  let id: String
  let referrer_id: String
  let referred_user_id: String?
  let referred_email: String
  let referred_at: String
  let signup_completed_at: String?
  let status: String // 'pending', 'completed'
}

struct ReferralStats: Codable {
  let total_referrals: Int
  let completed_referrals: Int
  let pending_referrals: Int
  let bonus_days_earned: Int
  let free_year_unlocked: Bool
}

// MARK: - Referral Manager

class ReferralManager: ObservableObject {
  @Published var currentUser: BetaUser?
  @Published var referralStats: ReferralStats?
  @Published var referrals: [ReferralRecord] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let supabase: SupabaseClient

  init(supabase: SupabaseClient) {
    self.supabase = supabase
  }

  // MARK: - Load Current User & Stats

  func loadCurrentUserAndStats() async {
    DispatchQueue.main.async {
      self.isLoading = true
    }

    do {
      // Get current user's email (from Auth session or local storage)
      guard let email = try await getCurrentUserEmail() else {
        DispatchQueue.main.async {
          self.errorMessage = "Not authenticated"
          self.isLoading = false
        }
        return
      }

      // Fetch user profile
      let user: BetaUser = try await supabase
        .from("beta_users")
        .select()
        .eq("email", value: email)
        .single()
        .execute()
        .value

      // Fetch referral stats via RPC
      let stats: [ReferralStats] = try await supabase
        .rpc("get_referral_stats", params: ["user_email": email])
        .execute()
        .value

      // Fetch referrals
      let referralsList: [ReferralRecord] = try await supabase
        .from("referrals")
        .select()
        .eq("referrer_id", value: user.id)
        .order("referred_at", ascending: false)
        .execute()
        .value

      DispatchQueue.main.async {
        self.currentUser = user
        self.referralStats = stats.first
        self.referrals = referralsList
        self.isLoading = false
        self.errorMessage = nil
      }
    } catch {
      DispatchQueue.main.async {
        self.errorMessage = error.localizedDescription
        self.isLoading = false
      }
    }
  }

  // MARK: - Generate Referral Link

  func generateReferralLink() -> String? {
    guard let code = currentUser?.referral_code else { return nil }
    return "https://buy.polar.sh/checkout?referral=\(code)"
  }

  // MARK: - Add a Referral (Manual Entry)

  func addReferral(friendEmail: String) async {
    guard let userEmail = currentUser?.email else {
      DispatchQueue.main.async {
        self.errorMessage = "User not found"
      }
      return
    }

    DispatchQueue.main.async {
      self.isLoading = true
    }

    do {
      let result: [[String: AnyCodable]] = try await supabase
        .rpc("add_referral", params: [
          "referrer_email": userEmail,
          "referred_email": friendEmail,
        ])
        .execute()
        .value

      if let firstResult = result.first {
        if let status = firstResult["status"]?.stringValue,
           status != "error" {
          DispatchQueue.main.async {
            self.errorMessage = nil
            // Reload stats
            Task {
              await self.loadCurrentUserAndStats()
            }
          }
        } else if let message = firstResult["message"]?.stringValue {
          DispatchQueue.main.async {
            self.errorMessage = message
            self.isLoading = false
          }
        }
      }
    } catch {
      DispatchQueue.main.async {
        self.errorMessage = "Failed to add referral: \(error.localizedDescription)"
        self.isLoading = false
      }
    }
  }

  // MARK: - Copy Referral Code

  func copyReferralCode() {
    guard let code = currentUser?.referral_code else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(code, forType: .string)
  }

  // MARK: - Share Referral Link

  func shareReferralLink() {
    guard let link = generateReferralLink() else { return }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(link, forType: .string)

    // Open share sheet (macOS)
    if let url = URL(string: link) {
      NSWorkspace.shared.open(url)
    }
  }

  // MARK: - Check Free Year Eligibility

  var isFreeYearUnlocked: Bool {
    guard let stats = referralStats else { return false }
    return stats.free_year_unlocked
  }

  // MARK: - Helper: Get Current User Email

  private func getCurrentUserEmail() async throws -> String? {
    // Option 1: From Auth session (if using Supabase Auth)
    if let session = try await supabase.auth.session {
      return session.user.email
    }

    // Option 2: From local UserDefaults (if stored during signup)
    if let savedEmail = UserDefaults.standard.string(forKey: "userEmail") {
      return savedEmail
    }

    return nil
  }

  // MARK: - License Expiry Helper

  func daysUntilExpiry() -> Int? {
    guard let expiryString = currentUser?.license_expires_at else { return nil }

    let formatter = ISO8601DateFormatter()
    guard let expiryDate = formatter.date(from: expiryString) else { return nil }

    let days = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    return max(0, days)
  }

  func isLicenseExpired() -> Bool {
    guard let days = daysUntilExpiry() else { return true }
    return days <= 0
  }
}

// MARK: - Helper for Decoding JSON to AnyCodable

enum AnyCodable: Codable {
  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case array([AnyCodable])
  case object([String: AnyCodable])

  var stringValue: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }

  var boolValue: Bool? {
    if case .bool(let value) = self {
      return value
    }
    return nil
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let int = try? container.decode(Int.self) {
      self = .int(int)
    } else if let double = try? container.decode(Double.self) {
      self = .double(double)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let array = try? container.decode([AnyCodable].self) {
      self = .array(array)
    } else if let object = try? container.decode([String: AnyCodable].self) {
      self = .object(object)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Cannot decode AnyCodable"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .bool(let value):
      try container.encode(value)
    case .int(let value):
      try container.encode(value)
    case .double(let value):
      try container.encode(value)
    case .string(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    }
  }
}
