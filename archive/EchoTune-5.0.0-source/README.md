# EchoTune

**Private, on-device voice dictation and meeting notes for macOS.**

EchoTune turns speech into text anywhere on your Mac. Hold one key, talk, and
your words appear in whatever app you're using. Transcription runs locally with
Whisper models — with local models selected, your audio never leaves your
machine. Optional AI cleanup and cloud transcription are available if you bring
your own API key, and are always clearly labeled.

EchoTune is open source (GPL-3.0). You can read, build, and modify it freely.
A signed, notarized build with a license key is available for purchase if you'd
rather not build it yourself and want to support development.

## Features

- **Global dictation** — hold the **Option** key (configurable) to dictate into
  any app; release to insert the cleaned-up text.
- **On-device transcription** — Whisper models via WhisperKit, tuned to your
  Mac's hardware. EchoTune recommends the best model for your machine.
- **AI text cleanup (optional)** — fix grammar, remove filler words, and format
  lists using your own OpenAI, Gemini, or Groq API key.
- **Meeting mode** — capture system + microphone audio (no meeting bot), type
  your own notes alongside a live transcript, then generate structured notes
  that merge your notes with what was said.
- **History & dictionary** — searchable transcript history and a custom
  vocabulary so names and jargon are spelled correctly.
- **Menu-bar native** — lives quietly in the menu bar; no Dock clutter.

## Privacy

- With **local models**, audio is transcribed entirely on your device and is
  never uploaded.
- **Cloud transcription** and **AI cleanup** are off unless you add an API key,
  and clearly labeled when active. Those features send audio or transcript text
  to the provider you configured (OpenAI, Google, Groq, or Deepgram).
- **Crash reporting is opt-in** (off by default) and contains no personally
  identifying information.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon recommended for best on-device performance
- ~1 GB free disk for models (varies by model)

## Building from source

```sh
git clone https://github.com/<your-org>/echotune.git
cd echotune
open EchoTune.xcodeproj   # then Build & Run in Xcode
```

Or from the command line:

```sh
xcodebuild -project EchoTune.xcodeproj -scheme EchoTune -configuration Release build
```

Dependencies are resolved automatically via Swift Package Manager.

## License

EchoTune is licensed under the **GNU General Public License v3.0** — see
[`LICENSE`](LICENSE). Attributions and third-party components are listed in
[`NOTICE.md`](NOTICE.md).

Buying a signed binary supports development; the source here is the same app.

---

© 2026 Vishnu Raj
