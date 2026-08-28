//
//  AppCoordinator+Transcription.swift
//  EchoTune
//
//  Whisper/Apple Speech result handling, text processing, insertion, and statistics.
//

import Foundation
import AppKit
import os.log

// MARK: - Transcription Handling

extension AppCoordinator {

    // Guard against duplicate transcription callbacks
    private static var lastTranscriptionId: UUID?

    func resetCurrentProcessingState(for model: AIModel? = nil) {
        currentProcessingMetadata = TranscriptionProcessingMetadata()
        recordingStartedAt = nil
        transcriptionPhaseStartedAt = nil
        enhancementPhaseStartedAt = nil
        appState.recordingStatusDetail = nil

        guard let model else { return }
        currentProcessingMetadata.transcriptionProvider = transcriptionProviderName(for: model)
        currentProcessingMetadata.transcriptionModel = transcriptionModelName(for: model)
    }

    func startRecordingAudit(for model: AIModel) {
        resetCurrentProcessingState(for: model)
        recordingStartedAt = Date()
        appState.recordingStatusDetail = recordingDetailText(for: model)
    }

    func beginTranscriptionAudit(provider: String? = nil, model: String? = nil, detail: String) {
        transcriptionPhaseStartedAt = Date()
        if let provider { currentProcessingMetadata.transcriptionProvider = provider }
        if let model { currentProcessingMetadata.transcriptionModel = model }
        appState.recordingStatusDetail = detail
    }

    func completeTranscriptionAudit() {
        if let startedAt = transcriptionPhaseStartedAt {
            currentProcessingMetadata.transcriptionLatency = Date().timeIntervalSince(startedAt)
        }
        if let recordingStartedAt {
            currentProcessingMetadata.totalLatency = Date().timeIntervalSince(recordingStartedAt)
        }
    }

    func beginEnhancementAudit(using model: AIEnhancementEngine.EnhancementModel) {
        enhancementPhaseStartedAt = Date()
        currentProcessingMetadata.enhancementProvider = model.provider.displayName
        currentProcessingMetadata.enhancementModel = model.shortName
        appState.recordingStatusDetail = "Enhancing with \(model.provider.displayName)..."
        PerformanceMonitor.shared.startEnhancement(engine: model.provider.displayName, model: model.shortName)
    }

    func completeEnhancementAudit() {
        if let startedAt = enhancementPhaseStartedAt {
            currentProcessingMetadata.enhancementLatency = Date().timeIntervalSince(startedAt)
        }
        if let recordingStartedAt {
            currentProcessingMetadata.totalLatency = Date().timeIntervalSince(recordingStartedAt)
        }
        PerformanceMonitor.shared.endEnhancement(
            fallbackUsed: currentProcessingMetadata.usedFallback,
            reason: currentProcessingMetadata.fallbackReason
        )
    }

    func markEnhancementFallback(reason: String) {
        currentProcessingMetadata.usedFallback = true
        currentProcessingMetadata.fallbackReason = reason
    }

    func finalisedProcessingMetadata(recordingDuration: TimeInterval, audioByteCount: Int?) -> TranscriptionProcessingMetadata {
        var metadata = currentProcessingMetadata
        metadata.recordingDuration = recordingDuration
        if metadata.audioByteCount == nil {
            metadata.audioByteCount = audioByteCount
        }
        if metadata.totalLatency == nil, let recordingStartedAt {
            metadata.totalLatency = Date().timeIntervalSince(recordingStartedAt)
        }
        return metadata
    }

    func clearCurrentProcessingState() {
        resetCurrentProcessingState()
    }

    private func transcriptionProviderName(for model: AIModel) -> String {
        if model.category == .cloud {
            if model.id.contains("groq") {
                return "Groq"
            } else if model.id.contains("deepgram") {
                return "Deepgram"
            }
            return "Cloud"
        }

        if model.category == .local && !model.isBuiltIn {
            return "Local Whisper"
        }

        return "Apple Speech"
    }

    private func transcriptionModelName(for model: AIModel) -> String {
        if model.id == "groq-whisper-large-v3-turbo" {
            return "whisper-large-v3-turbo"
        }
        if model.id.contains("deepgram") {
            return "nova-2"
        }
        return model.name
    }

    private func recordingDetailText(for model: AIModel) -> String {
        switch transcriptionProviderName(for: model) {
        case "Groq":
            return "Recording for Groq Whisper..."
        case "Deepgram":
            return "Recording for Deepgram..."
        case "Local Whisper":
            return "Recording locally with \(model.name)..."
        default:
            return "Recording with Apple Speech..."
        }
    }

    // MARK: - Whisper Result

    func handleWhisperResult(_ result: Result<WhisperTranscriptionResult, WhisperEngine.WhisperError>) {
        switch result {
        case .success(let payload):
            os_log("📝 handleWhisperResult SUCCESS text='%@' len=%d", log: appLog, type: .info, payload.outputText, payload.outputText.count)
        case .failure(let error):
            os_log("📝 handleWhisperResult FAILURE error=%{public}@", log: appLog, type: .error, "\(error)")
        }
        let recordingDuration = audioManager.getRecordingDuration()

        // Dismiss processing notification
        notificationManager.dismissProcessingNotification()

        switch result {
        case .success(let payload):
            completeTranscriptionAudit()
            PerformanceMonitor.shared.endTranscription(wordCount: payload.outputText.split(separator: " ").count)
            os_log("✅ Whisper success: '%@' words=%d dur=%.1f", log: appLog, type: .info, payload.outputText, payload.outputText.split(separator: " ").count, recordingDuration)

            self.errorLogger.logInfo("Whisper transcription successful", category: "Transcription", context: [
                "wordCount": "\(payload.outputText.split(separator: " ").count)",
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s",
                "model": self.modelManager.currentModel?.name ?? "unknown",
                "detectedLanguage": payload.detectedLanguage ?? "unknown",
                "translated": payload.wasTranslated ? "true" : "false"
            ])

            processAndInsertText(
                FinalizedTranscription(
                    outputText: payload.outputText,
                    originalText: payload.originalText,
                    translatedText: payload.translatedText,
                    detectedLanguage: payload.detectedLanguage
                ),
                recordingDuration: recordingDuration
            )

        case .failure(let error):
            os_log("❌ Whisper FAILURE: %{public}@", log: appLog, type: .error, "\(error)")

            self.errorLogger.logError(error, category: "Transcription", context: [
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s",
                "model": self.modelManager.currentModel?.name ?? "unknown"
            ])

            handleTranscriptionError(error.localizedDescription)
        }
    }

    // MARK: - Apple Speech Result

    func handleTranscriptionResult(_ result: Result<String, TranscriptionEngine.TranscriptionError>) {
        let recordingDuration = audioManager.getRecordingDuration()

        // Dismiss processing notification
        notificationManager.dismissProcessingNotification()

        switch result {
        case .success(let transcribedText):
            completeTranscriptionAudit()
            PerformanceMonitor.shared.endTranscription(wordCount: transcribedText.split(separator: " ").count)
            debugLog("✅ Apple Speech transcription successful: \(transcribedText)")

            self.errorLogger.logInfo("Apple Speech transcription successful", category: "Transcription", context: [
                "wordCount": "\(transcribedText.split(separator: " ").count)",
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s"
            ])

            processAndInsertText(
                FinalizedTranscription(
                    outputText: transcribedText,
                    originalText: transcribedText,
                    translatedText: nil,
                    detectedLanguage: nil
                ),
                recordingDuration: recordingDuration
            )

        case .failure(let error):
            debugLog("❌ Apple Speech transcription failed: \(error)")

            self.errorLogger.logError(error, category: "Transcription", context: [
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s"
            ])

            handleTranscriptionError(error.localizedDescription)
        }
    }

    // MARK: - Text Processing & Insertion

    func processAndInsertText(_ transcription: FinalizedTranscription, recordingDuration: TimeInterval) {
        // Guard: only process if we're in .processing state (prevents double-fire)
        guard case .processing = appState.recordingState else {
            debugLog("⚠️ processAndInsertText called but state is \(appState.recordingState) — skipping duplicate")
            return
        }

        var transcribedText = transcription.outputText

        // Deduplicate repeated Whisper output — Whisper sometimes echoes the transcript
        transcribedText = deduplicateWhisperOutput(transcribedText)

        // Validate transcription - detect silence/hallucinations
        if isLikelyHallucination(transcribedText, recordingDuration: recordingDuration) {
            debugLog("⚠️ Detected likely hallucination or silence, not inserting text: '\(transcribedText)'")

            // Show a subtle notification
            self.notificationManager.showNotification(
                title: "No Speech Detected",
                body: "No clear speech was detected in the recording.",
                sound: false
            )

            // Reset state
            self.appState.recordingState = .idle
            self.appState.recordingStatusDetail = nil

            // Update status bar
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let statusBar = appDelegate.statusBarController {
                statusBar.updateIcon(for: .idle)
            }

            clearCurrentProcessingState()
            return
        }

        // Post live transcription update for mini recorder
        NotificationCenter.default.post(
            name: NSNotification.Name("LiveTranscriptionUpdate"),
            object: nil,
            userInfo: ["text": transcribedText]
        )

        appState.recordingStatusDetail = "Cleaning transcript..."

        // Apply text processing
        let processedText = self.processTranscription(transcribedText)

        // Phase 6D: Trigger Word Detection — scan before AI enhancement
        let triggerResult = AIEnhancementEngine.shared.detectTriggerWords(in: processedText)
        let textForEnhancement = triggerResult.cleanedTranscript
        let shouldEnhance = settings.aiEnhancementEnabled || triggerResult.shouldForceAI
        let overridePrompt = triggerResult.overridePrompt
        let rawTranscriptionText = textForEnhancement

        if let matched = triggerResult.matchedRule {
            debugLog("🎯 Trigger word matched: \"\(matched.triggerPhrase)\" → using custom prompt")
        }

        // Phase 6A: AI Enhancement (if enabled or trigger word forces it)
        if shouldEnhance {
            debugLog("🎨 AI Enhancement active\(triggerResult.shouldForceAI ? " (triggered by keyword)" : ""), enhancing transcription...")

            // Get appropriate API key based on selected model
            let modelString = settings.selectedEnhancementModel
            guard let model = AIEnhancementEngine.EnhancementModel(rawValue: modelString) else {
                debugLog("⚠️ Invalid enhancement model: \(modelString)")
                markEnhancementFallback(reason: "Invalid enhancement model")
                insertTextWithAutoSend(
                    textForEnhancement,
                    recordingDuration: recordingDuration,
                    originalText: transcription.originalText,
                    translatedText: transcription.translatedText,
                    detectedLanguage: transcription.detectedLanguage,
                    rawTranscriptionText: rawTranscriptionText
                )
                return
            }

            let apiKey = settings.apiKey(for: model.provider)

            guard !apiKey.isEmpty else {
                debugLog("⚠️ No API key configured for AI enhancement")
                markEnhancementFallback(reason: "Missing \(model.provider.displayName) API key")
                notificationManager.showNotification(
                    title: "AI Enhancement Disabled",
                    body: "Please add your API key in Settings > Advanced > AI Enhancement",
                    sound: false
                )
                insertTextWithAutoSend(
                    textForEnhancement,
                    recordingDuration: recordingDuration,
                    originalText: transcription.originalText,
                    translatedText: transcription.translatedText,
                    detectedLanguage: transcription.detectedLanguage,
                    rawTranscriptionText: rawTranscriptionText
                )
                return
            }

            // Get dictionary context if available
            let dictionaryContext = DictionaryManager.shared.correctSpellings.map { $0.word }.joined(separator: ", ")

            // Determine which prompt to use: trigger word prompt overrides custom/default
            let promptToUse = overridePrompt ?? (settings.customEnhancementPrompt.isEmpty ? nil : settings.customEnhancementPrompt)

            beginEnhancementAudit(using: model)

            // Enhance asynchronously
            Task {
                do {
                    let enhanced = try await AIEnhancementEngine.shared.enhance(
                        textForEnhancement,
                        using: model,
                        apiKey: apiKey,
                        customPrompt: promptToUse,
                        dictionaryContext: dictionaryContext.isEmpty ? nil : dictionaryContext
                    )

                    await MainActor.run {
                        debugLog("✅ AI Enhancement successful")
                        self.completeEnhancementAudit()
                        self.insertTextWithAutoSend(
                            enhanced,
                            recordingDuration: recordingDuration,
                            originalText: transcription.originalText,
                            translatedText: transcription.translatedText,
                            detectedLanguage: transcription.detectedLanguage,
                            rawTranscriptionText: rawTranscriptionText
                        )
                    }
                } catch {
                    await MainActor.run {
                        debugLog("❌ AI Enhancement failed: \(error.localizedDescription)")
                        self.markEnhancementFallback(reason: error.localizedDescription)
                        self.completeEnhancementAudit()
                        self.notificationManager.showNotification(
                            title: "Enhancement Failed",
                            body: "Using original transcription. Error: \(error.localizedDescription)",
                            sound: false
                        )
                        self.insertTextWithAutoSend(
                            textForEnhancement,
                            recordingDuration: recordingDuration,
                            originalText: transcription.originalText,
                            translatedText: transcription.translatedText,
                            detectedLanguage: transcription.detectedLanguage,
                            rawTranscriptionText: rawTranscriptionText
                        )
                    }
                }
            }
            return
        }

        // No AI enhancement, insert directly
        insertTextWithAutoSend(
            textForEnhancement,
            recordingDuration: recordingDuration,
            originalText: transcription.originalText,
            translatedText: transcription.translatedText,
            detectedLanguage: transcription.detectedLanguage,
            rawTranscriptionText: rawTranscriptionText
        )
    }

    // Phase 6A: Insert text with optional auto-send
    func insertTextWithAutoSend(
        _ processedText: String,
        recordingDuration: TimeInterval,
        originalText: String? = nil,
        translatedText: String? = nil,
        detectedLanguage: String? = nil,
        rawTranscriptionText: String? = nil
    ) {
        appState.recordingStatusDetail = "Finalising text..."

        let wordCount = processedText.split(separator: " ").count
        let audioByteCount = self.lastRecordedAudioData?.count
        let processingMetadata = finalisedProcessingMetadata(
            recordingDuration: recordingDuration,
            audioByteCount: audioByteCount
        )

        // Post final transcription for mini recorder
        NotificationCenter.default.post(
            name: NSNotification.Name("TranscriptionComplete"),
            object: nil,
            userInfo: [
                "text": processedText,
                "transcriptionProvider": processingMetadata.transcriptionProvider ?? "",
                "transcriptionModel": processingMetadata.transcriptionModel ?? "",
                "enhancementProvider": processingMetadata.enhancementProvider ?? "",
                "enhancementModel": processingMetadata.enhancementModel ?? "",
                "transcriptionLatency": processingMetadata.transcriptionLatency ?? 0,
                "enhancementLatency": processingMetadata.enhancementLatency ?? 0,
                "totalLatency": processingMetadata.totalLatency ?? 0,
                "usedFallback": processingMetadata.usedFallback,
                "fallbackReason": processingMetadata.fallbackReason ?? ""
            ]
        )

        // Save audio file for retention — only when the user opted in.
        var savedAudioPath: String? = nil
        if AppSettings.shared.keepAudioHistory,
           let audioData = self.lastRecordedAudioData, !audioData.isEmpty {
            let fileId = UUID()
            savedAudioPath = TranscriptionHistoryManager.shared.saveAudioFile(data: audioData, id: fileId)
        }
        self.lastRecordedAudioData = nil // Always clear — never hold audio the user didn't ask to keep

        // Add to history (with audio file path if saved)
        let historyItem = TranscriptionHistoryManager.shared.addTranscription(
            processedText,
            duration: recordingDuration,
            audioFilePath: savedAudioPath,
            originalText: originalText ?? processedText,
            translatedText: translatedText,
            detectedLanguage: detectedLanguage,
            rawTranscriptionText: rawTranscriptionText ?? processedText,
            processingMetadata: processingMetadata
        )

        // Insert text directly with performance monitoring
        let insertionStartedAt = Date()
        PerformanceMonitor.shared.startTextInsertion()

        self.textInsertionManager.insertText(processedText) { result in
            PerformanceMonitor.shared.endTextInsertion()

            let insertionLatency = Date().timeIntervalSince(insertionStartedAt)
            TranscriptionHistoryManager.shared.updateProcessingMetadata(for: historyItem.id) { metadata in
                metadata.textInsertionLatency = insertionLatency
                if let recordingStartedAt = self.recordingStartedAt {
                    metadata.totalLatency = Date().timeIntervalSince(recordingStartedAt)
                } else if let existingTotal = metadata.totalLatency {
                    metadata.totalLatency = existingTotal + insertionLatency
                } else {
                    metadata.totalLatency = insertionLatency
                }
            }

            switch result {
            case .success:
                self.errorLogger.logInfo("Text inserted directly", category: "TextInsertion")

                // Phase 6A: Auto-Send After Paste (if enabled)
                if AutoSendService.shared.shouldTriggerAutoSend() {
                    debugLog("📤 Auto-send enabled for this app, sending...")
                    AutoSendService.shared.sendAfterDelay(0.2) // 200ms delay
                }

            case .failure(let error):
                self.errorLogger.logWarning(error.localizedDescription, category: "TextInsertion")
                // Fallback to clipboard is already handled in TextInsertionManager
            }

            // Complete performance monitoring session
            PerformanceMonitor.shared.completeSession()
            self.clearCurrentProcessingState()
        }

        // Record analytics
        self.analyticsManager.recordTranscription(
            duration: recordingDuration,
            wordCount: wordCount,
            transcriptionTime: processingMetadata.totalLatency ?? recordingDuration
        )

        // Record statistics
        self.recordTranscription(text: processedText)

        // Reset state
        self.appState.recordingState = .idle
        self.appState.recordingStatusDetail = nil

        // Update status bar
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .idle)
        }

        // Show success notification
        self.notificationManager.showTranscriptionSuccess(
            text: processedText,
            wordCount: wordCount,
            duration: recordingDuration
        )
    }

    // MARK: - Error Handling

    func handleTranscriptionError(_ errorMessage: String) {
        // Record error in analytics
        self.analyticsManager.recordError(type: "Transcription", context: errorMessage)

        self.appState.recordingState = .error(errorMessage)
        self.appState.recordingStatusDetail = nil
        clearCurrentProcessingState()

        // Reset state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.appState.recordingState = .idle
        }

        // Update status bar
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .idle)
        }

        // Show error notification
        self.notificationManager.showTranscriptionError(error: errorMessage)
    }

    // MARK: - Whisper Deduplication

    /// Detect and remove repeated text blocks from Whisper output.
    /// Whisper sometimes echoes the entire transcription, producing "Hello world Hello world".
    /// This checks if the text is approximately a repeated copy of itself and returns just one copy.
    func deduplicateWhisperOutput(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return text } // Too short to be a real duplicate

        // Try splitting at the midpoint and checking if both halves are similar
        let words = trimmed.split(separator: " ")
        guard words.count >= 6 else { return text } // Need enough words to detect duplication

        // Check for exact half duplication
        let halfCount = words.count / 2
        let firstHalf = words[0..<halfCount].joined(separator: " ").lowercased()
        let secondHalf = words[halfCount..<min(halfCount * 2, words.count)].joined(separator: " ").lowercased()

        // Calculate similarity (Jaccard-like: shared words / total unique words)
        let firstWords = Set(firstHalf.split(separator: " "))
        let secondWords = Set(secondHalf.split(separator: " "))
        let intersection = firstWords.intersection(secondWords)
        let union = firstWords.union(secondWords)

        guard !union.isEmpty else { return text }
        let similarity = Double(intersection.count) / Double(union.count)

        if similarity > 0.75 {
            // High similarity — take the first half (usually cleaner)
            let result = words[0..<halfCount].joined(separator: " ")
            debugLog("🔄 Whisper dedup: detected ~\(Int(similarity * 100))% duplicate, keeping first half (\(halfCount) words)")
            return result
        }

        return text
    }

    // MARK: - Hallucination Detection

    func isLikelyHallucination(_ text: String, recordingDuration: TimeInterval) -> Bool {
        // Trim whitespace
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check 1: Empty or very short text
        if trimmed.count < 3 {
            return true
        }

        // Check 2: Recording was too short (less than 0.3 seconds)
        // Likely just noise or accidental trigger
        if recordingDuration < 0.3 {
            return true
        }

        // Check 3: Punctuation-only or ellipsis
        let punctuationOnly = ["...", ".", ". ."]
        if punctuationOnly.contains(trimmed) {
            return true
        }

        // Check 4: For very short recordings (< 1.5s), filter common Whisper hallucination phrases
        // These appear when Whisper processes near-silence. Longer recordings with the same
        // words are legitimate dictation (e.g., someone actually saying "thank you").
        if recordingDuration < 1.5 {
            let shortRecordingHallucinations = [
                "thank you", "thanks", "thank you.", "thanks.",
                "bye", "bye.", "goodbye", "goodbye.",
                "you", "thank",
                "thanks for watching", "thanks for watching.",
                "see you next time", "see you next time."
            ]
            if shortRecordingHallucinations.contains(trimmed) {
                return true
            }
        }

        // Check 5: Very short recordings with generic single words
        if recordingDuration < 1.0 && trimmed.split(separator: " ").count == 1 {
            let shortWords = ["the", "a", "an", "i", "you", "ok", "okay", "um", "uh", "ah"]
            if shortWords.contains(trimmed) {
                return true
            }
        }

        // Looks legitimate
        return false
    }

    // MARK: - Text Processing

    func processTranscription(_ text: String) -> String {
        var processed = text

        // Apply dictionary transformations (word replacements + correct spellings)
        processed = DictionaryManager.shared.process(text: processed)

        // Apply settings (capitalization is handled in TranscriptionEngine.processText)
        if settings.insertSpaceAfterText {
            processed += " "
        }

        return processed
    }

    // MARK: - Statistics

    func recordTranscription(text: String) {
        let wordCount = text.split(separator: " ").count
        appState.incrementTranscriptionCount(wordCount: wordCount)
        debugLog("📊 Recorded transcription: \(wordCount) words")
    }

    // MARK: - UI Helpers

    func showErrorAlert(message: String) {
        errorLogger.logError(
            NSError(domain: "com.echotune.app", code: -1, userInfo: [NSLocalizedDescriptionKey: message]),
            category: "Recording",
            context: [:]
        )

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Recording Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
