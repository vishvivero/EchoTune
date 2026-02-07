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
    
    // Speech recognition properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Status properties
    @Published var isAvailable = false
    @Published var isPermissionGranted = false
    @Published var isProcessing = false
    @Published var currentText = ""
    
    // Language settings
    @Published var currentLanguage: String = "en-US" {
        didSet {
            setupSpeechRecognizer()
        }
    }

    // Formatting options
    var autoPunctuation = true
    var smartCapitalization = true

    // Task state tracking to prevent multiple simultaneous tasks
    private var isTranscribing = false
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        checkPermission()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage))
        isAvailable = speechRecognizer?.isAvailable ?? false
    }
    
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
    
    func transcribeAudio(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        guard !audioData.isEmpty else {
            completion(.failure(.noAudioData))
            return
        }

        // Route to the appropriate transcription service based on default model
        let selectedModel = AppSettings.shared.defaultTranscriptionModel
        print("🎯 Using transcription model: \(selectedModel)")

        // Route to cloud services if selected
        if selectedModel.hasPrefix("groq-") {
            print("📡 Routing to Groq transcription service")
            routeToGroq(audioData, completion: completion)
            return
        } else if selectedModel.hasPrefix("deepgram-") {
            print("📡 Routing to Deepgram transcription service")
            routeToDeepgram(audioData, completion: completion)
            return
        } else if selectedModel.hasPrefix("whisper-") && selectedModel != "whisper-large-v3-turbo" {
            print("🎙️ Routing to local Whisper engine")
            routeToWhisper(audioData, selectedModel: selectedModel, completion: completion)
            return
        }

        // Default to Apple Speech for "apple-speech" or any unrecognized model
        print("🍎 Using Apple Speech (default)")

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

            print("📄 Wrote audio data to temp file: \(tempURL.path)")
            print("   File size: \(audioData.count) bytes")

            // Use URL-based recognition instead of buffer-based
            // This is more reliable for file-based audio
            let urlRequest = SFSpeechURLRecognitionRequest(url: tempURL)
            urlRequest.shouldReportPartialResults = false

            print("🎯 Starting URL-based speech recognition...")
            print("   File URL: \(tempURL.path)")
            print("   Speech recognizer available: \(self.speechRecognizer != nil)")

            guard let speechRecognizer = self.speechRecognizer else {
                print("❌ Speech recognizer not available")
                self.isProcessing = false
                completion(.failure(.unavailable))
                return
            }

            recognitionTask = speechRecognizer.recognitionTask(with: urlRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Recognition error: \(error)")
                    print("   Error domain: \((error as NSError).domain)")
                    print("   Error code: \((error as NSError).code)")
                    print("   Error description: \(error.localizedDescription)")
                    self.isProcessing = false
                    completion(.failure(.recognitionError(error)))
                    return
                }

                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    print("📝 Transcription result: \(transcription)")
                    self.currentText = transcription

                    // If we're done, return the final result
                    if result.isFinal {
                        print("✅ Final transcription: \(transcription)")
                        self.isProcessing = false

                        // Process text with formatting options
                        let processedText = self.processText(transcription)
                        completion(.success(processedText))
                    }
                } else {
                    print("⚠️ No result and no error - recognition may still be processing")
                }
            }

            if recognitionTask == nil {
                print("❌ Failed to create recognition task")
                self.isProcessing = false
                completion(.failure(.unavailable))
                return
            }

            print("✓ Recognition task created successfully")
        } catch let outerError {
            print("❌ Outer catch block error: \(outerError)")
            print("   Error type: \(type(of: outerError))")
            print("   Error description: \(outerError.localizedDescription)")
            isProcessing = false
            completion(.failure(.audioFormatError))
        }
    }
    
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

    /// Cleans up in-speech corrections, e.g., 'Sorry, it should be 8am', so the transcript only contains the intended/corrected value.
    private func cleanTranscript(_ transcript: String) -> String {
        var result = transcript

        // Pattern 1: "oldValue sorry I meant newValue"
        let pattern1 = #"(\b\w+\b)[^\n.]*?\s+(sorry\s+i\s+meant|actually|no,?\s*i\s+meant|oops,?\s*i\s+meant|correction:?|it should be)\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern1, options: [.caseInsensitive]) {
            let range = NSRange(result.startIndex..., in: result)
            if let match = regex.firstMatch(in: result, options: [], range: range) {
                // Group 1: oldValue, Group 3: newValue
                if let oldRange = Range(match.range(at: 1), in: result),
                   let newRange = Range(match.range(at: 3), in: result) {
                    let oldValue = String(result[oldRange])
                    let newValue = String(result[newRange])
                    // Replace only the last occurrence of oldValue prior to correction
                    if let lastOldRange = result.range(of: oldValue, options: .backwards, range: result.startIndex..<oldRange.upperBound) {
                        result.replaceSubrange(lastOldRange, with: newValue)
                    }
                    // Remove the correction phrase and everything after
                    if let phraseSwiftRange = Range(match.range, in: result) {
                        result = String(result[..<phraseSwiftRange.lowerBound])
                    }
                    // Remove trailing spaces and punctuation, add period if not present
                    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !result.hasSuffix(".") && !result.isEmpty { result += "." }
                }
            }
        }

        // (Pattern 2 and more: add as needed for more complex/future corrections)

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
    
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isProcessing = false
        isTranscribing = false
    }
    
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

    // MARK: - Live Streaming Transcription

    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var bufferCount = 0
    private var totalFrames: AVAudioFrameCount = 0
    private let audioProcessingQueue = DispatchQueue(label: "com.echotune.audioProcessing", qos: .userInitiated)

    // Auto-restart support for long recordings (Apple Speech ~60s timeout)
    private var accumulatedTranscriptions: [String] = []
    private var currentSessionText = ""
    private var liveInputFormat: AVAudioFormat?
    private var liveCompletion: ((Result<String, TranscriptionError>) -> Void)?
    private var sessionRestartCount = 0
    private var lastSessionFrameCount: AVAudioFrameCount = 0
    private static let sessionRestartThresholdSeconds: Double = 50 // Restart before 60s timeout

    func startLiveTranscription(audioFormat: AVAudioFormat, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        print("🎤 Starting live transcription (with auto-restart for long recordings)...")

        // Prevent multiple simultaneous tasks
        guard !isTranscribing else {
            print("⚠️ Already transcribing, ignoring start request")
            return
        }

        // Cancel any existing task before starting new one
        if let existingTask = recognitionTask {
            print("🛑 Cancelling existing recognition task")
            existingTask.cancel()
        }
        recognitionTask = nil
        recognitionRequest = nil

        // Reset counters
        bufferCount = 0
        totalFrames = 0
        accumulatedTranscriptions = []
        currentSessionText = ""
        sessionRestartCount = 0
        lastSessionFrameCount = 0

        guard isAvailable else {
            completion(.failure(.unavailable))
            return
        }

        guard isPermissionGranted else {
            completion(.failure(.permissionDenied))
            return
        }

        isTranscribing = true
        isProcessing = true
        currentText = ""

        // Store for auto-restart
        liveInputFormat = audioFormat
        liveCompletion = completion

        // Create Int16 PCM format for Speech Recognition
        guard let int16Format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: audioFormat.sampleRate,
            channels: audioFormat.channelCount,
            interleaved: false
        ) else {
            print("❌ Failed to create Int16 format")
            completion(.failure(.audioFormatError))
            return
        }

        targetFormat = int16Format

        // Create converter from Float32 to Int16
        guard let converter = AVAudioConverter(from: audioFormat, to: int16Format) else {
            print("❌ Failed to create audio converter")
            completion(.failure(.audioFormatError))
            return
        }

        audioConverter = converter

        // Start the first recognition session
        startRecognitionSession()

        print("✓ Live recognition task started (auto-restart enabled)")
    }

    /// Starts or restarts a recognition session.
    /// Called initially and when a session times out for long recordings.
    private func startRecognitionSession() {
        // Cancel previous session if any
        recognitionTask?.cancel()
        recognitionRequest = nil
        lastSessionFrameCount = 0

        // Create recognition request for live audio
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        guard let speechRecognizer = self.speechRecognizer else {
            print("❌ Speech recognizer not available")
            isProcessing = false
            liveCompletion?(.failure(.unavailable))
            return
        }

        let sessionIndex = sessionRestartCount
        print("🔄 Starting recognition session #\(sessionIndex)")

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self, self.isTranscribing else { return }

            if let error = error {
                let nsError = error as NSError
                print("⚠️ Recognition session #\(sessionIndex) error: \(error.localizedDescription) (code: \(nsError.code))")

                // Check if this is a timeout/limit error that we should recover from
                // Error codes: 203 = "Retry", 209 = "No speech detected", 216 = timeout
                let recoverableCodes = [203, 209, 216, 1110]
                if recoverableCodes.contains(nsError.code) && self.isTranscribing {
                    // Save current partial text and restart
                    if !self.currentSessionText.isEmpty {
                        self.accumulatedTranscriptions.append(self.currentSessionText)
                        print("📝 Saved session #\(sessionIndex) text: \(self.currentSessionText)")
                    }
                    self.currentSessionText = ""
                    self.sessionRestartCount += 1

                    print("🔄 Auto-restarting recognition (session \(self.sessionRestartCount))...")
                    self.startRecognitionSession()
                    return
                }

                // Non-recoverable error
                if !self.accumulatedTranscriptions.isEmpty || !self.currentSessionText.isEmpty {
                    // We have partial results — return them instead of failing
                    if !self.currentSessionText.isEmpty {
                        self.accumulatedTranscriptions.append(self.currentSessionText)
                    }
                    let merged = AudioChunker.mergeTranscriptions(self.accumulatedTranscriptions)
                    let processedText = self.processText(merged)
                    self.isTranscribing = false
                    self.isProcessing = false
                    self.liveCompletion?(.success(processedText))
                } else {
                    self.isTranscribing = false
                    self.isProcessing = false
                    self.liveCompletion?(.failure(.recognitionError(error)))
                }
                return
            }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                self.currentSessionText = transcription

                // Show accumulated + current text
                let allParts = self.accumulatedTranscriptions + [transcription]
                let displayText = AudioChunker.mergeTranscriptions(allParts)
                self.currentText = displayText

                if result.isFinal {
                    print("✅ Session #\(sessionIndex) final: \(transcription)")
                    self.accumulatedTranscriptions.append(transcription)
                    self.currentSessionText = ""

                    // If we're still recording, auto-restart for continued transcription
                    if self.isTranscribing {
                        self.sessionRestartCount += 1
                        print("🔄 Session ended, auto-restarting (session \(self.sessionRestartCount))...")
                        self.startRecognitionSession()
                    }
                }
            }
        }
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Process buffer on background queue to avoid blocking UI
        audioProcessingQueue.async { [weak self] in
            guard let self = self else { return }

            // Convert Float32 buffer to Int16 before sending to Speech Recognition
            guard let converter = self.audioConverter,
                  let targetFormat = self.targetFormat else {
                return
            }

            // Track buffer stats
            self.bufferCount += 1
            self.totalFrames += buffer.frameLength
            self.lastSessionFrameCount += buffer.frameLength

            // Log every 100th buffer to avoid spam
            if self.bufferCount % 100 == 1 || self.bufferCount <= 5 {
                let totalSec = Double(self.totalFrames) / buffer.format.sampleRate
                let sessionSec = Double(self.lastSessionFrameCount) / buffer.format.sampleRate
                print("🎵 Buffer #\(self.bufferCount): total=\(String(format: "%.1f", totalSec))s, session=\(String(format: "%.1f", sessionSec))s")
            }

            // Create output buffer for converted audio
            let frameCapacity = buffer.frameLength
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCapacity
            ) else {
                print("❌ Failed to create converted buffer")
                return
            }

            // Convert the buffer
            var error: NSError?
            var inputConsumed = false
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                if inputConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputConsumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            // Log detailed conversion info for first few buffers
            if self.bufferCount <= 3 {
                print("   Conversion status: \(status)")
                print("   Converted buffer format: \(convertedBuffer.format)")
            }

            if status == .error {
                print("❌ Buffer conversion error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            if status != .haveData {
                return
            }

            // CRITICAL: Set the frame length on the converted buffer
            convertedBuffer.frameLength = buffer.frameLength

            // Verify the buffer has valid data
            if convertedBuffer.frameLength == 0 {
                return
            }

            // Append converted Int16 buffer to recognition request
            self.recognitionRequest?.append(convertedBuffer)
        }
    }

    func endLiveTranscription() {
        print("🛑 Ending live transcription")
        print("📊 Total buffers processed: \(bufferCount)")
        print("📊 Total frames: \(totalFrames) (\(Double(totalFrames) / 48000.0) seconds)")
        print("📊 Sessions used: \(sessionRestartCount + 1)")

        // End audio on current request
        recognitionRequest?.endAudio()
        audioConverter = nil
        targetFormat = nil

        // If we have accumulated text from previous sessions, make sure to include it
        // The completion will be called by the recognition task handler when it gets isFinal
        // But if we're being called because the user stopped recording, we need to handle it

        // Give the recognition task a moment to finalize, then force completion if needed
        let existingAccumulated = accumulatedTranscriptions
        let existingCurrent = currentSessionText
        let existingCompletion = liveCompletion

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            // If still in transcribing state after 2 seconds, force completion with accumulated text
            if self.isTranscribing {
                print("⏱️ Forcing completion after timeout")
                var allParts = existingAccumulated
                if !existingCurrent.isEmpty {
                    allParts.append(existingCurrent)
                }
                if !allParts.isEmpty {
                    let merged = AudioChunker.mergeTranscriptions(allParts)
                    let processedText = self.processText(merged)
                    self.isTranscribing = false
                    self.isProcessing = false
                    existingCompletion?(.success(processedText))
                }
            }
        }

        // Reset state flag
        isTranscribing = false
        liveInputFormat = nil
        liveCompletion = nil
    }

    // MARK: - Model Routing Helpers

    private func routeToGroq(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        // Save audio to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("groq_audio.m4a")
        do {
            try audioData.write(to: tempURL)
            print("📡 Groq: Saved audio to \(tempURL.path)")

            // Use GroqTranscriptionService (needs to be accessed via shared instance if available)
            // For now, fall back to Apple Speech
            print("⚠️ Groq service integration pending - using Apple Speech as fallback")
            transcribeWithAppleSpeech(audioData, completion: completion)
        } catch {
            print("❌ Failed to save audio for Groq: \(error)")
            completion(.failure(.processingError))
        }
    }

    private func routeToDeepgram(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        // Save audio to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("deepgram_audio.m4a")
        do {
            try audioData.write(to: tempURL)
            print("📡 Deepgram: Saved audio to \(tempURL.path)")

            // Use DeepgramTranscriptionService (needs to be accessed via shared instance if available)
            // For now, fall back to Apple Speech
            print("⚠️ Deepgram service integration pending - using Apple Speech as fallback")
            transcribeWithAppleSpeech(audioData, completion: completion)
        } catch {
            print("❌ Failed to save audio for Deepgram: \(error)")
            completion(.failure(.processingError))
        }
    }

    private func routeToWhisper(_ audioData: Data, selectedModel: String, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        print("🎙️ Whisper: Using model \(selectedModel)")
        // Save audio to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("whisper_audio.m4a")
        do {
            try audioData.write(to: tempURL)
            print("🎙️ Whisper: Saved audio to \(tempURL.path)")

            // Use WhisperEngine (needs to be accessed via shared instance if available)
            // For now, fall back to Apple Speech
            print("⚠️ Whisper engine integration pending - using Apple Speech as fallback")
            transcribeWithAppleSpeech(audioData, completion: completion)
        } catch {
            print("❌ Failed to save audio for Whisper: \(error)")
            completion(.failure(.processingError))
        }
    }

    private func transcribeWithAppleSpeech(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
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

            print("📄 Wrote audio data to temp file: \(tempURL.path)")
            print("   File size: \(audioData.count) bytes")

            // Use URL-based recognition instead of buffer-based
            let urlRequest = SFSpeechURLRecognitionRequest(url: tempURL)
            urlRequest.shouldReportPartialResults = false

            print("🎯 Starting URL-based speech recognition...")

            guard let speechRecognizer = self.speechRecognizer else {
                print("❌ Speech recognizer not available")
                self.isProcessing = false
                completion(.failure(.unavailable))
                return
            }

            recognitionTask = speechRecognizer.recognitionTask(with: urlRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Recognition error: \(error)")
                    self.isProcessing = false
                    completion(.failure(.recognitionError(error)))
                    return
                }

                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    self.currentText = transcription

                    if result.isFinal {
                        print("✅ Final transcription: \(transcription)")
                        self.isProcessing = false
                        let processedText = self.processText(transcription)
                        completion(.success(processedText))
                    }
                }
            }

            if recognitionTask == nil {
                print("❌ Failed to create recognition task")
                self.isProcessing = false
                completion(.failure(.unavailable))
            }
        } catch {
            print("❌ Error: \(error)")
            isProcessing = false
            completion(.failure(.audioFormatError))
        }
    }
}