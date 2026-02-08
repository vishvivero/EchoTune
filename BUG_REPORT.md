# EchoTune Swift Code Audit — Bug Report

(Generated 2026-02-08)

## BUG: AVAudioPCMBuffer passed outside tap callback without copying (use-after-free / corrupted audio)
**Severity**: Critical
**File**: `Managers/AudioManager.swift:151-176`
**Description**: Inside `inputNode.installTap`, the code forwards the tap’s `buffer` directly via `onAudioBuffer?(buffer)` (line ~172) to Whisper/Apple streaming pipelines. Both `WhisperEngine.appendAudioBuffer` and `TranscriptionEngine.appendAudioBuffer` process buffers asynchronously on background queues.

AVAudioNode tap buffers are not guaranteed to remain valid after the tap callback returns; they may be reused by the audio engine. Sending the original buffer to another queue can result in reading mutated/reused memory.
**Impact**: Intermittent empty/garbled audio, distorted transcripts, random failures (especially under load), “no speech detected” false negatives.
**Fix**: Copy the buffer before handing it to any async pipeline. E.g. create a `copyBuffer(_:)` that supports both Float32 and Int16 and pass the copy to `onAudioBuffer`. Alternatively, require downstream consumers to synchronously consume within tap callback (not recommended).

## BUG: Audio pipeline assumes Float32 channel data even when hardware format may be Int16/interleaved
**Severity**: High
**File**: `Managers/AudioManager.swift:204-266`, `Managers/AudioManager.swift:318-360`, `Managers/AudioManager.swift:640-675`
**Description**: `appendToChunkedStorage`, `mergeAllAudioChunks`, and `copyBuffer` read/write using `buffer.floatChannelData` and `AVAudioPCMBuffer.floatChannelData` exclusively. If the input device/hardware format is not Float32 non-interleaved, `floatChannelData` can be nil.
**Impact**: Silent failure to store audio (chunk storage stays empty), VAD analysis breaks, stopRecording returns nil/empty, transcription fails.
**Fix**: Normalize input to a known internal format at tap time (e.g. Float32 non-interleaved mono at hardware sample rate), or implement copying/merging for Int16 and interleaved formats using `int16ChannelData` / `audioBufferList`.

## BUG: Chunked storage append loop incorrectly handles “buffer spans chunks” and never updates framesAvailable
**Severity**: High
**File**: `Managers/AudioManager.swift:204-246`
**Description**: `appendToChunkedStorage` computes `framesAvailable` once (line ~207) and never recomputes it after allocating a new chunk. Additionally it unconditionally `break`s after the first copy (line ~245), so it cannot copy more than one segment of a buffer.

Today tap buffers are 1024 frames so it usually fits, but any change to tap buffer size or format conversion could make this truncate audio.
**Impact**: Potential truncation/corruption at chunk boundaries; hard-to-debug missing audio on long sessions.
**Fix**: Recompute `framesAvailable` inside the loop after chunk swaps; remove the unconditional `break` and continue copying until `framesToCopy == 0`.

## BUG: Unlimited in-memory buffering of audio chunks can blow memory on long recordings
**Severity**: High
**File**: `Managers/AudioManager.swift:55-60`, `Managers/AudioManager.swift:174-176`, `Managers/AudioManager.swift:295-315`
**Description**: `audioChunks` grows without bounds (“no cap!”). A 30-minute recording at 48kHz Float32 mono is ~345MB; stereo or higher rates is worse.
**Impact**: High memory use → UI lag, app termination by jetsam/OS, failures when merging chunks into one huge buffer.
**Fix**: Stream to disk (incremental CAF/WAV write) during recording, or enforce a maximum buffered duration/bytes with user setting. Avoid merging into a single giant buffer; convert in streaming or chunked conversion.

## BUG: ModelManager mutates @Published properties from a background thread
**Severity**: High
**File**: `Managers/ModelManager.swift:56-69`, `Managers/ModelManager.swift:280-378`
**Description**: `checkInstalledModels()` runs on `DispatchQueue.global` and directly writes `installedModels`, `availableModels[index].isInstalled`, and `currentModel` (all `@Published`) off the main thread.
**Impact**: SwiftUI/Combine thread-safety warnings, race conditions, occasional UI inconsistencies/crashes.
**Fix**: Do the filesystem scanning on a background queue, but marshal all `@Published` mutations back to `DispatchQueue.main` / `MainActor`.

## BUG: Model selection persistence uses two different UserDefaults keys and is not fully synchronized
**Severity**: High
**File**: `Managers/ModelManager.swift:365-377`, `Managers/ModelManager.swift:629-644`, `Models/AppSettings.swift:35-40, 86-94`
**Description**:
- `ModelManager` restores the selected model from `UserDefaults` key `defaultModelID` (line ~366).
- `AppSettings` stores `defaultTranscriptionModel` in a different key: `defaultTranscriptionModel`.
- On startup, after restoring `currentModel`, `ModelManager` does **not** sync `AppSettings.shared.defaultTranscriptionModel` to match.

This can leave `ModelManager.currentModel` and `TranscriptionEngine` routing (which reads `AppSettings.defaultTranscriptionModel`) pointing to different models.
**Impact**: Wrong engine used, e.g. UI shows one model but transcription routes to another; local Whisper selected but Apple Speech used (or vice versa).
**Fix**: Use a single source of truth + single persistence key. On restore, always call `setCurrentModel(restoredModel)` (or explicitly set both `currentModel` and `AppSettings.defaultTranscriptionModel`). Consider removing `defaultModelID` entirely.

## BUG: TranscriptionEngine’s local Whisper routing ignores selectedModel and does not ensure correct model is loaded
**Severity**: High
**File**: `Managers/TranscriptionEngine.swift:104-122`, `Managers/TranscriptionEngine.swift:696-707`
**Description**: For any non-Apple, non-cloud model, `transcribeAudio` routes to `routeToWhisper(...)`, but `routeToWhisper` just calls `WhisperEngine.shared.transcribeAudio(audioData)` without loading the requested model (and without verifying it matches `selectedModel`).
**Impact**: If the selected model is different from the currently loaded WhisperKit model (or nothing is loaded), transcription fails with `.modelNotLoaded` / wrong model used.
**Fix**: In `routeToWhisper`, look up the `AIModel` by `selectedModel` via `ModelManager`, call `WhisperEngine.loadModel(...)` if needed, then transcribe. Also propagate specific errors back instead of `.processingError`.

## BUG: WhisperEngine.loadModel drops completion when called while a load is already in progress
**Severity**: High
**File**: `Managers/WhisperEngine.swift:73-77`
**Description**: When `isLoading` is true, `loadModel` prints a warning and returns without calling `completion`.
**Impact**: Callers can hang indefinitely in a “loading model…” UI state, or never start recording.
**Fix**: Always resolve `completion` (e.g. return `.failure(.modelLoadFailed(...))`, or enqueue callbacks and call them when the in-flight load finishes).

## BUG: Whisper streaming buffer list is not synchronized with async append queue
**Severity**: High
**File**: `Managers/WhisperEngine.swift:255-288`
**Description**: `appendAudioBuffer` appends to `audioBuffers` on `audioProcessingQueue`, but `endStreamingTranscription` reads `audioBuffers` directly on the caller’s thread and snapshots it (line ~287) without synchronizing with the queue.
**Impact**: Race conditions: missing last buffers, inconsistent count, potential crash if array mutated during read.
**Fix**: Synchronize access (e.g. use `audioProcessingQueue.sync` to snapshot, or protect with a lock/actor). Also clear `audioBuffers` on the same queue.

## BUG: Apple Speech live transcription completion is intentionally delayed and may never fire from recognition task handler
**Severity**: Medium
**File**: `Managers/TranscriptionEngine.swift:588-679`
**Description**: `endLiveTranscription()` sets `isTranscribing = false` then clears `liveCompletion = nil` immediately (line ~677). The recognition task handler gates completion on `isActive = isTranscribing` and therefore will not call completion after stop; instead the 3-second timeout block returns accumulated text.
**Impact**: Always waits ~3 seconds after stopping for Apple Speech results; increases perceived latency.
**Fix**: Implement a proper “finishing” state: keep completion alive until either `.isFinal` arrives or a shorter timeout occurs; don’t gate completion on `isTranscribing` when `endAudio()` has been called.

## BUG: AppCoordinator’s 10-second “safety timeout” can reset state while cloud/Whisper work is still in flight
**Severity**: Medium
**File**: `AppCoordinator.swift:420-452`
**Description**: `stopDictation` forces `recordingState = .idle` after 10 seconds if still `.processing`, and calls `transcriptionEngine.cancelTranscription()`. This does not cancel WhisperKit tasks or cloud Tasks started elsewhere.
**Impact**: UI resets to idle while transcription continues; results may insert late or be dropped, and status bar icon can desync.
**Fix**: Track/cancel the active transcription Task(s) for each engine; only reset state when cancellation completes. Increase timeout for long recordings or base it on duration.

## BUG: Cloud transcription services assume audio/wav but AudioManager writes CAF/PCM
**Severity**: Medium
**File**: `Managers/AudioManager.swift:389-520`, `Managers/GroqTranscriptionService.swift:158-195`, `Managers/DeepgramTranscriptionService.swift:96-131`
**Description**: `AudioManager.convertBufferToWAVData` actually writes a CAF file (`recording.caf`) and returns its bytes, but cloud services label uploads as `audio/wav` and `filename="audio.wav"`.
**Impact**: Some servers tolerate it; others may mis-detect format and reduce accuracy or reject requests.
**Fix**: Either (a) actually write WAV (RIFF) for cloud uploads, or (b) upload with the correct filename/content-type (`audio/x-caf` or `audio/aiff`/`audio/l16` as appropriate) and ensure server supports it.

## BUG: Groq chunking logic assumes 16kHz Int16 mono regardless of actual audio format
**Severity**: Medium
**File**: `Managers/GroqTranscriptionService.swift:122-146`
**Description**: Chunking uses `AudioChunker.chunkAudioData(... sampleRate: 16000, bytesPerSample: 2)` while the actual `AudioManager` cloud capture path uses Float32 at hardware sample rate (often 48kHz) and returns CAF bytes.
**Impact**: Chunking boundaries become meaningless; can split in the middle of headers/frames; likely to corrupt chunks and fail transcription.
**Fix**: Chunk based on decoded PCM frames, not raw container bytes. Decode CAF/WAV into PCM first, then split on frame boundaries, then re-encode each chunk properly.

## BUG: ModelManager treats cloud models as “installed” only when API key exists at scan time; no reactive update when key changes
**Severity**: Low
**File**: `Managers/ModelManager.swift:311-327`, `Managers/ModelManager.swift:563-577`
**Description**: `checkInstalledModels()` marks cloud models installed only if `isCloudEnabled(model)` at scan time. If the user later adds an API key in settings, `installedModels`/`availableModels` may not be refreshed unless `checkInstalledModels()` is rerun.
**Impact**: Cloud models may remain unselectable until restart.
**Fix**: Observe API key changes (AppSettings publisher) and refresh cloud model installation flags, or compute “enabled” dynamically rather than storing as `isInstalled`.

## BUG: TextInsertionManager paste method destroys non-string clipboard contents
**Severity**: Low
**File**: `Managers/TextInsertionManager.swift:154-188`
**Description**: `insertViaPaste` clears the pasteboard and restores only the previous **string** content, explicitly dropping images/files/RTF.
**Impact**: Users lose clipboard content (if not plain text).
**Fix**: Use `pasteboard.pasteboardItems` to serialize/restore multiple types by copying data representations, or avoid clearing clipboard by using a private NSPasteboard (not possible for paste) + AX insertion when available.

## BUG: PermissionsManager accessibilityStatus uses .notDetermined even when permission is denied
**Severity**: Low
**File**: `Managers/PermissionsManager.swift:170-199`
**Description**: When not trusted, `accessibilityStatus` is set to `.notDetermined` (line ~194), conflating “denied” and “not yet requested.”
**Impact**: UI may show misleading state, reducing user clarity.
**Fix**: Track a separate “denied” state based on whether the app has ever requested permission, or infer from previous state + time since request.
