//
//  OnboardingSound.swift
//  EchoTune
//
//  Onboarding 7.5.1: branded onboarding sound design. A soft intro chime
//  plays when the onboarding window appears (like superwhisper's intro),
//  and a subtle pop accompanies each step transition.
//

import AVFoundation
import Foundation

enum OnboardingSound {
    enum Sound: String {
        /// Soft two-note branded chime — onboarding window appear.
        case intro = "onboarding-intro"
        /// Short percussive pop — step transitions / Get Started.
        case pop = "onboarding-pop"
        /// Confirmation tick — shortcut saved / permission granted.
        case confirm = "onboarding-confirm"
    }

    private static var players: [Sound: AVAudioPlayer] = [:]
    private static let queue = DispatchQueue(label: "com.echotune.onboarding-sound")

    /// Plays the given sound once. Safe to call from any thread; failures are
    /// silent so a missing asset can never break the onboarding flow.
    static func play(_ sound: Sound, volume: Float? = nil) {
        queue.async {
            let player = player(for: sound)
            player?.volume = volume ?? defaultVolume(for: sound)
            player?.currentTime = 0
            player?.play()
        }
    }

    private static func defaultVolume(for sound: Sound) -> Float {
        switch sound {
        case .intro: return 0.32
        case .pop: return 0.22
        case .confirm: return 0.26
        }
    }

    private static func player(for sound: Sound) -> AVAudioPlayer? {
        if let cached = players[sound] { return cached }

        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a") else {
            debugLog("⚠️ Onboarding sound '\(sound.rawValue).m4a' not found in bundle")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[sound] = player
            return player
        } catch {
            debugLog("⚠️ Failed to load onboarding sound '\(sound.rawValue)': \(error.localizedDescription)")
            return nil
        }
    }
}
