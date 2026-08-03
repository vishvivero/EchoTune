# Graph Report - .  (2026-07-27)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1939 nodes · 4376 edges · 95 communities (83 shown, 12 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 456 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b292da5b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95

## God Nodes (most connected - your core abstractions)
1. `debugLog()` - 264 edges
2. `MeetingManager` - 60 edges
3. `AppSettings` - 60 edges
4. `AIModel` - 53 edges
5. `ModelManager` - 38 edges
6. `AudioManager` - 34 edges
7. `MultiHotkeyManager` - 31 edges
8. `LicenseManager` - 30 edges
9. `PowerModeManager` - 30 edges
10. `TranscriptionEngine` - 30 edges

## Surprising Connections (you probably didn't know these)
- `XCUIElement` --references--> `String`  [EXTRACTED]
  EchoTuneUITests/OnboardingPhase1UITests.swift → EchoTune/Managers/AnalyticsManager.swift
- `.displaySession` --references--> `MeetingManager`  [INFERRED]
  EchoTune/Views/Meeting/MeetingView.swift → EchoTune/Managers/MeetingManager.swift
- `.config` --calls--> `debugLog()`  [INFERRED]
  EchoTune/Managers/VADManager.swift → EchoTune/Utilities/DebugLog.swift
- `.wordCount` --references--> `TranscriptionHistoryItem`  [INFERRED]
  EchoTune/Views/Dashboard/HomeContentView.swift → EchoTune/Views/History/TranscriptionHistoryItem.swift
- `.body` --calls--> `OnboardingView`  [INFERRED]
  EchoTune/EchoTuneApp.swift → EchoTune/Views/Onboarding/OnboardingView.swift

## Import Cycles
- None detected.

## Communities (95 total, 12 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (42): DateFormatter, AnalyticsManager, DailyStats, Date, Double, Int, TimeInterval, UsageStatistics (+34 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (36): ModelManager, Bool, URL, ModelManager, Bool, Double, Int64, Result (+28 more)

### Community 2 - "Community 2"
Cohesion: 0.06
Nodes (26): CGEventTapProxy, AppCoordinator, .useWhisper, Bool, Date, Void, PermissionsManager, SettingsPane (+18 more)

### Community 3 - "Community 3"
Cohesion: 0.07
Nodes (35): Character, HotkeyAction, .defaultShortcut, .id, pasteLastEnhanced, pasteLastTranscript, showMainWindow, togglePowerModes (+27 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (31): AppCoordinator, RetranscriptionResult, Void, Int, TimeInterval, TranscriptionProcessingMetadata, .hasEnhancement, AudioCleanupManager (+23 more)

### Community 5 - "Community 5"
Cohesion: 0.06
Nodes (35): CodingKey, CodingKeys, customer, expiresAt, status, CustomerKeys, email, LicenseManager (+27 more)

### Community 6 - "Community 6"
Cohesion: 0.08
Nodes (23): DictionaryExport, DictionaryManager, DictionaryStatistics, Date, Int, URL, CodingKeys, caseSensitive (+15 more)

### Community 7 - "Community 7"
Cohesion: 0.06
Nodes (37): DispatchQueue, AVAudioFormat, AVAudioPCMBuffer, Double, Float, WhisperEngine, .whisperFormat, AVAudioPCMBuffer (+29 more)

### Community 8 - "Community 8"
Cohesion: 0.06
Nodes (31): AnyObject, Context, AppState, .isTrialExpired, .trialDaysRemaining, RecordingState, .color, .description (+23 more)

### Community 9 - "Community 9"
Cohesion: 0.08
Nodes (27): AIEnhancementEngine, EnhancementError, apiError, .errorDescription, invalidResponse, networkError, noAPIKey, EnhancementModel (+19 more)

### Community 10 - "Community 10"
Cohesion: 0.10
Nodes (23): AVAudioPlayer, AVAudioPlayerDelegate, AudioPlayerManager, AnyCancellable, Bool, Float, Int, Never (+15 more)

### Community 11 - "Community 11"
Cohesion: 0.10
Nodes (30): AIModelsSettingsView, .body, APIKeyField, .body, AboutLicenseSettingsView, .body, GeneralSettingsView, .body (+22 more)

### Community 12 - "Community 12"
Cohesion: 0.10
Nodes (22): Decodable, ReferralEntry, .createdDate, .id, .maskedEmail, .statusEmoji, ReferralManager, .betaCheckoutWithReferral (+14 more)

### Community 13 - "Community 13"
Cohesion: 0.12
Nodes (15): AppcastParser, Bool, Date, Error, Int64, TimeInterval, UpdateInfo, UpdateManager (+7 more)

### Community 14 - "Community 14"
Cohesion: 0.06
Nodes (32): AppSettings, .aiEnhancementEnabled, .audioRetentionDays, .autoCorrection, .autoDetectLanguage, .autoPunctuation, .autoSendEnabled, .customEnhancementPrompt (+24 more)

### Community 15 - "Community 15"
Cohesion: 0.11
Nodes (14): ErrorLogger, LogEntry, LogLevel, critical, debug, .emoji, error, info (+6 more)

### Community 16 - "Community 16"
Cohesion: 0.07
Nodes (30): StoreError, .errorDescription, failedVerification, SystemAudioCaptureError, captureStartFailed, .errorDescription, noDisplayFound, permissionDenied (+22 more)

### Community 17 - "Community 17"
Cohesion: 0.12
Nodes (11): Accelerate, AVFAudio, AVFoundation, CoreAudio, CoreML, ModelManager, Foundation, os.log (+3 more)

### Community 18 - "Community 18"
Cohesion: 0.11
Nodes (20): AVAudioInputNode, AudioDevice, AudioManager, .tempFileURL, .totalBufferedDuration, .totalFramesWritten, AVAudioConverter, AVAudioEngine (+12 more)

### Community 19 - "Community 19"
Cohesion: 0.10
Nodes (25): .body, DetailView, MainDashboardView, .body, ModelLoadingToast, .body, ModernSidebarItem, .body (+17 more)

### Community 20 - "Community 20"
Cohesion: 0.16
Nodes (11): AudioCaptureSource, mic, system, MeetingManager, AVAudioPCMBuffer, Date, Float, Int (+3 more)

### Community 21 - "Community 21"
Cohesion: 0.13
Nodes (19): AnalysisResult, .summary, DetectionMethod, energyBased, sileroVAD, Sensitivity, high, low (+11 more)

### Community 22 - "Community 22"
Cohesion: 0.11
Nodes (11): PerformanceMonitor, .isEnabled, Bool, Date, Double, Int, T, TimeInterval (+3 more)

### Community 23 - "Community 23"
Cohesion: 0.11
Nodes (18): PerformanceTier, .description, high, low, medium, .recommendedModelID, veryLow, Bool (+10 more)

### Community 24 - "Community 24"
Cohesion: 0.11
Nodes (18): MiniRecorderContentView, .barGradient, .body, .isProcessing, .isRecording, MiniRecorderWindow, AnyView, Bool (+10 more)

### Community 25 - "Community 25"
Cohesion: 0.12
Nodes (20): .isSilentCallStyleMeeting, UUID, MeetingSession, .duration, .formattedDuration, MeetingTemplate, brainstorm, custom (+12 more)

### Community 26 - "Community 26"
Cohesion: 0.11
Nodes (22): .body, ActiveMeetingSidebar, .body, EmptyMeetingDetailView, .body, LiveMeetingTranscriptionPanel, .body, MeetingDetailPanel (+14 more)

### Community 27 - "Community 27"
Cohesion: 0.14
Nodes (14): Config, SileroVADEngine, SileroVADInput, .featureNames, AVAudioPCMBuffer, Bool, Double, Float (+6 more)

### Community 28 - "Community 28"
Cohesion: 0.10
Nodes (10): EchoTuneUITests, EchoTuneUITestsLaunchTests, .runsForEachTargetApplicationUIConfiguration, Bool, OnboardingPhase1UITests, Int, XCUIElement, .textValue (+2 more)

### Community 29 - "Community 29"
Cohesion: 0.14
Nodes (6): AppCoordinator, AIEnhancementEngine, Bool, Int, TimeInterval, UUID

### Community 30 - "Community 30"
Cohesion: 0.15
Nodes (6): NotificationManager, Bool, Int, TimeInterval, debugLog(), Any

### Community 31 - "Community 31"
Cohesion: 0.13
Nodes (14): DailyUsage, Date, Double, Int, TimeInterval, TranscriptionStats, .efficiencyMultiplier, GradientOption (+6 more)

### Community 32 - "Community 32"
Cohesion: 0.17
Nodes (4): DispatchWorkItem, PowerModeManager, Bool, NSObjectProtocol

### Community 33 - "Community 33"
Cohesion: 0.15
Nodes (7): Bool, CGEventFlags, CGKeyCode, Error, Result, Void, TextInsertionManager

### Community 34 - "Community 34"
Cohesion: 0.13
Nodes (12): AVAudioConverter, AVAudioFormat, AVAudioFrameCount, Bool, Double, Void, TranscriptionEngine, .authorizationStatus (+4 more)

### Community 35 - "Community 35"
Cohesion: 0.13
Nodes (16): Content, .body, LiveWaveformView, .body, OnboardingCardView, .body, StepIndicatorView, .body (+8 more)

### Community 36 - "Community 36"
Cohesion: 0.14
Nodes (8): AppDelegate, Bool, Notification, NSApplication, NSApplicationDelegate, NSWindow, NSWindowDelegate, UNUserNotificationCenterDelegate

### Community 37 - "Community 37"
Cohesion: 0.13
Nodes (16): DeepgramError, apiError, decodingError, .errorDescription, invalidAudioData, networkError, noAPIKey, DeepgramModel (+8 more)

### Community 38 - "Community 38"
Cohesion: 0.17
Nodes (13): AudioStreamOutput, CMSampleBuffer, AVAudioConverter, AVAudioFormat, AVAudioPCMBuffer, Double, Float, Int (+5 more)

### Community 39 - "Community 39"
Cohesion: 0.15
Nodes (10): main(), PerformanceAnalyzer, Analyze VAD impact on performance, Check if performance targets are met, Load benchmark results from CSV, Generate comprehensive markdown report, Run complete analysis, Calculate statistics for a list of values (+2 more)

### Community 40 - "Community 40"
Cohesion: 0.13
Nodes (10): AnyHashable, MeetingAutoDetectionCoordinator, Any, Date, NSObjectProtocol, TimeInterval, Timer, MeetingDetectionContext (+2 more)

### Community 41 - "Community 41"
Cohesion: 0.21
Nodes (9): Data, GroqTranscriptionService, Provider, .displayName, .endpoint, groq, .model, xai (+1 more)

### Community 42 - "Community 42"
Cohesion: 0.33
Nodes (8): MeetingSummaryEngine, MeetingSummaryResult, httpError, AIEnhancementEngine, Bool, Error, Result, Void

### Community 43 - "Community 43"
Cohesion: 0.18
Nodes (6): NotesManager, .favoriteNotes, notes, NotesContentView, .body, .filteredNotes

### Community 44 - "Community 44"
Cohesion: 0.12
Nodes (10): .body, Void, TrialCTAStep, .body, Void, WelcomeStep, AIAutomationSettingsView, .body (+2 more)

### Community 45 - "Community 45"
Cohesion: 0.33
Nodes (3): AVAudioEngine, Bool, Bool

### Community 46 - "Community 46"
Cohesion: 0.21
Nodes (10): StoreKitManager, .isProUnlocked, .proProduct, Bool, Error, Product, T, Task (+2 more)

### Community 47 - "Community 47"
Cohesion: 0.26
Nodes (13): Codable, DeepgramAlternative, DeepgramChannel, DeepgramErrorResponse, DeepgramMetadata, DeepgramResponse, DeepgramResults, DeepgramWord (+5 more)

### Community 48 - "Community 48"
Cohesion: 0.22
Nodes (11): Result, Void, TranscriptionEngine, Result, TranscriptionError, audioFormatError, noAudioData, permissionDenied (+3 more)

### Community 49 - "Community 49"
Cohesion: 0.16
Nodes (7): Keys, OnboardingStateStore, Bool, Int, OnboardingView, Void, UserDefaults

### Community 50 - "Community 50"
Cohesion: 0.22
Nodes (7): Int, UUID, PowerMode, Bool, Date, Int, UUID

### Community 51 - "Community 51"
Cohesion: 0.26
Nodes (3): String, SystemInfo, AIEnhancementEngine

### Community 52 - "Community 52"
Cohesion: 0.14
Nodes (14): GroqError, apiError, decodingError, emptyTranscription, .errorDescription, invalidAudioData, networkError, noAPIKey (+6 more)

### Community 53 - "Community 53"
Cohesion: 0.24
Nodes (5): AppKit, ApplicationServices, CoreGraphics, Security, UserNotifications

### Community 54 - "Community 54"
Cohesion: 0.17
Nodes (12): CaseIterable, RecorderStyle, .description, .id, mini, slim, .userFacingOptions, RecordingMode (+4 more)

### Community 56 - "Community 56"
Cohesion: 0.27
Nodes (5): AutoSendService, Bool, CGEventFlags, CGKeyCode, TimeInterval

### Community 58 - "Community 58"
Cohesion: 0.31
Nodes (10): Note, NoteItem, NoteItemType, bullet, checkbox, numbered, Bool, Date (+2 more)

### Community 59 - "Community 59"
Cohesion: 0.17
Nodes (12): FeatureRow, .body, PurchaseView, .body, .featuresSection, .headerSection, .heroSection, .primaryCTA (+4 more)

### Community 60 - "Community 60"
Cohesion: 0.23
Nodes (6): AVAudioFormat, AVAudioPCMBuffer, Result, Void, TranscriptionEngine, SFSpeechAudioBufferRecognitionRequest

### Community 61 - "Community 61"
Cohesion: 0.21
Nodes (10): FaqItem, FaqRow, .body, HelpFeedbackView, .body, ResourceCard, .body, Bool (+2 more)

### Community 62 - "Community 62"
Cohesion: 0.25
Nodes (6): LaunchAtLoginManager, .isEnabled, Bool, Error, Result, Void

### Community 63 - "Community 63"
Cohesion: 0.29
Nodes (6): SpeechProbability, .confidence, AVAudioFrameCount, AVAudioPCMBuffer, Date, UnsafePointer

### Community 64 - "Community 64"
Cohesion: 0.25
Nodes (7): SetupStep, .body, .isModelActiveAndReady, .leanModel, .recommendedModel, Bool, Void

### Community 65 - "Community 65"
Cohesion: 0.18
Nodes (11): SettingsTab, aiModels, automation, general, hotkeys, .iconName, .id, license (+3 more)

### Community 66 - "Community 66"
Cohesion: 0.24
Nodes (6): AVAudioFile, AudioEngine, appleSpeech, cloud, whisper, AudioManager

### Community 68 - "Community 68"
Cohesion: 0.36
Nodes (3): Int, SystemAudioManager, NSAppleEventDescriptor

### Community 69 - "Community 69"
Cohesion: 0.22
Nodes (5): App, EchoTuneApp, URL, Scene, Sentry

### Community 70 - "Community 70"
Cohesion: 0.17
Nodes (5): Carbon, Cocoa, Combine, ServiceManagement, Sparkle

### Community 72 - "Community 72"
Cohesion: 0.36
Nodes (7): AudioChunker, ChunkConfig, ChunkResult, AVAudioPCMBuffer, Double, Int, TimeInterval

### Community 73 - "Community 73"
Cohesion: 0.25
Nodes (6): RecordingIndicatorContentView, .body, .statusText, RecordingIndicatorWindow, NSHostingView, NSPanel

### Community 74 - "Community 74"
Cohesion: 0.25
Nodes (6): ActiveBrowserInspector, Bool, TabQuery, chromium, unsupported, webKit

### Community 75 - "Community 75"
Cohesion: 0.29
Nodes (6): LicenseSettingsView, .body, LicenseSubscriptionButton, .body, AppCoordinator, Bool

### Community 76 - "Community 76"
Cohesion: 0.38
Nodes (4): FinalizedTranscription, Result, TranscriptionEngine, WhisperEngine

### Community 77 - "Community 77"
Cohesion: 0.29
Nodes (7): SummaryError, emptyTranscript, .errorDescription, invalidURL, noResponse, parseError, Int

### Community 78 - "Community 78"
Cohesion: 0.33
Nodes (5): FlowLayout, .body, AnyView, UniformTypeIdentifiers, V

### Community 79 - "Community 79"
Cohesion: 0.43
Nodes (3): LiveDemoStep, AnyCancellable, Void

### Community 80 - "Community 80"
Cohesion: 0.33
Nodes (6): TranscriptionQualityFeedback, better, .iconName, .id, same, worse

### Community 81 - "Community 81"
Cohesion: 0.40
Nodes (3): EchoTune, EchoTuneTests, Testing

### Community 83 - "Community 83"
Cohesion: 0.50
Nodes (4): Int, VADManager.Sensitivity, .rawValue, RawRepresentable

### Community 84 - "Community 84"
Cohesion: 0.40
Nodes (4): .deepgramAPIKey, .geminiAPIKey, .groqAPIKey, .openaiAPIKey

### Community 85 - "Community 85"
Cohesion: 0.40
Nodes (4): Bundle, .appBuildString, .appVersionString, .appVersionWithBuild

### Community 86 - "Community 86"
Cohesion: 0.40
Nodes (4): UNNotification, UNNotificationPresentationOptions, UNNotificationResponse, UNUserNotificationCenter

## Knowledge Gaps
- **361 isolated node(s):** `AVFAudio`, `better`, `same`, `worse`, `.id` (+356 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `Community 51` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 18`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 26`, `Community 27`, `Community 28`, `Community 29`, `Community 30`, `Community 31`, `Community 32`, `Community 33`, `Community 34`, `Community 35`, `Community 37`, `Community 40`, `Community 41`, `Community 42`, `Community 43`, `Community 45`, `Community 47`, `Community 48`, `Community 50`, `Community 52`, `Community 54`, `Community 55`, `Community 56`, `Community 58`, `Community 59`, `Community 60`, `Community 61`, `Community 62`, `Community 64`, `Community 65`, `Community 67`, `Community 68`, `Community 71`, `Community 73`, `Community 74`, `Community 75`, `Community 76`, `Community 77`, `Community 78`, `Community 80`, `Community 84`, `Community 85`, `Community 87`, `Community 89`?**
  _High betweenness centrality (0.557) - this node is a cross-community bridge._
- **Why does `debugLog()` connect `Community 30` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 12`, `Community 13`, `Community 15`, `Community 17`, `Community 18`, `Community 20`, `Community 21`, `Community 22`, `Community 25`, `Community 27`, `Community 29`, `Community 32`, `Community 33`, `Community 36`, `Community 37`, `Community 38`, `Community 40`, `Community 41`, `Community 42`, `Community 45`, `Community 46`, `Community 48`, `Community 50`, `Community 51`, `Community 55`, `Community 56`, `Community 57`, `Community 60`, `Community 62`, `Community 63`, `Community 64`, `Community 66`, `Community 68`, `Community 69`, `Community 71`, `Community 72`, `Community 76`, `Community 79`, `Community 82`, `Community 87`, `Community 88`, `Community 91`?**
  _High betweenness centrality (0.263) - this node is a cross-community bridge._
- **Why does `AppSettings` connect `Community 14` to `Community 67`, `Community 37`, `Community 7`, `Community 8`, `Community 11`, `Community 44`, `Community 13`, `Community 51`, `Community 84`, `Community 19`, `Community 54`, `Community 89`, `Community 25`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Are the 261 inferred relationships involving `debugLog()` (e.g. with `.applicationDidFinishLaunching()` and `.applicationWillTerminate()`) actually correct?**
  _`debugLog()` has 261 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `MeetingManager` (e.g. with `SystemAudioCapture` and `.displaySession`) actually correct?**
  _`MeetingManager` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AVFAudio`, `better`, `same` to the rest of the system?**
  _361 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05063291139240506 - nodes in this community are weakly interconnected._