//
//  TranscriptionEngine.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import Speech
import AVFoundation
import Combine

class TranscriptionEngine: NSObject, ObservableObject {
    static let shared = TranscriptionEngine()

    enum TranscriptionError: Error {
        case audioFormatError
        case recognitionError(Error)
        case permissionDenied
        case unavailable
        case noAudioData
        case processingError
    }

    // MARK: - Speech Recognition Properties

    // Internal for cross-file extension access (TranscriptionEngine+Routing, +LiveStreaming)
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?

    // MARK: - Status Properties

    @Published var isAvailable = false
    @Published var isPermissionGranted = false
    @Published var isProcessing = false
    @Published var currentText = ""

    // MARK: - Language Settings

    @Published var currentLanguage: String = "en-US" {
        didSet {
            setupSpeechRecognizer()
        }
    }

    // MARK: - Formatting Options

    var autoPunctuation = true
    var smartCapitalization = true

    // Task state tracking to prevent multiple simultaneous tasks
    // Internal for cross-file extension access (TranscriptionEngine+LiveStreaming)
    var isTranscribing = false

    // MARK: - Live Streaming Properties
    // Stored properties must remain in the class definition (Swift extensions cannot have stored properties).
    // Internal for cross-file extension access (TranscriptionEngine+LiveStreaming).

    var audioConverter: AVAudioConverter?
    var targetFormat: AVAudioFormat?
    var bufferCount = 0
    var totalFrames: AVAudioFrameCount = 0
    let audioProcessingQueue = DispatchQueue(label: "com.echotune.audioProcessing", qos: .userInitiated)

    // Auto-restart support for long recordings (Apple Speech ~60s timeout)
    var accumulatedTranscriptions: [String] = []
    var currentSessionText = ""
    var liveInputFormat: AVAudioFormat?
    var liveCompletion: ((Result<String, TranscriptionError>) -> Void)?
    var sessionRestartCount = 0
    var lastSessionFrameCount: AVAudioFrameCount = 0
    static let sessionRestartThresholdSeconds: Double = 50 // Restart before 60s timeout

    // MARK: - Initialization

    override init() {
        super.init()
        setupSpeechRecognizer()
        // Don't request Speech Recognition authorization eagerly on init.
        // EchoTune primarily uses WhisperKit/Groq — only request Apple Speech
        // permission when the user actually selects an Apple Speech model.
        checkPermissionStatus()
    }

    // MARK: - Speech Recognizer Setup

    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage))
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Permission Handling

    /// Non-prompting check — reads the current authorization status without triggering a dialog
    func checkPermissionStatus() {
        let status = SFSpeechRecognizer.authorizationStatus()
        DispatchQueue.main.async {
            self.isPermissionGranted = (status == .authorized)
        }
    }

    /// Prompting check — only call this when Apple Speech transcription is actually needed
    func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isPermissionGranted = true
                case .denied, .restricted, .notDetermined:
                    self?.isPermissionGranted = false
                @unknown default:
                    self?.isPermissionGranted = false
                }
            }
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                let granted = status == .authorized
                self.isPermissionGranted = granted
                completion(granted)
            }
        }
    }

    // MARK: - Main Transcription Entry Point

    func transcribeAudio(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        guard !audioData.isEmpty else {
            completion(.failure(.noAudioData))
            return
        }

        // Route to the appropriate transcription service based on default model.
        // This uses AppSettings.defaultTranscriptionModel which is kept in sync
        // with ModelManager.currentModel via setCurrentModel().
        let selectedModel = AppSettings.shared.defaultTranscriptionModel
        debugLog("🎯 Using transcription model: \(selectedModel)")

        // Route to cloud services
        if selectedModel.hasPrefix("groq-") {
            routeToGroq(audioData, completion: completion)
            return
        } else if selectedModel.hasPrefix("deepgram-") {
            routeToDeepgram(audioData, completion: completion)
            return
        } else if selectedModel != "apple-speech" {
            // Any non-Apple-Speech, non-cloud model is a local Whisper model
            debugLog("🎙️ Routing to local Whisper engine")
            routeToWhisper(audioData, selectedModel: selectedModel, completion: completion)
            return
        }

        // Default to Apple Speech for "apple-speech" or unrecognized models
        debugLog("🍎 Using Apple Speech (default)")

        guard isAvailable else {
            completion(.failure(.unavailable))
            return
        }

        guard isPermissionGranted else {
            completion(.failure(.permissionDenied))
            return
        }

        isProcessing = true
        currentText = ""

        // Create temporary file for audio data (using CAF format for better Float32 support)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("transcription.caf")

        do {
            try audioData.write(to: tempURL)

            debugLog("📄 Wrote audio data to temp file: \(tempURL.path)")
            debugLog("   File size: \(audioData.count) bytes")

            // Use URL-based recognition instead of buffer-based
            // This is more reliable for file-based audio
            let urlRequest = SFSpeechURLRecognitionRequest(url: tempURL)
            urlRequest.shouldReportPartialResults = false

            debugLog("🎯 Starting URL-based speech recognition...")
            debugLog("   File URL: \(tempURL.path)")
            debugLog("   Speech recognizer available: \(self.speechRecognizer != nil)")

            guard let speechRecognizer = self.speechRecognizer else {
                debugLog("❌ Speech recognizer not available")
                self.isProcessing = false
                completion(.failure(.unavailable))
                return
            }

            recognitionTask = speechRecognizer.recognitionTask(with: urlRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let error = error {
                    debugLog("❌ Recognition error: \(error)")
                    debugLog("   Error domain: \((error as NSError).domain)")
                    debugLog("   Error code: \((error as NSError).code)")
                    debugLog("   Error description: \(error.localizedDescription)")
                    self.isProcessing = false
                    completion(.failure(.recognitionError(error)))
                    return
                }

                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    debugLog("📝 Transcription result: \(transcription)")
                    self.currentText = transcription

                    // If we're done, return the final result
                    if result.isFinal {
                        debugLog("✅ Final transcription: \(transcription)")
                        self.isProcessing = false

                        // Process text with formatting options
                        let processedText = self.processText(transcription)
                        completion(.success(processedText))
                    }
                } else {
                    debugLog("⚠️ No result and no error - recognition may still be processing")
                }
            }

            if recognitionTask == nil {
                debugLog("❌ Failed to create recognition task")
                self.isProcessing = false
                completion(.failure(.unavailable))
                return
            }

            debugLog("✓ Recognition task created successfully")
        } catch let outerError {
            debugLog("❌ Outer catch block error: \(outerError)")
            debugLog("   Error type: \(type(of: outerError))")
            debugLog("   Error description: \(outerError.localizedDescription)")
            isProcessing = false
            completion(.failure(.audioFormatError))
        }
    }

    // MARK: - Text Processing

    func processText(_ text: String) -> String {
        var processedText = text

        // Auto-correction: clean up in-speech corrections if toggle is ON
        if AppSettings.shared.autoCorrection {
            processedText = cleanTranscript(processedText)
        }

        if smartCapitalization {
            // Apply smart capitalization
            processedText = applySentenceCapitalization(processedText)
        }

        return processedText
    }

    /// Cleans up explicit in-speech corrections, e.g., 'Sorry, I meant 8am'.
    /// Only matches deliberate correction phrases — NOT the bare word "actually"
    /// which is common filler and would destroy most transcriptions.
    private func cleanTranscript(_ transcript: String) -> String {
        var result = transcript

        // Pattern: "oldValue <correction phrase> newValue"
        // Correction phrases must be unambiguous self-correction signals.
        // "actually" removed — it's normal filler, not a correction trigger.
        let pattern1 = #"(\b\w+\b)[^\n.]{0,30}\s+(sorry\s+i\s+meant|no,?\s+i\s+meant|oops,?\s+i\s+meant|correction:?\s*|it\s+should\s+be)\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern1, options: [.caseInsensitive]) {
            let range = NSRange(result.startIndex..., in: result)
            if let match = regex.firstMatch(in: result, options: [], range: range) {
                if let oldRange = Range(match.range(at: 1), in: result),
                   let newRange = Range(match.range(at: 3), in: result),
                   let fullMatchRange = Range(match.range, in: result) {
                    let oldValue = String(result[oldRange])
                    let newValue = String(result[newRange])
                    // Replace the old value with the new one
                    if let lastOldRange = result.range(of: oldValue, options: .backwards, range: result.startIndex..<oldRange.upperBound) {
                        result.replaceSubrange(lastOldRange, with: newValue)
                    }
                    // Remove only the correction phrase itself, keep everything after
                    // Find the end of the match and preserve the rest of the text
                    let afterMatch = String(result[fullMatchRange.upperBound...])
                    let beforeMatch = String(result[..<fullMatchRange.lowerBound])
                    result = beforeMatch + newValue + afterMatch
                    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return result
    }

    private func applySentenceCapitalization(_ text: String) -> String {
        // Split text into sentences and capitalize first letter of each
        let sentences = text.components(separatedBy: ". ")
        let capitalizedSentences = sentences.map { sentence in
            if sentence.isEmpty { return sentence }
            let firstChar = sentence.prefix(1).uppercased()
            let restOfSentence = sentence.dropFirst()
            return firstChar + restOfSentence
        }

        return capitalizedSentences.joined(separator: ". ")
    }

    // MARK: - Cancellation

    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isProcessing = false
        isTranscribing = false
    }

    // MARK: - Available Languages

    // Get available languages
    func getAvailableLanguages() -> [String] {
        return SFSpeechRecognizer.supportedLocales().map { $0.identifier }.sorted()
    }

    // MARK: - Convenience methods for AppCoordinator compatibility

    // Get authorization status
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        return SFSpeechRecognizer.authorizationStatus()
    }

    // Alias for requestPermission
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        requestPermission(completion: completion)
    }

    // Alias for transcribeAudio
    func transcribe(audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        transcribeAudio(audioData, completion: completion)
    }
}
