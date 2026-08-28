# EchoTune — Notices & Attributions

EchoTune
Copyright © 2026 Vishnu Raj
Licensed under the GNU General Public License v3.0 (see `LICENSE`).

## Inspiration

EchoTune's dictation experience was inspired by **VoiceInk**
(https://github.com/Beingpax/VoiceInk), an open-source macOS dictation app
licensed under GPL-3.0. EchoTune is an independent implementation; its
dictation-related source was rewritten from behavior specifications. In the
spirit of that lineage, EchoTune is likewise released under GPL-3.0.

## Bundled / Dependent Open-Source Components

EchoTune builds on the following third-party packages, retrieved via Swift
Package Manager. Each remains under its own license:

- **WhisperKit** (Argmax, Inc.) — MIT — on-device Whisper transcription
  https://github.com/argmaxinc/WhisperKit
- **swift-transformers** (Hugging Face) — Apache-2.0
- **swift-jinja** (Hugging Face) — Apache-2.0
- **swift-collections** (Apple) — Apache-2.0 with Runtime Library Exception
- **swift-argument-parser** (Apple) — Apache-2.0 with Runtime Library Exception
- **Sentry** (Sentry, functional-source / MIT for the Cocoa SDK) — optional,
  opt-in crash reporting only

## Speech Models

Local transcription uses OpenAI Whisper and Distil-Whisper model weights,
distributed by Argmax via the WhisperKit CoreML model repository, under their
respective upstream licenses.

## Trademarks

"EchoTune" and its logo are trademarks of the project author. The GPL grants
rights to the software; it does not grant rights to the name or logo.
