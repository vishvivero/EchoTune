# Onboarding Fix Plan

## Scope

Investigate and fix these onboarding regressions:

1. Main app opens behind onboarding on first launch.
2. Screen recording permission flow does not properly resume onboarding after quit/reopen.
3. Model download reports "Ready" but the onboarding demo still fails.
4. Get license / upgrade flow hangs.

This document started as an implementation plan. The first onboarding fix pass is now implemented.

## Implemented In This Pass

- Added a shared persisted onboarding state store for `hasCompletedOnboarding` and the current onboarding step.
- Gated the main `WindowGroup` so onboarding is the only primary UI until onboarding completes.
- Restored onboarding to the saved step on relaunch and clear saved progress on completion.
- Persisted the permissions step before opening screen recording settings so restart/relaunch returns to onboarding cleanly.
- Tightened onboarding permission guidance so Accessibility and Screen Recording grant actions open the privacy pane directly, tell the user exactly which EchoTune toggle to enable, and auto-refresh when the app becomes active again.
- Updated the app delegate to use `.regular` activation while onboarding is incomplete, bring the onboarding window to the front, then switch back to `.accessory` after completion.
- Changed onboarding setup so the recommended Whisper model is only marked ready after `ModelManager` is ready, the model is installed, selected, and `WhisperEngine.loadModel(...)` succeeds.
- Updated the onboarding live demo to transcribe through the actually selected engine path: Apple Speech for the built-in model, Whisper for local models, and explicit actionable errors for missing permissions, missing models, cloud-only selections, empty audio, and load/transcription failures.
- Moved onboarding upgrade and direct-license actions into onboarding-owned UI:
  - App Store builds now present `PurchaseView` from the onboarding window itself.
  - Direct-sale builds now expose a deterministic `Get License` browser CTA plus inline activation, with explicit success/failure status instead of relying on a dashboard-owned sheet.
- Replaced the blocking post-onboarding welcome alert with a direct handoff that activates the app and brings the main dashboard window forward after onboarding closes.

## Additional Polish Pass

- Removed the automatic `tccutil reset Accessibility ...` step from `PermissionsManager.requestAccessibilityPermission()`. EchoTune now triggers the native Accessibility prompt and immediately opens the exact Accessibility pane instead of clearing existing TCC state.
- Kept permission re-entry/resume behavior intact while tightening the copy in onboarding and Settings:
  - Accessibility and Screen Recording cards now explain exactly which EchoTune toggle to enable.
  - Both surfaces explicitly call out that permission state refreshes when EchoTune becomes active again.
  - Settings now exposes pane-specific buttons for Accessibility and Screen Recording instead of a generic privacy shortcut.
- Left the existing foreground permission refresh in place so returning from System Settings re-checks microphone, Accessibility, and Screen Recording automatically.
- Reworked trial-state CTAs so "Trial Active" is no longer passive:
  - Main dashboard now shows `Upgrade to Pro` on App Store builds and `Purchase Now` on direct-sale builds.
  - Menu bar and License settings use the same explicit purchase wording.
  - CTA clicks now route directly into the purchase flow via `AppCoordinator.presentPurchaseFlow()`.
- Replaced the menu bar icon asset with a transparent bar-glyph that matches the EchoTune logo shape, and adjusted `StatusBarController` sizing/scaling for native macOS menu bar rendering.
- Tightened the floating recording indicator presentation by removing the extra transparent host padding and window shadow so only the intended dark pill remains visible.

## Final Cleanup Pass

- Removed the remaining misleading onboarding footer text that still claimed a false `50 transcriptions` cap. Trial copy now matches the real 7-day full-access logic.
- Tightened licensing and purchase wording across onboarding, App Store purchase UI, and Settings so the business model is explicit:
  - App Store builds use a one-time Pro unlock purchased through the Apple Account.
  - Direct-sale builds use a one-time EchoTune license activated with a purchased license key.
- Updated the menu bar status item so the EchoTune brand mark remains visible while recording, processing, and error states are active. State is now shown with a small colored badge instead of swapping to a generic SF Symbol.
- Stopped the background accessibility polling timer once trust is granted, and stopped onboarding-local permission polling once the required permissions are satisfied.
- Gated `Reset Onboarding...` behind debug/internal-testing switches so it stays available for QA without exposing it to normal production users.
- Removed stale permission UX left over from the older flow by deleting unused generic permission-alert helpers and aligning the standalone permissions window with the newer pane-specific actions and copy.

## Key Files And Current State Flow

### App launch and window ownership

- `EchoTune/EchoTuneApp.swift`
  - Always creates the main `WindowGroup` with `MainDashboardView()`.
  - Also creates the `Settings` scene.
- `EchoTune/App/AppDelegate.swift`
  - Sets `NSApp.setActivationPolicy(.accessory)`.
  - On first launch, calls `showOnboarding()`.
  - `showOnboarding()` opens a separate `NSWindow` for `OnboardingView`.
  - It explicitly does not call `NSApp.activate(ignoringOtherApps:)`.
- `EchoTune/AppCoordinator.swift`
  - Defers manager initialization until onboarding posts `OnboardingCompleted`.
  - Owns `showPurchaseSheet` and `showLicenseSheet`, which are later consumed by the main dashboard.
- `EchoTune/Views/MainDashboardView.swift`
  - Presents purchase and license sheets from the main dashboard window via `.sheet(...)`.

### Onboarding flow

- `EchoTune/Views/Onboarding/OnboardingView.swift`
  - Holds onboarding progress in local `@State private var currentStep = 0`.
  - Only persists final completion via `UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")`.
  - No persisted step, no resume token, no permission-return state.
- `PermissionsStep`
  - Polls `PermissionsManager.checkAllPermissions()` while visible.
  - Requires microphone + accessibility to continue.
  - Shows screen recording as optional.
- `SetupStep`
  - Downloads a recommended model via `ModelManager.downloadModel(...)`.
  - Now waits for `ModelManager.isReady`, verifies the installed model is discoverable, sets it as current/default, and only shows ready after `WhisperEngine` loads it successfully.
- `LiveDemoStep`
  - Now records and transcribes through the real selected engine path.
  - Returns explicit user-visible errors when the selected model is cloud-only, missing, unloaded, denied permissions, or produces no usable transcription.
- `TrialCTAStep`
  - App Store build: presents `PurchaseView` from the onboarding window via local sheet state.
  - Direct-sale build: exposes both `Get License` and inline activation from onboarding itself.

### Permissions

- `EchoTune/Managers/PermissionsManager.swift`
  - Tracks microphone, accessibility, and screen recording state.
  - Starts a global accessibility polling timer in `init()`.
  - Screen recording request opens System Settings but does not coordinate onboarding resume.
- `EchoTune/Managers/ScreenContextService.swift`
  - Uses `PermissionsManager.shared.hasScreenRecordingPermission` on older macOS.
  - Relevant for validating that screen recording state is actually consumed after onboarding.

### Models and transcription

- `EchoTune/Managers/ModelManager.swift`
  - Scans installed models, restores `currentModel` from `defaultModelID`, syncs `AppSettings.defaultTranscriptionModel`.
  - `downloadModel(...)` marks a model installed, but only sets `currentModel` if `currentModel == nil`.
- `EchoTune/Managers/WhisperEngine.swift`
  - Loads local Whisper models and exposes load failures.
  - Can report success only after the model is genuinely usable.
- `EchoTune/Managers/TranscriptionEngine.swift`
  - Routes based on `AppSettings.shared.defaultTranscriptionModel`.
  - Uses Apple Speech for `"apple-speech"`, Whisper for other local model ids.

### Licensing and upgrade flows

- `EchoTune/Managers/LicenseManager.swift`
  - Handles direct-sale key activation via Polar.
- `EchoTune/Managers/StoreKitManager.swift`
  - Handles App Store purchase state and posts `PurchaseCompleted`.
- `EchoTune/Views/PurchaseView.swift`
  - App Store purchase UI, but only used from the main dashboard sheet.
- `EchoTune/Views/Settings/LicenseSettingsView.swift`
  - Direct-sale activation UI and App Store purchase sheet variant inside Settings.

## Likely Root Causes

### 1. Main app opens behind onboarding on first launch

Primary cause:

- The main dashboard window is created unconditionally by `EchoTuneApp.swift` while onboarding is created separately in `AppDelegate.showOnboarding()`.
- The app is `.accessory`, and onboarding is shown with `makeKeyAndOrderFront(nil)` but without first-launch activation.

Likely effect:

- The dashboard and/or another app can stay in front while onboarding exists behind it.
- The purchase sheet and any follow-on modal that depends on the main dashboard window can also appear behind onboarding or behind another app.

### 2. Screen recording permission does not resume onboarding after quit/reopen

Primary causes:

- Onboarding progress is only in volatile `@State currentStep`; it is lost on quit.
- The only persisted onboarding flag is `hasCompletedOnboarding`, so relaunch restarts from step 0 instead of resuming the permission/setup step.
- `requestScreenRecordingPermission()` has no onboarding-specific resume handoff.

Likely effect:

- If the user quits to complete screen recording permission, reopening the app does not restore them to the relevant onboarding step.
- The flow depends on the user manually navigating back through onboarding.

### 3. Model download says ready but demo fails

Implemented fix:

- `SetupStep` now verifies the recommended model end-to-end before showing ready.
- The downloaded model is explicitly selected as the active/default model.
- The demo uses Apple Speech only when Apple Speech is actually selected, otherwise it loads/transcribes through Whisper directly.

### 4. Get license / upgrade flow hangs

Implemented fix:

- App Store onboarding now opens its purchase UI from the onboarding window itself.
- Direct-sale onboarding now includes an explicit purchase CTA that opens the checkout URL and reports whether the browser handoff succeeded.
- The flow no longer depends on a sheet owned by `MainDashboardView`.

## Implementation Plan

### Step 1. Fix first-launch window ownership first

Reason:

- This is the foundation for issue 1 and likely contributes to issue 4.

Changes to make:

- Gate main dashboard presentation during first-run onboarding, or explicitly hide/defer the main window until onboarding finishes.
- In `AppDelegate.showOnboarding()`, activate the app on first launch only.
- Remove `.resizable` from the onboarding window style mask since min/max size are fixed.

Expected result:

- Only one primary window path is visible during onboarding.
- Onboarding is guaranteed to appear in front on first launch.

### Step 2. Persist onboarding progress and permission-return state

Reason:

- This is required for issue 2 and will make the whole flow restart-safe.

Changes to make:

- Persist current onboarding step in `UserDefaults` or a small onboarding state object.
- Save step transitions from `OnboardingView.goForward()` / `goBack()`.
- On launch, if `hasCompletedOnboarding == false`, restore the saved step instead of always starting at 0.
- When screen recording is requested, persist a resume target such as "permissions" or "setup".
- On onboarding re-entry, re-check permissions immediately and auto-advance if the required state is already satisfied.

Expected result:

- Quit/reopen returns the user to the right onboarding context.
- Permission flows stop feeling lossy.

### Step 3. Make setup "ready" mean real transcription readiness

Reason:

- This isolates issue 3 and removes the current "downloaded != usable" mismatch.

Changes to make:

- In `SetupStep`, after a successful download:
  - Set the downloaded model as current/default via `ModelManager.setCurrentModel(...)`.
  - Attempt `WhisperEngine.loadModel(...)`.
  - Only show "Ready" after load succeeds.
  - Surface a real error state if load fails.
- In `LiveDemoStep`, route the demo through the same engine selection as normal app transcription:
  - Use `TranscriptionEngine` only when Apple Speech is actually selected.
  - Use `WhisperEngine` when a local Whisper model is selected and loaded.

Expected result:

- "Ready" means the selected model is both downloaded and usable.
- Demo behavior matches the model the user just configured.

### Step 4. Move license / purchase presentation into the onboarding window

Reason:

- This resolves the modal ownership mismatch behind issue 4.

Changes to make:

- Present purchase and license UI directly from `TrialCTAStep` or a dedicated onboarding-owned sheet.
- Do not depend on `MainDashboardView` to host onboarding-triggered purchase UI.
- For direct-sale builds, add an explicit "Buy License" action next to "I have a license key".
- After successful activation or purchase, update shared license state and continue onboarding in-place.

Expected result:

- Upgrade actions create visible UI immediately.
- Both App Store and direct-sale users have a complete path from onboarding.

### Step 5. Clean up state synchronization and add regression checks

Reason:

- The current issues are all state-sync problems.

Changes to make:

- Ensure onboarding completion clears any persisted temporary onboarding-step/resume state.
- Verify `AppCoordinator.updateLicenseState()` is called after purchase/license success.
- Verify model selection syncs both `ModelManager.currentModel` and `AppSettings.defaultTranscriptionModel`.
- Add targeted UI/manual test coverage for:
  - first launch window ordering
  - quit/reopen during permissions
  - downloaded-model live demo
  - onboarding upgrade/license presentation

Expected result:

- Fixes remain stable and don’t regress when windowing or onboarding copy changes.

## Recommended Fix Order

1. Window ownership and first-launch activation.
2. Persisted onboarding step / permission resume.
3. Model readiness and demo routing.
4. Onboarding-owned purchase / license UI.
5. Regression tests and cleanup.

## Notes For Implementation

- Avoid spreading more onboarding state into unrelated managers; a small persisted onboarding-state model is likely cleaner than more booleans in `PermissionsManager`.
- Reuse the same transcription routing path in onboarding and the main app where possible; separate demo-only logic is what created the current drift.
- Keep onboarding modal ownership local to the onboarding window. Cross-window sheet triggers are the wrong abstraction here.
