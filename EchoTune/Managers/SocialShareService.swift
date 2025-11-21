//
//  SocialShareService.swift
//  EchoTune
//
//  Phase 6A: Social Share for Discount
//  Share EchoTune on social media to unlock a 30% discount
//

import Foundation
import AppKit
import SwiftUI
import Combine

class SocialShareService: ObservableObject {
    static let shared = SocialShareService()

    @Published var hasShared: Bool = false
    @Published var discountCode: String?

    private let discountPercentage = 30

    private init() {
        // Load saved state
        hasShared = AppSettings.shared.hasSharedForDiscount
        discountCode = AppSettings.shared.socialShareDiscountCode

        print("✅ SocialShareService initialized")
    }

    // MARK: - Share Methods

    /// Show share sheet to share EchoTune on social media
    func showShareSheet() {
        let shareText = """
        Just discovered EchoTune - the best AI voice dictation for Mac! 🎙️✨

        Context-aware transcription that adapts to what you're working on. Lightning-fast with Groq, enhanced with AI post-processing, and 100% private.

        Check it out: https://echotune.app
        #EchoTune #MacOS #Productivity #AI
        """

        let shareItems: [Any] = [shareText]

        let activityController = NSSharingServicePicker(items: shareItems)

        if let window = NSApp.keyWindow {
            // Show share sheet anchored to window
            if let contentView = window.contentView {
                let rect = NSRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 0, height: 0)
                activityController.show(relativeTo: rect, of: contentView, preferredEdge: .minY)

                // Mark as shared after a delay (assume they completed sharing)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.markAsShared()
                }
            }
        }
    }

    /// Show Twitter/X share URL
    func shareOnTwitter() {
        let tweetText = "Just discovered EchoTune - the best AI voice dictation for Mac! 🎙️✨ Context-aware, lightning-fast, and 100% private. Check it out: https://echotune.app #EchoTune #MacOS #Productivity"

        if let encodedText = tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
            NSWorkspace.shared.open(url)

            // Mark as shared after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.markAsShared()
            }
        }
    }

    /// Show LinkedIn share URL
    func shareOnLinkedIn() {
        let shareURL = "https://echotune.app"

        if let encodedURL = shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.linkedin.com/sharing/share-offsite/?url=\(encodedURL)") {
            NSWorkspace.shared.open(url)

            // Mark as shared after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.markAsShared()
            }
        }
    }

    /// Show Facebook share URL
    func shareOnFacebook() {
        let shareURL = "https://echotune.app"

        if let encodedURL = shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.facebook.com/sharer/sharer.php?u=\(encodedURL)") {
            NSWorkspace.shared.open(url)

            // Mark as shared after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.markAsShared()
            }
        }
    }

    /// Copy share text to clipboard
    func copyShareText() {
        let shareText = """
        Just discovered EchoTune - the best AI voice dictation for Mac! 🎙️✨

        Context-aware transcription that adapts to what you're working on. Lightning-fast with Groq, enhanced with AI post-processing, and 100% private.

        Check it out: https://echotune.app
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shareText, forType: .string)

        print("📋 Share text copied to clipboard")

        // Show notification
        NotificationManager.shared.showNotification(
            title: "Share Text Copied",
            body: "Paste it on your favorite social platform to unlock your discount!",
            sound: false
        )

        // Don't auto-mark as shared for clipboard - user must manually confirm
    }

    // MARK: - Discount Code Management

    /// Generate a unique discount code for the user
    func generateDiscountCode() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = String(format: "%04d", Int.random(in: 0...9999))
        return "SHARE\(discountPercentage)-\(timestamp)-\(random)"
    }

    /// Mark that user has shared and generate discount code
    func markAsShared() {
        guard !hasShared else {
            print("⚠️ User already shared and received discount")
            return
        }

        // Generate discount code
        let code = generateDiscountCode()
        discountCode = code
        hasShared = true

        // Save to settings
        AppSettings.shared.hasSharedForDiscount = true
        AppSettings.shared.socialShareDiscountCode = code

        print("✅ User shared! Discount code generated: \(code)")

        // Show success notification
        DispatchQueue.main.async {
            NotificationManager.shared.showNotification(
                title: "🎉 Discount Unlocked!",
                body: "Thank you for sharing! Your \(self.discountPercentage)% discount code: \(code)",
                sound: true
            )
        }

        // TODO: Send code to backend for validation
        // reportShareToBackend(code: code)
    }

    /// Manually confirm share (for clipboard method)
    func confirmShare() {
        markAsShared()
    }

    // MARK: - Backend Integration (TODO)

    private func reportShareToBackend(code: String) {
        // TODO: Send discount code to backend for tracking and validation
        // This ensures codes are unique and can be validated during purchase
        /*
        let endpoint = "https://api.echotune.app/v1/discount-codes"
        let body = ["code": code, "type": "social_share", "discount": discountPercentage]

        // POST request to backend
        */
    }

    // MARK: - Helper Methods

    func getDiscountInfo() -> String {
        if let code = discountCode {
            return "Your \(discountPercentage)% discount code: \(code)"
        } else {
            return "Share EchoTune to unlock \(discountPercentage)% off!"
        }
    }

    func hasValidDiscount() -> Bool {
        return hasShared && discountCode != nil
    }
}
