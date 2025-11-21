//
//  SoundManager.swift
//  EchoTune
//
//  Handles audio feedback sounds for recording events
//

import Foundation
import AppKit

class SoundManager {
    static let shared = SoundManager()

    private var startSound: NSSound?
    private var stopSound: NSSound?

    private init() {
        setupSounds()
    }

    private func setupSounds() {
        // Use system sounds for simplicity and reliability
        // Alternatively, we can use simple sound IDs

        // Start sound - use a system beep (higher)
        startSound = NSSound(named: "Tink") // Short, high-pitched click

        // Stop sound - use a different system beep (lower)
        stopSound = NSSound(named: "Pop") // Short, subtle pop

        // Set volume
        startSound?.volume = 0.3
        stopSound?.volume = 0.3

        print("✓ Sound manager initialized with system sounds")
    }

    func playStartSound() {
        guard AppSettings.shared.playSoundOnStartStop else { return }

        startSound?.stop() // Stop if already playing
        startSound?.play()
        print("🔊 Playing start sound")
    }

    func playStopSound() {
        guard AppSettings.shared.playSoundOnStartStop else { return }

        stopSound?.stop() // Stop if already playing
        stopSound?.play()
        print("🔊 Playing stop sound")
    }
}
