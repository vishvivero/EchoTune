# EchoTune Meeting Mode — Implementation Plan

## What Granola Does (Competitive Analysis)
- Captures system audio directly (no meeting bots joining calls)
- Works on Zoom, Teams, Google Meet, etc.
- Transcribes the full meeting in real-time
- User can take their own notes alongside
- After meeting ends, AI enhances notes with transcript context
- Generates structured summaries: action items, decisions, key points
- Customizable templates (sales calls, 1:1s, interviews)
- "Ask Granola anything" — chat with your transcript
- One-click share to Slack, email, Notion, CRM
- Pricing: Free (25 meetings), $10/mo Pro, $18/mo Business

## EchoTune Meeting Mode — Feature Plan

### Phase 1: Core Meeting Recording (This Build)
1. **Settings Toggle**: "Meeting Mode" in Settings > General
2. **System Audio Capture**: Use ScreenCaptureKit `SCStream` to capture system audio (what Zoom/Teams/Meet output)
3. **Combined Audio**: Mix system audio + microphone for full meeting capture
4. **Meeting Session Manager**: Start/stop meeting recording, track duration, auto-detect meeting apps
5. **Long-Form Transcription**: Continuous transcription during meeting (chunked, not one massive buffer)
6. **Meeting Summary**: AI-generated summary when meeting ends (action items, decisions, key points)
7. **Meeting History**: Separate "Meetings" tab showing past meetings with transcripts + summaries
8. **Auto-Detection**: Optionally auto-start when Zoom/Teams/Meet opens (via PowerMode detection)

### Architecture

```
MeetingManager (new)
├── SystemAudioCapture (ScreenCaptureKit SCStream for system audio)
├── MicrophoneCapture (existing AudioManager)
├── AudioMixer (combines both streams)
├── ChunkedTranscriber (sends chunks every 30s to Groq/Whisper)
├── LiveTranscriptBuffer (running transcript)
├── MeetingSummaryEngine (AI summary on meeting end)
└── MeetingStorage (CoreData/JSON for meeting history)
```

### Files to Create
- `EchoTune/Managers/MeetingManager.swift` — orchestrates meeting recording
- `EchoTune/Managers/SystemAudioCapture.swift` — ScreenCaptureKit audio capture
- `EchoTune/Managers/MeetingSummaryEngine.swift` — AI summary generation
- `EchoTune/Models/MeetingSession.swift` — data model for meetings
- `EchoTune/Views/Meeting/MeetingView.swift` — meeting tab UI
- `EchoTune/Views/Meeting/MeetingDetailView.swift` — individual meeting view
- `EchoTune/Views/Meeting/MeetingListView.swift` — list of past meetings
- `EchoTune/Views/Settings/MeetingSettingsView.swift` — settings for meeting mode

### Key Technical Details
- **ScreenCaptureKit**: macOS 13+ `SCStream` with `capturesAudio = true` for system audio
- **No meeting bot**: Direct audio capture from system output (like Granola)
- **Privacy**: Screen Recording permission required (already partially handled in PermissionsManager)
- **Chunked Transcription**: 30-second chunks → Groq cloud for speed, or local Whisper
- **Summary Prompt**: Structured output with sections (Summary, Action Items, Decisions, Key Points)
- **Storage**: JSON files in `~/Library/Application Support/EchoTune/Meetings/`

### Settings UI
- Meeting Mode: On/Off toggle
- Auto-detect meetings: Toggle (when Zoom/Teams/Meet detected)
- Summary template: Dropdown (General, Sales Call, 1:1, Interview, Custom)
- Auto-summarize on end: Toggle
- Include mic audio: Toggle (for capturing your own voice too)
