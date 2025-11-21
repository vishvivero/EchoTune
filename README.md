# EchoTune - Local AI Voice Dictation for macOS

EchoTune is a privacy-focused voice dictation application for macOS that uses local AI models to convert speech to text, ensuring complete privacy and offline functionality.

## Features

- **Local Processing**: All voice data is processed on your device
- **Global Keyboard Shortcut**: Press ⌘⇧D anywhere to start dictation
- **High Accuracy**: Uses state-of-the-art speech recognition models
- **Multiple Models**: Choose between fast, balanced, or accurate transcription
- **Statistics Dashboard**: Track your productivity and time saved
- **System Integration**: Works in any application
- **Menu Bar Access**: Quick access to controls and recent transcriptions
- **Transcription History**: Save and search past transcriptions

## System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon Mac recommended for best performance
- 4GB RAM minimum (8GB+ recommended)
- 1GB free disk space (more for additional models)

## Getting Started

1. **Install EchoTune**
   - Download the latest version from the [EchoTune website](https://echotune.app)
   - Drag to your Applications folder

2. **Grant Permissions**
   - Microphone access (required for voice capture)
   - Speech recognition (required for transcription)
   - Accessibility (required for text insertion)

3. **Choose a Model**
   - Fast: 27MB, 5-10x realtime, good accuracy
   - Balanced: 140MB, 2-3x realtime, very good accuracy
   - Accurate: 550MB, 1x realtime, excellent accuracy

4. **Start Dictating**
   - Press ⌘⇧D to start recording
   - Speak clearly into your microphone
   - Release ⌘⇧D to process and insert text

## Implementation Details

EchoTune is built using Swift and SwiftUI, with a focus on performance and user experience. The application is structured into three main phases:

### Phase 1: Core Application Structure
- Menu bar integration
- Dashboard UI
- Navigation system
- Settings framework

### Phase 2: Audio Capture and Processing
- Audio recording system
- Transcription engine with Apple Speech
- Model management system
- Statistics tracking

### Phase 3: System Integration and Polish
- Global keyboard shortcuts
- Licensing and trial system
- Settings and permissions management
- Final testing and documentation

## Privacy and Security

EchoTune is designed with privacy as a core principle:

- All audio processing happens locally on your device
- No audio data is sent to external servers
- Optional: Use Apple Speech (requires internet) or local Whisper models (100% offline)
- No analytics or telemetry unless explicitly enabled by user

## License

EchoTune is available as a 7-day trial, after which a license must be purchased:

- **Individual License**: $29.99 (one-time purchase)
- **Pro License**: $49.99 (one-time purchase, 3 devices)

## Support

For support, feature requests, or bug reports, please visit:
- [EchoTune Support](https://echotune.app/support)
- [Email Support](mailto:support@echotune.app)

## Credits

EchoTune uses the following open-source technologies:
- [Whisper](https://github.com/openai/whisper) by OpenAI
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov

## Development

This project was developed by Vishnu Raj in 2025.

---

© 2025 EchoTune Software. All rights reserved.







