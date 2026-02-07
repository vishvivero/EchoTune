# VoiceInk vs EchoTune — Deep Competitive Analysis

> Generated: 2026-02-07 | Based on source code analysis of both codebases

---

## 1. Executive Summary

### What VoiceInk Does Better

1. **Transcription Engine Breadth** — VoiceInk supports **9 cloud providers** (Groq, Deepgram, ElevenLabs, Mistral, Gemini, Soniox, OpenAI-compatible, custom endpoints) plus 3 local engines (whisper.cpp, Parakeet/NVIDIA, Native Apple Speech on macOS 26). EchoTune supports Groq, Deepgram, Apple Speech, and local Whisper — roughly half the coverage.

2. **Mini Recorder / Notch Recorder** — VoiceInk's signature UX. A floating capsule or MacBook-notch-integrated recorder that pops up on hotkey press with prompt/power-mode selectors, audio visualiser, and in-context AI enhancement toggle. EchoTune has a simpler `RecordingIndicatorWindow` with no inline controls.

3. **Keyboard Shortcuts — Depth** — VoiceInk uses `sindresorhus/KeyboardShortcuts` with support for: two configurable hotkeys (modifier or custom combo), middle-click toggle with configurable delay, hands-free mode (brief press = toggle, long press = push-to-talk), per-prompt shortcuts (⌘1-⌘0), per-power-mode shortcuts (⌥1-⌥0), Escape double-tap cancel, dedicated shortcuts for paste-last-transcription / paste-last-enhancement / retry-last / open-history. EchoTune uses raw `CGEvent.tapCreate` with single-shortcut support.

4. **Power Mode Configuration** — VoiceInk's Power Mode is richer: per-mode transcription model, AI provider, AI model, AI prompt, language, auto-send, screen capture, URL-based matching, app-based matching, default fallback, dedicated per-mode hotkeys, emoji identifiers. EchoTune has the same concepts but less granular configuration.

5. **Selected Text Context** — VoiceInk captures the currently-selected text in the active application (via `SelectedTextKit` library + accessibility API) and injects it into the AI enhancement system prompt. This makes "edit my selection" use cases seamless. EchoTune doesn't have this.

6. **Screen Capture (OCR)** — VoiceInk uses `ScreenCaptureKit` (SCScreenshotManager) which captures only the active window at 2× resolution with VNRecognizeTextRequest at `.accurate` level. EchoTune uses `CGDisplayCreateImage` which captures the entire display at `.fast` recognition — lower quality and less targeted.

7. **Clipboard Context** — VoiceInk can optionally inject the clipboard content into AI enhancement context. EchoTune doesn't use clipboard context.

8. **Trigger Words** — VoiceInk's `PromptDetectionService` lets users define trigger words per AI prompt. Say "Hey Siri-style" trigger words at the start/end of your dictation and the system auto-selects the correct prompt and strips the trigger word. Very clever.

9. **Audio File Transcription** — VoiceInk can transcribe dropped audio/video files (supports many formats via `SupportedMedia`). EchoTune is live-recording only.

10. **Filler Word Removal** — Configurable filler word list with regex-based removal at the transcription output level. EchoTune relies on AI enhancement to remove fillers — no dedicated system.

11. **Transcription History (SwiftData)** — VoiceInk uses SwiftData with proper `ModelContainer` (persistent + in-memory fallback), stores `Transcription`, `VocabularyWord`, `WordReplacement` as SwiftData models with CloudKit sync for dictionary data. EchoTune uses UserDefaults for everything.

12. **Code Quality** — VoiceInk has 184 Swift files with well-separated services (TranscriptionServiceRegistry pattern, dedicated service per cloud provider). EchoTune has 80 files with a monolithic AppCoordinator (~600 lines) handling most logic.

13. **Siri Shortcuts / App Intents** — VoiceInk registers `AppShortcut` intents for Siri ("Toggle VoiceInk recorder", "Dismiss recorder"). EchoTune has none.

14. **iCloud Dictionary Sync** — VoiceInk syncs custom vocabulary and word replacements across devices via CloudKit. EchoTune's dictionary is device-local (UserDefaults).

15. **License Validation** — VoiceInk uses Polar (polar.sh) for real license validation with server-side activation, activation limits, device fingerprinting. EchoTune has a placeholder server validation that accepts any 23-char formatted key.

### What EchoTune Does Better

1. **App Store IAP Support** — EchoTune has dual-track licensing: Keychain-stored license keys for direct sales AND StoreKit in-app purchase for App Store builds (`#if APPSTORE`). VoiceInk appears to be direct-sale only (Polar).

2. **VAD (Voice Activity Detection)** — EchoTune has a dedicated `SileroVADEngine` with configurable speech/silence thresholds and analysis summaries. VoiceInk references a `VADModelManager` but it's less prominently integrated.

3. **Auto-Send Service** — EchoTune's `AutoSendService` can automatically press Enter/Return after pasting text in supported apps. VoiceInk also has auto-send in Power Mode, but EchoTune's is cleaner as a standalone service.

4. **Social Sharing** — EchoTune has `ShareStatsView` and `SocialShareService` for sharing transcription statistics. VoiceInk doesn't have this.

5. **Referral System** — EchoTune has a `ReferralView`. VoiceInk doesn't appear to have one.

6. **Performance Benchmarking** — EchoTune has `PerformanceBenchmark` and `PerformanceMonitor` with detailed timing for each phase (recording, transcription, text insertion). VoiceInk has metrics but they're less structured.

7. **Notes Feature** — EchoTune has a dedicated `NotesManager` and `NotesView` for saving transcriptions as notes. VoiceInk stores transcription history but doesn't have a separate notes feature.

---

## 2. Feature-by-Feature Comparison

| Feature | VoiceInk | EchoTune | Gap |
|---------|----------|----------|-----|
| **Local Whisper** | ✅ whisper.cpp (C bindings) | ✅ WhisperKit (Swift) | Parity |
| **Local Parakeet (NVIDIA)** | ✅ FluidAudio framework | ❌ | **Major gap** |
| **Native Apple Speech (macOS 26)** | ✅ SpeechAnalyzer API | ✅ SFSpeechRecognizer | Parity-ish |
| **Cloud: Groq** | ✅ | ✅ | Parity |
| **Cloud: Deepgram** | ✅ | ✅ | Parity |
| **Cloud: ElevenLabs** | ✅ (Scribe v1) | ❌ | Gap |
| **Cloud: Gemini** | ✅ (multimodal audio) | ❌ | Gap |
| **Cloud: Mistral** | ✅ | ❌ | Gap |
| **Cloud: Soniox** | ✅ (async w/ vocabulary) | ❌ | Gap |
| **Cloud: OpenAI-compatible** | ✅ (custom endpoint) | ❌ | Gap |
| **AI Enhancement** | ✅ (12+ providers incl. Cerebras, Groq, Gemini, Anthropic, OpenAI, Mistral, OpenRouter, Ollama, custom) | ✅ (OpenAI, Anthropic only) | **Major gap** |
| **AI Prompt System** | ✅ Custom prompts w/ trigger words, predefined templates, ⌘1-⌘0 shortcuts | ✅ Single custom prompt | **Major gap** |
| **Reasoning Config** | ✅ (auto reasoning_effort for supported models) | ❌ | Gap |
| **Mini Recorder UI** | ✅ Floating capsule w/ prompt/mode selectors | ❌ | **Major gap** |
| **Notch Recorder UI** | ✅ Integrates with MacBook notch | ❌ | **Major gap** |
| **Keyboard Shortcuts** | ✅ 2 configurable + middle-click + per-prompt + per-mode + history + paste shortcuts | ✅ Single configurable shortcut | **Major gap** |
| **Hands-free Mode** | ✅ Brief press = toggle, long press = push-to-talk | ❌ | Gap |
| **Power Mode** | ✅ Per-app, per-URL, per-mode AI/model/language/prompt + defaults | ✅ Per-app, basic config | Gap |
| **Screen Context (OCR)** | ✅ ScreenCaptureKit, active window only, .accurate | ✅ CGDisplayCreateImage, full screen, .fast | Quality gap |
| **Selected Text Context** | ✅ SelectedTextKit library | ❌ | Gap |
| **Clipboard Context** | ✅ | ❌ | Gap |
| **Trigger Words** | ✅ Auto-detect & strip per-prompt | ❌ | Gap |
| **Dictionary: Vocabulary** | ✅ SwiftData + iCloud sync | ✅ UserDefaults, correct spellings + variations | Quality gap |
| **Dictionary: Replacements** | ✅ SwiftData, comma-separated variants, CJK-aware | ✅ UserDefaults, word boundary only | Quality gap |
| **Dictionary → Transcription** | ✅ Soniox sends vocab as API context | ❌ (dictionary only for post-processing) | Gap |
| **Filler Word Removal** | ✅ Configurable list, regex removal | ❌ (AI-dependent) | Gap |
| **Hallucination Filter** | ✅ TranscriptionOutputFilter (brackets, tags, fillers) | ✅ isLikelyHallucination (text patterns) | Parity |
| **Audio File Transcription** | ✅ Drag-and-drop, multi-format | ❌ | Gap |
| **Transcription History** | ✅ SwiftData, searchable, playback | ✅ Basic history manager | Quality gap |
| **History Window** | ✅ Dedicated floating window w/ shortcut | ❌ | Gap |
| **Paste Last Transcription** | ✅ Keyboard shortcut | ❌ | Gap |
| **Retry Last Transcription** | ✅ Re-transcribe from saved audio | ❌ | Gap |
| **Auto-Send (Enter)** | ✅ In Power Mode | ✅ Standalone service | Parity |
| **Audio Device Management** | ✅ CoreAudio, live device switching, multi-device | ✅ Basic AVAudioEngine | Quality gap |
| **Media Pause/Resume** | ✅ MediaRemote + custom PlaybackController | ❌ (mute system only) | Gap |
| **Custom Sounds** | ✅ CustomSoundManager (start/stop/cancel) | ✅ SoundManager | Parity |
| **Onboarding** | ✅ 4-step: Welcome → Permissions → Model Download → Tutorial | ✅ Basic onboarding | Quality gap |
| **Siri/App Intents** | ✅ Toggle/Dismiss recorder | ❌ | Gap |
| **Sparkle Updates** | ✅ SPUStandardUpdaterController | ✅ UpdateManager | Parity |
| **Licensing** | ✅ Polar.sh with server validation | ✅ Keychain + StoreKit IAP | Different approaches |
| **iCloud Sync** | ✅ Dictionary data | ❌ | Gap |
| **CSV Export** | ✅ VoiceInkCSVExportService | ❌ | Gap |
| **Diagnostics/Logging** | ✅ LogExporter, os.Logger throughout | ✅ ErrorLogger with categories | Parity |
| **Announcements** | ✅ AnnouncementsService (in-app news) | ❌ | Minor gap |
| **Auto Audio Cleanup** | ✅ Configurable retention + auto-delete | ❌ | Gap |
| **Transcription Auto-Cleanup** | ✅ Zero data retention mode | ❌ | Gap |
| **Notes** | ❌ | ✅ NotesManager | EchoTune advantage |
| **Social Share** | ❌ | ✅ ShareStatsView | EchoTune advantage |
| **Referral System** | ❌ | ✅ ReferralView | EchoTune advantage |
| **VAD** | ⚠️ VADModelManager (less prominent) | ✅ SileroVADEngine | EchoTune advantage |
| **Performance Benchmark** | ⚠️ Metrics views | ✅ PerformanceBenchmark + PerformanceMonitor | EchoTune advantage |
| **App Store IAP** | ❌ | ✅ StoreKitManager | EchoTune advantage |

---

## 3. Architecture Differences

### VoiceInk Architecture

```
VoiceInkApp (@main)
├── SwiftData ModelContainer (persistent + in-memory fallback)
│   ├── Transcription.self
│   ├── VocabularyWord.self
│   └── WordReplacement.self (CloudKit synced)
├── WhisperState (central state manager, @StateObject)
│   ├── TranscriptionServiceRegistry → dispatches to:
│   │   ├── LocalTranscriptionService (whisper.cpp)
│   │   ├── CloudTranscriptionService → 8 sub-services
│   │   ├── ParakeetTranscriptionService (NVIDIA)
│   │   └── NativeAppleTranscriptionService
│   ├── Recorder (CoreAudio-based)
│   └── AIEnhancementService
├── HotkeyManager → MiniRecorderShortcutManager + PowerModeShortcutManager
├── MenuBarManager
├── AIService (provider abstraction)
└── ActiveWindowService → BrowserURLService → PowerModeManager
```

**Key patterns:**
- **SwiftData** for all persistent data with CloudKit sync
- **@StateObject** dependency injection via environment objects
- **Service Registry** pattern for transcription (strategy pattern)
- **Dedicated managers** per concern (each in its own file)
- **CoreAudio** directly (not AVAudioEngine) for low-latency recording
- **os.Logger** throughout for structured logging
- **sindresorhus/KeyboardShortcuts** for hotkey management
- **Sparkle** for auto-updates
- **Keychain** for secrets (API keys, license data)

### EchoTune Architecture

```
EchoTuneApp (@main)
├── AppCoordinator (singleton, central coordinator, ~600 lines)
│   ├── AudioManager (AVAudioEngine-based)
│   ├── TranscriptionEngine (Apple Speech)
│   ├── WhisperEngine (local Whisper)
│   ├── ModelManager
│   ├── TextInsertionManager
│   ├── PermissionsManager
│   ├── ShortcutManager (CGEvent tap)
│   ├── MultiHotkeyManager
│   ├── GroqTranscriptionService
│   ├── DeepgramTranscriptionService
│   └── AIEnhancementEngine
├── AppSettings (UserDefaults wrapper)
├── AppState (recording state, stats)
└── Various Managers (all singletons via .shared)
```

**Key patterns:**
- **Singleton coordinator** — AppCoordinator owns nearly everything
- **UserDefaults** for all persistence (dictionary, settings, stats)
- **AVAudioEngine** for recording
- **CGEvent tap** for keyboard shortcuts (raw Carbon API)
- **Lazy initialization** to defer permission prompts
- **#if APPSTORE** compilation flags for App Store vs direct sale

### Critical Architecture Differences

| Aspect | VoiceInk | EchoTune |
|--------|----------|----------|
| State management | @StateObject + EnvironmentObject | Singleton .shared pattern |
| Data persistence | SwiftData + CloudKit | UserDefaults |
| Audio recording | CoreAudio (low-level) | AVAudioEngine |
| Hotkey library | KeyboardShortcuts (maintained OSS) | Raw CGEvent tap |
| Transcription dispatch | TranscriptionServiceRegistry | if/else in AppCoordinator |
| Secret storage | KeychainService | Keychain (for license) + plain settings |
| Logging | os.Logger with categories | print() + ErrorLogger |

---

## 4. Priority Features to Build (Impact vs Effort)

### 🔴 Critical Priority (High Impact, Worth the Effort)

#### 1. Mini Recorder UI
- **Impact:** 🔥🔥🔥🔥🔥 — This is VoiceInk's #1 differentiator and the reason users choose it
- **Effort:** High (3-4 weeks)
- **What to build:** Floating capsule window that appears on hotkey with: audio visualiser, AI prompt selector dropdown, Power Mode selector, enhancement toggle. Dismiss with hotkey or Escape.
- **Why:** Without this, EchoTune feels like a background utility. With it, it becomes an interactive tool.

#### 2. Multi-Prompt System with Trigger Words
- **Impact:** 🔥🔥🔥🔥🔥 — Transforms the product from "transcription" to "intelligent dictation"
- **Effort:** Medium (1-2 weeks)
- **What to build:** Multiple custom AI prompts with icons, per-prompt trigger words, keyboard shortcuts (⌘1-⌘0). The `PromptDetectionService` concept is brilliant — say "translate" at the start of your sentence and it auto-selects the translation prompt.
- **Why:** This is the core "power user" feature that creates lock-in.

#### 3. Adopt `KeyboardShortcuts` Library
- **Impact:** 🔥🔥🔥🔥 — Eliminates bugs, adds features for free
- **Effort:** Low (2-3 days)
- **What to build:** Replace raw CGEvent tap with `sindresorhus/KeyboardShortcuts`. Add second configurable hotkey, hands-free mode, custom shortcut recording UI.
- **Why:** Current ShortcutManager is fragile (raw Carbon API). The library handles edge cases, modifier key detection, and provides SwiftUI recording views out of the box.

#### 4. More Cloud Providers (Gemini, ElevenLabs Scribe)
- **Impact:** 🔥🔥🔥🔥 — Users want choice; Gemini is free-tier friendly
- **Effort:** Low-Medium (1 week per provider)
- **What to build:** Add Gemini (multimodal audio transcription — very unique approach), ElevenLabs Scribe, and an OpenAI-compatible custom endpoint option.
- **Why:** Gemini offers free API access. ElevenLabs Scribe is very accurate. Custom endpoint supports self-hosted solutions.

#### 5. More AI Enhancement Providers
- **Impact:** 🔥🔥🔥🔥 — Many users prefer Gemini/Groq for speed
- **Effort:** Low (3-5 days)
- **What to build:** Add Groq, Gemini, Cerebras, Mistral, OpenRouter, and Ollama (local) as AI enhancement providers. VoiceInk supports all of these.
- **Why:** Currently EchoTune only supports OpenAI and Anthropic for enhancement. Fast providers like Groq/Cerebras make enhancement feel instant. Ollama enables fully offline operation.

### 🟡 High Priority (High Impact, Moderate Effort)

#### 6. Selected Text Context
- **Impact:** 🔥🔥🔥🔥 — Enables "edit selection" workflows
- **Effort:** Low (2-3 days)
- **What to build:** Use `SelectedTextKit` (same library VoiceInk uses) or accessibility APIs to grab currently-selected text and inject into AI enhancement context.
- **Why:** Allows users to select text, press hotkey, say "make this more formal", and have the AI rewrite only the selected text.

#### 7. Upgrade Screen Capture
- **Impact:** 🔥🔥🔥 — Better context = better transcription
- **Effort:** Low (1-2 days)
- **What to build:** Switch from `CGDisplayCreateImage` to `ScreenCaptureKit` (`SCScreenshotManager`). Capture only the active window. Use `.accurate` recognition level.
- **Why:** Current implementation captures the entire screen which is noisy. VoiceInk captures just the active window at 2× resolution.

#### 8. Audio File Transcription
- **Impact:** 🔥🔥🔥 — Unlocks a whole new use case
- **Effort:** Medium (2 weeks)
- **What to build:** Drag-and-drop audio/video files for transcription. Support common formats (mp3, m4a, wav, mp4, mov).
- **Why:** Many users want to transcribe meetings, podcasts, voice memos.

#### 9. Filler Word Removal
- **Impact:** 🔥🔥🔥 — Quick win for transcription quality
- **Effort:** Low (2-3 days)
- **What to build:** Configurable filler word list with regex-based removal as a post-processing step (before AI enhancement). Default list: "um", "uh", "like", "you know", etc.
- **Why:** VoiceInk does this at the output filter level, so it works even without AI enhancement.

#### 10. SwiftData Migration
- **Impact:** 🔥🔥🔥 — Enables features like search, sync, proper data management
- **Effort:** High (2-3 weeks)
- **What to build:** Migrate dictionary and transcription history from UserDefaults to SwiftData. Add iCloud sync for dictionary.
- **Why:** UserDefaults is a scalability bottleneck. Can't search, can't sync, can't handle large histories.

### 🟢 Medium Priority (Moderate Impact)

#### 11. Paste Last / Retry Last Shortcuts
- **Impact:** 🔥🔥 — Power user convenience
- **Effort:** Very Low (1-2 days)
- **What to build:** Global shortcuts for: paste last transcription, paste last enhancement, retry last transcription with different model.

#### 12. Hands-Free Mode
- **Impact:** 🔥🔥🔥 — Important accessibility feature
- **Effort:** Low (2-3 days)
- **What to build:** Brief press of hotkey = hands-free toggle (recording starts, press again to stop). Long press = push-to-talk (recording stops on key release).

#### 13. Siri / App Intents
- **Impact:** 🔥🔥 — Nice integration point
- **Effort:** Low (1-2 days)
- **What to build:** Register AppShortcuts for "Start EchoTune recording", "Stop recording". Enables Shortcuts app and Siri integration.

#### 14. Clipboard Context
- **Impact:** 🔥🔥 — Easy context enrichment
- **Effort:** Very Low (< 1 day)
- **What to build:** Option to include clipboard content in AI enhancement system prompt.

#### 15. History Window
- **Impact:** 🔥🔥 — Better than settings-embedded history
- **Effort:** Medium (1 week)
- **What to build:** Dedicated floating window for transcription history with search, filter, re-transcribe, and export options.

#### 16. Media Pause/Resume During Recording
- **Impact:** 🔥🔥 — Polish feature
- **Effort:** Low (2-3 days)
- **What to build:** Pause active media playback (Spotify, Apple Music, YouTube) when recording starts, resume when done. VoiceInk uses the `MediaRemote` private framework.

---

## 5. Things NOT to Copy

### ❌ Don't Copy VoiceInk's Weaknesses

1. **Monolithic WhisperState** — VoiceInk's `WhisperState` is a god object that handles recording, transcription, model management, enhancement, history, and UI state. It's split across 5+ extension files (`WhisperState+ModelManagement`, `WhisperState+UI`, etc.) which is a code smell. **EchoTune's coordinator pattern is actually cleaner** in concept — just needs the coordinator to delegate more.

2. **EnvironmentObject Soup** — VoiceInk passes 6+ environment objects through the view hierarchy (`whisperState`, `hotkeyManager`, `updaterViewModel`, `menuBarManager`, `aiService`, `enhancementService`). This is fragile. **Keep EchoTune's single-coordinator approach** but make it delegate to sub-managers.

3. **CoreAudio Complexity** — VoiceInk uses raw CoreAudio for recording, which adds significant complexity. Unless you need ultra-low-latency or specific CoreAudio features, **stick with AVAudioEngine** — it's simpler and well-maintained.

4. **Polar.sh Licensing** — VoiceInk uses Polar which is relatively niche. **EchoTune's dual approach (Keychain + StoreKit)** is more flexible and better for App Store distribution.

5. **No Test Coverage** — VoiceInk has essentially empty test files (`VoiceInkTests.swift`, `VoiceInkUITests.swift`). Don't copy this. **Invest in tests for critical paths** (transcription pipeline, dictionary processing, license validation).

### ✅ Where EchoTune Should Differentiate

1. **App Store First** — VoiceInk is direct-sale only. EchoTune's App Store + StoreKit IAP support is a distribution advantage. Lean into this.

2. **VAD Intelligence** — EchoTune's Silero VAD is more sophisticated than VoiceInk's. **Make this a selling point** — "Smart silence detection" that saves API costs.

3. **Performance Transparency** — EchoTune's performance benchmarking is great. **Show users their stats** — transcription time, words per minute, cost per transcription.

4. **Notes Integration** — VoiceInk doesn't have a notes feature. **EchoTune's NotesManager is unique** — expand it into a proper voice journal / meeting notes tool.

5. **Simpler UX** — VoiceInk is feature-dense but complex. EchoTune can win by being **easier to set up and use** out of the box. Not everyone needs 12 cloud providers.

6. **Privacy-First** — Add a "fully offline" mode badge. When using local Whisper + no AI enhancement, zero data leaves the device. Market this.

---

## 6. Technical Recommendations

### Libraries to Adopt

| Library | Purpose | Priority |
|---------|---------|----------|
| `sindresorhus/KeyboardShortcuts` | Keyboard shortcut management | 🔴 Critical |
| `SelectedTextKit` | Get selected text from any app | 🟡 High |
| `ScreenCaptureKit` (system) | Better window capture | 🟡 High |
| `LaunchAtLogin` (sindresorhus) | Clean login item management | 🟢 Nice to have |
| `FluidAudio` | Parakeet/NVIDIA model support | 🟢 Future |

### Patterns to Follow

1. **Service Registry Pattern** — Instead of if/else chains in AppCoordinator for routing to Groq vs Deepgram vs Whisper, create a `TranscriptionServiceProtocol` and a registry that dispatches based on model metadata. This is how VoiceInk handles 9+ providers cleanly.

2. **Split the AppCoordinator** — Move recording logic to a `RecordingCoordinator`, transcription routing to a `TranscriptionServiceRegistry`, and AI enhancement to a standalone `AIEnhancementService`. Keep `AppCoordinator` as a thin orchestrator.

3. **Use os.Logger** — Replace `print()` statements with `os.Logger` using proper subsystem/category. This enables Console.app filtering and production logging.

4. **SwiftData for Persistence** — Migrate dictionary and history to SwiftData. This enables search, sorting, iCloud sync, and proper data management. VoiceInk's separate store approach (one for transcripts, one for dictionary with CloudKit) is worth copying.

5. **Keychain for All Secrets** — Move API keys from `AppSettings` (UserDefaults) to Keychain. VoiceInk has a clean `KeychainService` and `APIKeyManager` pattern to follow.

6. **Output Filter Pipeline** — Create a `TranscriptionOutputFilter` that chains: hallucination removal → filler word removal → word replacement → vocabulary correction → text formatting. Run this before AI enhancement so the AI gets cleaner input.

### Quick Wins (< 1 day each)

- [ ] Add clipboard context toggle for AI enhancement
- [ ] Expose VoiceInk-style hallucination phrases as configurable list
- [ ] Add "Insert space after text" toggle (VoiceInk has this)
- [ ] Add reasoning_effort parameter for OpenAI o-series models
- [ ] Add output filter for bracketed/tagged hallucinations (`[Music]`, `(inaudible)`, `<|en|>`)

### Medium-Term Architecture Goals

1. Migrate from UserDefaults → SwiftData for dictionary + history
2. Replace CGEvent tap → KeyboardShortcuts library
3. Split AppCoordinator into focused coordinators
4. Add a proper TranscriptionServiceProtocol with registry
5. Implement Mini Recorder floating window
6. Add multi-prompt system with trigger words

---

## Appendix A: VoiceInk's Dependency Graph

| Package | Purpose |
|---------|---------|
| `KeyboardShortcuts` (sindresorhus) | Global keyboard shortcut management |
| `FluidAudio` | Parakeet/NVIDIA ASR model support |
| `SelectedTextKit` | Get selected text from any app via accessibility |
| `Sparkle` | Auto-update framework |
| `AXSwift` | Accessibility API wrapper |
| `LaunchAtLogin-Modern` | Launch at login management |
| `KeySender` | Simulate keystrokes for text insertion |
| `MediaRemote-Adapter` | Control media playback (private framework wrapper) |
| `swift-atomics` | Thread-safe atomic operations |
| `Zip` | ZIP file handling (for model downloads) |

## Appendix B: VoiceInk's AI Provider Matrix

### For Transcription (Speech-to-Text):
- **Local:** whisper.cpp, Parakeet v2/v3, Native Apple (macOS 26)
- **Cloud:** Groq, Deepgram, ElevenLabs, Gemini, Mistral, Soniox, OpenAI-compatible, Custom endpoint

### For Enhancement (AI Post-Processing):
- **Cloud:** OpenAI, Anthropic, Groq, Gemini, Cerebras, Mistral, OpenRouter, Custom
- **Local:** Ollama (any local model)

### EchoTune's Current Coverage:
- **Transcription:** Apple Speech, local Whisper, Groq, Deepgram
- **Enhancement:** OpenAI, Anthropic

### Gap: 6 transcription providers + 6 enhancement providers

## Appendix C: VoiceInk's Power Mode vs EchoTune's Power Mode

| Feature | VoiceInk | EchoTune |
|---------|----------|----------|
| App matching | ✅ By bundle ID | ✅ By bundle ID |
| URL matching | ✅ Per-URL rules | ❌ |
| Default mode | ✅ Fallback when no match | ❌ |
| Per-mode transcription model | ✅ | ✅ (cloudModelId) |
| Per-mode AI provider/model | ✅ | ❌ |
| Per-mode AI prompt | ✅ | ❌ (single custom prompt) |
| Per-mode language | ✅ | ✅ |
| Per-mode screen capture | ✅ | ❌ |
| Per-mode auto-send | ✅ | ✅ |
| Per-mode hotkey | ✅ | ❌ |
| Enable/disable individual modes | ✅ | ❌ |
| Drag-to-reorder | ✅ | ❌ |
| Emoji identifier | ✅ | ✅ |
| Priority system | ❌ (order-based) | ✅ (0-100 numeric) |
| Use count tracking | ❌ | ✅ |

---

*This analysis should be refreshed when either product ships major updates. VoiceInk appears to release frequently based on their Sparkle update configuration.*
