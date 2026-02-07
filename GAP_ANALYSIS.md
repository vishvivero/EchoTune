# EchoTune vs VoiceInk: Gap Analysis & Implementation Status

## Date: 2026-02-07

---

## Gap Analysis Summary

### 1. Screen Context (OCR + System Awareness)
**VoiceInk:** Full OCR via Vision framework on frontmost window, clipboard capture, selected text via Accessibility API, browser URL detection — all fed into AI prompts for context-aware transcription.

**EchoTune (Before):** Basic `CGDisplayCreateImage` full-screen capture with OCR. No clipboard, no selected text, no browser URL integration. Context analysis was text-only (no app/URL awareness).

**EchoTune (After ✅):**
- Frontmost window capture via `CGWindowListCreateImage` (per-window, not full screen)
- Clipboard text capture via `NSPasteboard`
- Selected text capture via macOS Accessibility API (`AXUIElement`)
- Browser URL + title integration with `BrowserContextDetector`
- Multi-layered context type detection (app bundle ID → URL → text heuristics)
- Full rich context fed into AI enhancement prompts (app, URL, selected text, clipboard, keywords, OCR snippet)

---

### 2. App-Aware Power Mode (Auto-Switching)
**VoiceInk:** Automatically switches AI models, prompts, and settings when the user changes apps. Monitors `NSWorkspace.didActivateApplicationNotification`.

**EchoTune (Before):** Had Power Mode matching logic but only triggered at recording start (`detectAndApplyPowerMode()` called manually). No real-time monitoring.

**EchoTune (After ✅):**
- `NSWorkspace.didActivateApplicationNotification` observer for real-time app switch detection
- 300ms debounce to avoid rapid-fire during fast switching
- `isAutoSwitchEnabled` toggle for users who prefer manual-only
- Auto-reverts to global settings when no Power Mode matches
- Settings UI updated with Auto-Switch toggle

---

### 3. Modifier Key Hotkeys (Push-to-Talk)
**VoiceInk:** Supports single modifier keys (Right Command, Left Option, Fn/Globe) as push-to-talk triggers. Much faster than key combos.

**EchoTune (Before):** `MultiHotkeyManager` used Carbon `RegisterEventHotKey` which cannot register modifier-only hotkeys. `ShortcutManager` had some modifier support but was a separate system.

**EchoTune (After ✅):**
- `ModifierKeyTrigger` enum with all variants (Left/Right Cmd, Option, Control, Fn/Globe)
- CGEvent tap monitors `flagsChanged` events for modifier-only detection
- Uses `keyCode` from `CGEvent` to distinguish left vs right modifier keys
- Listen-only event tap (doesn't consume events, avoids breaking system shortcuts)
- `setModifierTrigger()` API for easy assignment
- Dedicated "Modifier Key Triggers" section in HotkeysView with Picker UI

---

### 4. Trigger Word Detection
**VoiceInk:** Supports "trigger words" that dynamically activate AI enhancement or switch prompts, even if AI is globally off. Scans transcription for keywords.

**EchoTune (Before):** No trigger word support. AI enhancement was always the same prompt.

**EchoTune (After ✅):**
- `TriggerWordRule` model: trigger phrase, custom prompt, force-AI flag, auto-strip option
- `detectTriggerWords()` scans transcript for matches (prefix, suffix, or contains)
- Trigger word prompt overrides default/custom prompt
- `activateAI` flag can force-enable AI even when globally off
- `removeTriggerFromOutput` auto-strips the trigger phrase from final text
- 5 default rules: "fix this", "summarize", "translate to spanish", "make it formal", "make it casual"
- Full CRUD (add/edit/delete/toggle) with persistence via UserDefaults
- `TriggerWordsView` settings UI with add/edit sheets
- Integrated into `AppCoordinator.processAndInsertText` pipeline

---

### 5. Notch/Mini Recorder UI
**VoiceInk:** Multiple recorder interfaces — Notch Recorder (compact, notch-area), Mini Recorder (floating panel). Feel native to macOS.

**EchoTune (Before):** Only slim bottom-bar `RecordingIndicatorWindow`.

**EchoTune (After ✅):**
- `NotchRecorderWindow`: compact pill UI in the MacBook notch area (screenSaver level, above menu bar)
- `MiniRecorderWindow`: floating draggable panel with waveform, timer, Power Mode badge
- Both use live `AudioManager` data with VAD-aware coloring
- `RecorderStyle` enum (Slim Bar, Notch Recorder, Mini Panel) in AppSettings
- `showRecorderUI()/hideRecorderUI()` in AppCoordinator dispatches to correct style
- All recording entry/exit points updated
- Picker in GeneralSettingsView

---

## Remaining Gaps (Lower Priority)

| Gap | VoiceInk | EchoTune | Priority |
|-----|----------|----------|----------|
| SwiftData persistence | Uses SwiftData for history/vocabulary | UserDefaults | Low |
| Parakeet (Apple ASR) | Supports Apple's neural ASR | Apple Speech (SFSpeech) | Low |
| Mouse middle-click trigger | Supported | Not implemented | Low |
| Vocabulary AI context | Dictionary fed into ASR model | Dictionary only in AI prompt | Low |
| AppleScript-free URL detection | Could improve | Using AppleScript (current approach works) | Low |

---

## Files Modified

### New Files
- `EchoTune/Views/NotchRecorderView.swift`
- `EchoTune/Views/MiniRecorderView.swift`
- `EchoTune/Views/Settings/TriggerWordsView.swift`

### Modified Files
- `EchoTune/Managers/ScreenContextService.swift` — Enhanced with clipboard, selected text, window capture, browser URL
- `EchoTune/Managers/AIEnhancementEngine.swift` — Trigger words + rich context prompts
- `EchoTune/Managers/PowerModeManager.swift` — NSWorkspace app-switch monitoring
- `EchoTune/Managers/MultiHotkeyManager.swift` — Modifier key event tap support
- `EchoTune/AppCoordinator.swift` — Trigger word integration + recorder style dispatch
- `EchoTune/Models/AppSettings.swift` — RecorderStyle setting
- `EchoTune/Views/Settings/PowerModesView.swift` — Auto-switch toggle
- `EchoTune/Views/Settings/HotkeysView.swift` — Modifier key triggers section
- `EchoTune/Views/Settings/GeneralSettingsView.swift` — Recorder style picker
- `EchoTune/Views/SettingsView.swift` — Trigger Words section in consolidated settings
