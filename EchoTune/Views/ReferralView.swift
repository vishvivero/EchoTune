import SwiftUI

struct ReferralView: View {
  @StateObject private var manager: ReferralManager
  @State private var friendEmail = ""
  @State private var showAlert = false
  @State private var alertMessage = ""

  init(supabase: SupabaseClient) {
    _manager = StateObject(wrappedValue: ReferralManager(supabase: supabase))
  }

  var body: some View {
    VStack(spacing: 24) {
      // Header
      VStack(spacing: 8) {
        Text("Grow with EchoTune")
          .font(.title2)
          .fontWeight(.bold)

        Text("Invite friends and unlock free premium time")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // License Status
      if let user = manager.currentUser {
        VStack(spacing: 12) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Your License")
                .font(.caption)
                .foregroundColor(.secondary)

              if let days = manager.daysUntilExpiry() {
                Text("\(days) days remaining")
                  .font(.headline)
                  .foregroundColor(days > 30 ? .green : days > 7 ? .orange : .red)
              }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
              Text("Referral Code")
                .font(.caption)
                .foregroundColor(.secondary)

              HStack(spacing: 8) {
                Text(user.referral_code)
                  .font(.system(.body, design: .monospaced))
                  .fontWeight(.semibold)
                  .textSelection(.enabled)

                Button(action: { manager.copyReferralCode() }) {
                  Image(systemName: "doc.on.doc")
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy referral code")
              }
            }
          }
          .padding(12)
          .background(Color(.controlBackgroundColor))
          .cornerRadius(8)
        }
      }

      // Referral Stats
      if let stats = manager.referralStats {
        VStack(spacing: 12) {
          HStack(spacing: 16) {
            // Completed Referrals
            VStack(spacing: 4) {
              Text("\(stats.completed_referrals)")
                .font(.title3)
                .fontWeight(.bold)

              Text("Completed")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // Pending Referrals
            VStack(spacing: 4) {
              Text("\(stats.pending_referrals)")
                .font(.title3)
                .fontWeight(.bold)

              Text("Pending")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // Bonus Days
            VStack(spacing: 4) {
              Text("\(stats.bonus_days_earned)d")
                .font(.title3)
                .fontWeight(.bold)

              Text("Bonus Days")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
          }

          // Free Year Achievement
          if stats.free_year_unlocked {
            HStack(spacing: 8) {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)

              Text("🎉 You've unlocked a free year of premium!")
                .font(.subheadline)
                .fontWeight(.semibold)

              Spacer()
            }
            .padding(12)
            .background(Color(.systemYellow).opacity(0.1))
            .cornerRadius(8)
          } else {
            ProgressView(
              value: Double(stats.completed_referrals),
              total: 12
            )
            .tint(.green)

            Text("Refer \(12 - stats.completed_referrals) more friends to unlock a free year")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      // Referral Link
      VStack(spacing: 12) {
        Text("Share Your Link")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let link = manager.generateReferralLink() {
          HStack(spacing: 8) {
            Text(link)
              .font(.system(.caption, design: .monospaced))
              .lineLimit(1)
              .textSelection(.enabled)
              .foregroundColor(.secondary)

            Spacer()

            Button(action: { manager.shareReferralLink() }) {
              Image(systemName: "link.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Copy link")
          }
          .padding(12)
          .background(Color(.controlBackgroundColor))
          .cornerRadius(8)
        }
      }

      // Add Friend
      VStack(spacing: 12) {
        Text("Invite a Friend")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
          TextField("friend@example.com", text: $friendEmail)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()

          Button(action: { addFriend() }) {
            Image(systemName: "paperplane.fill")
          }
          .disabled(friendEmail.trimmingCharacters(in: .whitespaces).isEmpty || manager.isLoading)
        }

        if let error = manager.errorMessage {
          Text(error)
            .font(.caption)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      // Referral List
      if !manager.referrals.isEmpty {
        VStack(spacing: 12) {
          Text("Your Referrals")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

          VStack(spacing: 8) {
            ForEach(manager.referrals, id: \.id) { referral in
              HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(referral.referred_email)
                    .font(.body)
                    .fontWeight(.medium)

                  Text(referral.status.capitalized)
                    .font(.caption)
                    .foregroundColor(
                      referral.status == "completed" ? .green : .orange
                    )
                }

                Spacer()

                if referral.status == "completed" {
                  HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.green)

                    Text("+30d")
                      .font(.caption)
                      .fontWeight(.semibold)
                  }
                }
              }
              .padding(8)
              .background(Color(.controlBackgroundColor))
              .cornerRadius(6)
            }
          }
        }
      }

      Spacer()

      // Footer
      VStack(spacing: 8) {
        Text("How it works")
          .font(.caption)
          .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Text("1")
              .font(.caption)
              .fontWeight(.bold)
              .frame(width: 20, height: 20)
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(10)

            Text("Share your referral code or link")
              .font(.caption)
          }

          HStack(spacing: 8) {
            Text("2")
              .font(.caption)
              .fontWeight(.bold)
              .frame(width: 20, height: 20)
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(10)

            Text("Friend signs up and activates license")
              .font(.caption)
          }

          HStack(spacing: 8) {
            Text("3")
              .font(.caption)
              .fontWeight(.bold)
              .frame(width: 20, height: 20)
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(10)

            Text("You get +30 days bonus, they get +3 months")
              .font(.caption)
          }

          HStack(spacing: 8) {
            Text("🎉")
              .font(.caption)

            Text("Refer 12 friends? Unlock a free year!")
              .font(.caption)
              .fontWeight(.semibold)
          }
        }
        .foregroundColor(.secondary)
      }
    }
    .padding(20)
    .background(Color(.windowBackgroundColor))
    .task {
      await manager.loadCurrentUserAndStats()
    }
  }

  // MARK: - Helper Methods

  private func addFriend() {
    let email = friendEmail.trimmingCharacters(in: .whitespaces)
    guard !email.isEmpty, email.contains("@") else {
      manager.errorMessage = "Please enter a valid email address"
      return
    }

    Task {
      await manager.addReferral(friendEmail: email)
      DispatchQueue.main.async {
        friendEmail = ""
      }
    }
  }
}

#Preview {
  // Note: Replace with actual SupabaseClient for preview
  // ReferralView(supabase: SupabaseClient(...))
  Text("ReferralView Preview")
}
