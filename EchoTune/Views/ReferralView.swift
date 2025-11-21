//
//  ReferralView.swift
//  EchoTune
//
//  Referral Program View
//

import SwiftUI
import AppKit

struct ReferralView: View {
    @Environment(\.dismiss) var dismiss
    @State private var friendEmail: String = ""
    @State private var showCopiedAlert = false
    @State private var selectedTab = 0

    private var isProUser: Bool {
        // Check if user has a Pro license
        AppState.shared.isLicensed
    }

    private var referralCode: String {
        // Generate unique referral code based on user
        let username = NSFullUserName().replacingOccurrences(of: " ", with: "")
        let hash = abs(username.hashValue) % 10000
        return "ET-\(username.prefix(3).uppercased())\(hash)"
    }

    private var referralLink: String {
        "https://echotune.app/refer?code=\(referralCode)"
    }

    private var headerTitle: String {
        isProUser ? "Share EchoTune, earn rewards" : "Give a month, get a month"
    }

    private var headerSubtitle: String {
        isProUser ? "Earn $5 for every friend who subscribes!" : "Invite friends and you both get a free month!"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Share").tag(0)
                Text("Past Referrals (0)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if selectedTab == 0 {
                        shareContent
                    } else {
                        pastReferralsContent
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Share Content

    private var shareContent: some View {
        VStack(spacing: 24) {
            // How it works
            VStack(alignment: .leading, spacing: 16) {
                Text("How it works")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    HowItWorksRow(
                        icon: "paperplane.fill",
                        text: "Send an invite or share your link"
                    )

                    HowItWorksRow(
                        icon: "person.badge.plus.fill",
                        text: isProUser ? "Your friend signs up and gets a free month" : "They sign up and get a free month of Pro"
                    )

                    HowItWorksRow(
                        icon: isProUser ? "dollarsign.circle.fill" : "gift.fill",
                        text: isProUser ? "You earn $5 when they subscribe to Pro" : "You get a free month when they use their credit or 1000 words"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Referral Link
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Referral Link")
                    .font(.headline)

                HStack {
                    Text(referralLink)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                    Button(action: copyLink) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("or")
                .foregroundColor(.secondary)
                .padding(.vertical, 8)

            // Email Invite
            VStack(alignment: .leading, spacing: 12) {
                Text("Send via Email")
                    .font(.headline)

                HStack {
                    TextField("friend@example.com", text: $friendEmail)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                    Button(action: sendEmail) {
                        Text("Send")
                            .fontWeight(.medium)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(friendEmail.isEmpty ? Color.gray : Color(red: 0.2, green: 0.2, blue: 0.2))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(friendEmail.isEmpty)
                }
            }

            // Social Share Buttons
            VStack(alignment: .leading, spacing: 12) {
                Text("Share on Social Media")
                    .font(.headline)

                HStack(spacing: 12) {
                    SocialShareButton(
                        platform: "X",
                        icon: "xmark",
                        color: .black,
                        action: shareToX
                    )

                    SocialShareButton(
                        platform: "LinkedIn",
                        icon: "link",
                        color: Color(red: 0.0, green: 0.47, blue: 0.71),
                        action: shareToLinkedIn
                    )

                    SocialShareButton(
                        platform: "Facebook",
                        icon: "f.square.fill",
                        color: Color(red: 0.23, green: 0.35, blue: 0.6),
                        action: shareToFacebook
                    )
                }
            }
        }
    }

    // MARK: - Past Referrals Content

    private var pastReferralsContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text("No referrals yet")
                .font(.headline)

            Text("Share your link to start earning free months!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(referralLink, forType: .string)

        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedAlert = false
        }

        // Show success feedback
        NSSound.beep()
    }

    private func sendEmail() {
        let subject = "Try EchoTune - Get a Free Month!"
        let body = """
        Hi!

        I've been using EchoTune for voice dictation and it's amazing! 🎙️

        Use my referral link to sign up and you'll get a FREE month of Pro access:
        \(referralLink)

        Once you use 1000 words, we both get an extra free month!

        Hope you enjoy it as much as I do!
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoString = "mailto:\(friendEmail)?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailtoString) {
            NSWorkspace.shared.open(url)
        }

        friendEmail = ""
    }

    private func shareToX() {
        let text = """
        I've been using EchoTune for voice dictation and loving it! 🎙️

        Use my link to get a FREE month: \(referralLink)

        #productivity #AI #voicetyping
        """

        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://twitter.com/intent/tweet?text=\(encodedText)"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func shareToLinkedIn() {
        let urlString = "https://www.linkedin.com/feed/"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        // Copy referral message
        let message = """
        I've been using EchoTune for voice dictation and it's been a game-changer for my productivity! 🎙️

        If you're interested in trying it out, use my referral link to get a FREE month of Pro access:
        \(referralLink)

        #productivity #AI #voicetyping #EchoTune
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
    }

    private func shareToFacebook() {
        let encodedUrl = referralLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.facebook.com/sharer/sharer.php?u=\(encodedUrl)"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - How It Works Row

struct HowItWorksRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Social Share Button

struct SocialShareButton: View {
    let platform: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(platform)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReferralView()
}
