# EchoTune - Product Requirements Document (PRD)

**Version:** 1.0
**Date:** October 25, 2025
**Product:** EchoTune - Local AI Voice Dictation for macOS
**Target Platform:** macOS 13.0+ (Ventura and later)

---

## 1. Executive Summary

EchoTune is a privacy-first, local AI-powered voice dictation application for macOS that enables users to convert speech to text anywhere on their Mac using state-of-the-art local language models. Unlike cloud-based solutions, EchoTune processes all audio locally, ensuring complete privacy and offline functionality.

### Key Value Propositions
- **100% Privacy**: All processing happens on-device; no data leaves the user's Mac
- **System-wide Access**: Works in any application via global keyboard shortcut
- **Offline Operation**: No internet connection required
- **Superior Accuracy**: Leverages Whisper AI for high-quality transcription
- **Low Latency**: Optimized for real-time dictation experience

---

## 2. Market Analysis

### 2.1 Competitive Landscape

| Competitor | Strengths | Weaknesses | Price |
|------------|-----------|------------|-------|
| SuperWhisper | Mature, polished UI | Subscription model | $10/month |
| MacWhisper | File transcription focus | Not optimized for real-time dictation | $20-30 one-time |
| Voice Type | Fast, local processing | Limited features | $15 one-time |
| Apple Dictation | Built-in, free | Poor accuracy, requires internet | Free |

### 2.2 Market Opportunity
- Growing privacy concerns driving demand for local processing
- Remote workers and content creators need reliable dictation
- Competitive pricing opportunity with one-time purchase model
- Estimated market: 50M+ Mac users, 2-5% addressable market

---

## 3. Target User Personas

### Primary Persona: "Sarah the Solopreneur"
- **Role**: Freelance writer/consultant
- **Age**: 28-45
- **Tech Savvy**: Moderate to high
- **Pain Points**:
  - Types 4-8 hours daily, experiencing RSI
  - Needs fast content creation
  - Privacy-conscious, doesn't trust cloud services
  - Works in coffee shops with unreliable internet
- **Goals**: Increase productivity, reduce typing strain

### Secondary Persona: "Alex the Developer"
- **Role**: Software engineer
- **Age**: 25-40
- **Tech Savvy**: High
- **Pain Points**:
  - Writes documentation, code comments
  - Prefers local-first tools
  - Values efficiency and keyboard-driven workflows
- **Goals**: Speed up documentation, stay in flow state

---

## 4. Product Requirements

### 4.1 Core Features (MVP - Phase 1)

#### F1: Voice Dictation Engine
**Priority:** P0 (Critical)

**Requirements:**
- Real-time speech-to-text conversion using local Whisper model
- Support for multiple model sizes:
  - Fast (27MB): 5-10x realtime speed, good accuracy
  - Balanced (140MB): 2-3x realtime speed, better accuracy
  - Accurate (550MB): 1x realtime speed, best accuracy
- Automatic language detection
- Support for 50+ languages
- Audio streaming from system microphone
- Real-time transcription with <500ms latency (Fast model)

**Success Criteria:**
- >95% accuracy on clear speech (English)
- <1 second delay from speech stop to text insertion

#### F2: Global Keyboard Shortcut Activation
**Priority:** P0 (Critical)

**Requirements:**
- Customizable global keyboard shortcut (default: Cmd+Shift+D)
- Push-to-talk mode (hold key to record)
- Toggle mode (press once to start, press again to stop)
- Visual feedback indicator during recording
- Works system-wide across all applications
- Conflict detection with system shortcuts

**Success Criteria:**
- 100% reliable shortcut capture
- <100ms activation latency

#### F3: System-wide Text Insertion
**Priority:** P0 (Critical)

**Requirements:**
- Insert transcribed text at cursor position in any app
- Support for rich text applications (Word, Google Docs, etc.)
- Support for plain text applications (Terminal, VS Code, etc.)
- Auto-punctuation option
- Smart capitalization

**Success Criteria:**
- Works in >95% of macOS applications
- Preserves cursor position and selection state

#### F4: Menu Bar Application
**Priority:** P0 (Critical)

**Requirements:**
- Lives in menu bar (no dock icon option)
- Quick status indicator (idle/recording/processing)
- Menu with:
  - Start/Stop dictation
  - Settings
  - Model selection
  - About
  - Quit
- Native macOS design language

#### F5: Launch at Startup
**Priority:** P1 (High)

**Requirements:**
- Optional launch at login via user setting
- Uses modern SMAppService API
- Disabled by default (user opt-in)
- Starts minimized to menu bar
- Permission request on first enable

#### F6: License Activation System
**Priority:** P0 (Critical)

**Requirements:**
- License key format: XXXXX-XXXXX-XXXXX-XXXXX
- Activation flow:
  1. Trial mode (7 days, full features)
  2. Purchase license key
  3. Enter license in app
  4. Online activation (one-time)
  5. Offline grace period (30 days)
- Single-user license (1 activation per key)
- Transfer license option (deactivate old device)
- License validation on app launch
- Graceful degradation if activation server unavailable

**Success Criteria:**
- <5 second activation time
- 99.9% activation success rate

### 4.2 Settings & Configuration

#### F7: Settings Panel
**Priority:** P1 (High)

**Requirements:**
- Native macOS settings window
- Settings categories:
  - **General**
    - Launch at login toggle
    - Keyboard shortcut customization
    - Recording mode (push-to-talk vs toggle)
  - **Model**
    - Model size selection (Fast/Balanced/Accurate)
    - Language preference
    - Model download status
  - **Privacy**
    - Audio history toggle (keep/delete recordings)
    - Usage analytics toggle (opt-in)
  - **Advanced**
    - Auto-punctuation toggle
    - Smart capitalization toggle
    - Custom vocabulary/corrections
  - **License**
    - License key entry
    - Activation status
    - Deactivate/transfer option

### 4.3 Enhanced Features (Phase 2)

#### F8: Voice Commands
**Priority:** P2 (Nice to have)

**Requirements:**
- Built-in commands:
  - "new paragraph" → insert double newline
  - "new line" → insert single newline
  - "period", "comma", "question mark" → insert punctuation
  - "undo that" → delete last transcription
  - "scratch that" → delete and restart
- Custom command creation

#### F9: Multi-language Support
**Priority:** P2 (Nice to have)

**Requirements:**
- Language selector in menu bar
- Fast language switching
- Per-application language memory
- Support for 50+ languages

#### F10: Transcription History
**Priority:** P2 (Nice to have)

**Requirements:**
- Optional history panel
- Last 50 transcriptions saved
- Copy/paste from history
- Search history
- Clear history option

---

## 5. User Flows

### 5.1 First-Time Setup Flow

```
1. User downloads EchoTune.dmg
2. User drags app to Applications
3. User opens EchoTune
4. Welcome screen appears:
   - Brief introduction
   - Feature highlights
   - "Start Trial" button (7 days)
5. Permission requests:
   - Microphone access (required)
   - Accessibility access (required for text insertion)
6. Model download:
   - Select initial model (default: Balanced)
   - Download progress indicator
   - "Model ready" confirmation
7. Tutorial:
   - Interactive guide showing keyboard shortcut
   - Practice dictation test
   - Success confirmation
8. App minimizes to menu bar
9. Trial period begins
```

### 5.2 Voice Dictation Flow

```
1. User positions cursor in target application
2. User presses global shortcut (Cmd+Shift+D)
3. Visual indicator appears (menu bar icon changes)
4. User speaks
5. User releases shortcut (or presses again)
6. Audio processing begins
7. Transcribed text appears at cursor position
8. Indicator returns to idle state
```

### 5.3 License Activation Flow

```
1. Trial expires → notification appears
2. User clicks "Purchase License"
3. Browser opens to purchase page
4. User completes purchase, receives license key via email
5. User clicks "Enter License" in app
6. User pastes license key
7. App validates format
8. App contacts activation server
9. Activation success → full version unlocked
10. Confirmation message displayed
```

---

## 6. Technical Architecture

### 6.1 Technology Stack

**Core Application:**
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI + AppKit (for menu bar)
- **Minimum OS:** macOS 13.0 (Ventura)
- **Target Architecture:** Universal Binary (Intel + Apple Silicon)

**Speech Recognition:**
- **Primary Engine:** whisper.cpp (C++ bindings for Swift)
- **Alternative:** MLX-based Whisper (Apple Silicon optimized)
- **Models:** OpenAI Whisper Tiny/Small/Medium (converted to CoreML/MLX)
- **Audio Capture:** AVFoundation (AVAudioEngine)

**System Integration:**
- **Global Shortcuts:** KeyboardShortcuts SPM package
- **Launch at Login:** ServiceManagement framework (SMAppService)
- **Text Insertion:** Accessibility API (CGEvent)
- **Menu Bar:** NSStatusBar

**Licensing:**
- **Platform:** Keygen.sh or LicenseSpring
- **Storage:** Keychain for license storage
- **Validation:** Online + offline grace period

### 6.2 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         EchoTune App                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐      ┌──────────────┐   ┌─────────────┐ │
│  │   SwiftUI    │      │   Menu Bar   │   │  Settings   │ │
│  │  Main Views  │◄────►│   Manager    │◄─►│   Manager   │ │
│  └──────────────┘      └──────────────┘   └─────────────┘ │
│         │                      │                   │        │
│         ▼                      ▼                   ▼        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            Application Coordinator                   │  │
│  └──────────────────────────────────────────────────────┘  │
│         │                      │                   │        │
│  ┌──────▼───────┐      ┌──────▼──────┐    ┌──────▼──────┐ │
│  │  Shortcut    │      │   Audio     │    │   License   │ │
│  │  Handler     │      │   Manager   │    │   Manager   │ │
│  └──────┬───────┘      └──────┬──────┘    └──────┬──────┘ │
│         │                     │                   │        │
│         │              ┌──────▼──────┐            │        │
│         │              │   Whisper   │            │        │
│         │              │   Engine    │            │        │
│         │              └──────┬──────┘            │        │
│         │                     │                   │        │
│         ▼                     ▼                   ▼        │
│  ┌──────────────────────────────────────────────────────┐ │
│  │           System Integration Layer                   │ │
│  ├──────────────────────────────────────────────────────┤ │
│  │  Keyboard   AVFoundation   Accessibility   Keychain  │ │
│  │  Shortcuts                  (Text Insert)            │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                         │            │
                         ▼            ▼
                  ┌───────────┐  ┌──────────┐
                  │  macOS    │  │ Keygen   │
                  │  System   │  │ Server   │
                  └───────────┘  └──────────┘
```

### 6.3 Key Components

#### Audio Manager
- Captures audio from default microphone
- Handles permissions
- Real-time audio streaming to Whisper engine
- Audio level monitoring (visual feedback)

#### Whisper Engine Wrapper
- Loads selected model into memory
- Accepts audio stream
- Returns transcribed text
- Model management (download, storage, switching)
- Performance optimization (Metal acceleration on Apple Silicon)

#### Text Insertion Manager
- Monitors active application
- Uses Accessibility API to insert text at cursor
- Handles special cases (Terminal, secure fields)
- Undo support

#### Shortcut Handler
- Registers global keyboard shortcuts
- Detects conflicts
- Supports both push-to-talk and toggle modes
- Visual feedback coordination

#### License Manager
- Validates license key format
- Communicates with activation server
- Stores encrypted license in Keychain
- Handles offline validation
- Trial period management

### 6.4 Data Flow

```
User Activation (Keyboard Shortcut)
    ↓
Shortcut Handler triggers Audio Manager
    ↓
Audio Manager starts recording
    ↓
Audio stream → Whisper Engine
    ↓
Whisper Engine processes audio
    ↓
Transcribed text returned
    ↓
Text Insertion Manager receives text
    ↓
Text inserted at cursor position
    ↓
User sees transcribed text in active app
```

### 6.5 File Structure

```
EchoTune/
├── App/
│   ├── EchoTuneApp.swift              # App entry point
│   ├── AppCoordinator.swift           # Main coordinator
│   └── AppDelegate.swift              # App lifecycle
├── Models/
│   ├── AppSettings.swift              # User settings model
│   ├── TranscriptionResult.swift      # Transcription data
│   └── LicenseInfo.swift              # License model
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift          # Menu bar UI
│   │   └── StatusIndicatorView.swift  # Recording indicator
│   ├── Settings/
│   │   ├── SettingsView.swift         # Main settings
│   │   ├── GeneralSettings.swift      # General tab
│   │   ├── ModelSettings.swift        # Model tab
│   │   └── LicenseSettings.swift      # License tab
│   ├── Onboarding/
│   │   ├── WelcomeView.swift          # Welcome screen
│   │   ├── PermissionsView.swift      # Permissions request
│   │   └── TutorialView.swift         # Interactive tutorial
│   └── Components/
│       └── LicenseKeyInput.swift      # License entry component
├── Managers/
│   ├── AudioManager.swift             # Audio capture
│   ├── WhisperEngine.swift            # Whisper integration
│   ├── TextInsertionManager.swift     # Text insertion
│   ├── ShortcutManager.swift          # Keyboard shortcuts
│   ├── LicenseManager.swift           # License validation
│   ├── ModelManager.swift             # Model download/storage
│   └── LaunchAtLoginManager.swift     # Startup management
├── Services/
│   ├── LicenseAPIService.swift        # Keygen API client
│   └── AnalyticsService.swift         # Optional analytics
├── Utilities/
│   ├── KeychainHelper.swift           # Keychain access
│   ├── PermissionHelper.swift         # System permissions
│   └── Constants.swift                # App constants
└── Resources/
    ├── Models/                        # Whisper model files
    ├── Assets.xcassets/              # Icons, images
    └── Localizations/                # i18n files
```

### 6.6 Security Considerations

1. **Audio Privacy**: No audio stored by default (user opt-in for history)
2. **License Storage**: Encrypted in Keychain
3. **Code Signing**: Developer ID certificate required
4. **Notarization**: Apple notarization for macOS Gatekeeper
5. **Sandboxing**: Minimal permissions (mic, accessibility only)
6. **Network**: Only for license activation (optional offline mode)

---

## 7. Non-Functional Requirements

### 7.1 Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| App Launch Time | <2 seconds | Cold start to menu bar ready |
| Shortcut Response | <100ms | Key press to recording start |
| Transcription Latency | <1 second | Speech end to text insertion (Fast model) |
| Memory Usage | <500MB | With Balanced model loaded |
| CPU Usage (Idle) | <1% | When not recording |
| CPU Usage (Recording) | <30% | During active transcription |
| Model Load Time | <3 seconds | First transcription after launch |

### 7.2 Reliability

- **Crash Rate:** <0.1% of sessions
- **Activation Success:** >99% (with internet)
- **Transcription Success:** >98% (clear audio)

### 7.3 Accessibility

- Fully accessible via VoiceOver
- Keyboard-only navigation support
- High contrast mode support

### 7.4 Localization

- **Phase 1:** English UI only (supports 50+ languages for speech)
- **Phase 2:** Localized UI for top 10 languages

---

## 8. Licensing & Monetization

### 8.1 License Tiers

**Free Trial:**
- 7-day full-feature trial
- No credit card required
- Converts to limited mode after trial:
  - 5 transcriptions per day
  - Fast model only

**Individual License - $29.99 (One-Time)**
- Lifetime license
- 1 active device
- All features unlocked
- All models included
- Free updates for 1 year
- Major version upgrades: 50% discount

**Pro License - $49.99 (One-Time)**
- Lifetime license
- 3 active devices
- Priority support
- Early access to new features
- Lifetime free updates

### 8.2 Revenue Projections (Conservative)

**Year 1:**
- Target: 500 sales
- Revenue: ~$17,500 (avg $35/license)

**Year 2:**
- Target: 2,000 sales
- Revenue: ~$70,000

**Year 3:**
- Target: 5,000 sales
- Revenue: ~$175,000

### 8.3 Distribution Channels

1. **Primary:** Direct sale via website (keep 95% after payment processor)
2. **Secondary:** Setapp (subscription revenue share)
3. **Not planned:** Mac App Store (licensing restrictions, 30% fee)

---

## 9. Development Phases & Timeline

### Phase 1: MVP (8-10 weeks)

**Week 1-2: Foundation**
- Project setup
- Basic SwiftUI app structure
- Menu bar integration
- Settings framework

**Week 3-4: Audio Pipeline**
- AVFoundation integration
- Microphone permission handling
- Audio streaming infrastructure
- Visual feedback indicators

**Week 5-6: Whisper Integration**
- whisper.cpp integration
- Model loading and management
- Real-time transcription
- Performance optimization

**Week 7: System Integration**
- Global keyboard shortcuts
- Text insertion via Accessibility API
- Launch at login
- App lifecycle management

**Week 8: Licensing**
- Keygen integration
- License validation flow
- Trial period implementation
- Activation UI

**Week 9: Polish & Testing**
- UI/UX refinement
- Bug fixing
- Beta testing
- Documentation

**Week 10: Launch Prep**
- Code signing
- Notarization
- Website/payment setup
- Launch!

**Deliverables:**
- Functional MVP with all P0 features
- Beta testing group (20-50 users)
- Launch-ready application

### Phase 2: Enhancements (4-6 weeks post-launch)

**Features:**
- Voice commands
- Transcription history
- Advanced settings
- Performance improvements
- Bug fixes from user feedback

### Phase 3: Advanced Features (TBD)

**Potential Features:**
- Custom vocabulary training
- Integration with popular apps (Notion, Obsidian, etc.)
- Team licenses
- API for developers
- iOS companion app

---

## 10. Success Metrics

### 10.1 Launch Goals (First 3 Months)

| Metric | Target |
|--------|--------|
| Total Downloads | 5,000 |
| Trial Conversions | 10% (500 purchases) |
| Active Users (MAU) | 2,000 |
| Average Session Length | 5+ minutes |
| App Store Rating | 4.5+ stars |
| Crash-Free Sessions | >99.5% |

### 10.2 User Engagement Metrics

- Daily Active Users (DAU)
- Transcriptions per user per day
- Average transcription length
- Model preference distribution
- Feature adoption rates

### 10.3 Business Metrics

- Customer Acquisition Cost (CAC)
- Lifetime Value (LTV)
- Trial-to-paid conversion rate
- Refund rate (<5% target)
- Support ticket volume

---

## 11. Risks & Mitigation

### 11.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Poor transcription accuracy | High | Medium | Extensive testing, model tuning, clear audio requirements |
| Performance issues on Intel Macs | Medium | Medium | Optimize whisper.cpp, offer Fast model as default |
| Accessibility API limitations | High | Low | Fallback to clipboard insertion |
| Apple policy changes | High | Low | Monitor developer guidelines, maintain fallback approaches |

### 11.2 Market Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Competitive response (price wars) | Medium | Medium | Focus on unique value (privacy, speed) |
| Apple adds better built-in dictation | High | Medium | Differentiate on advanced features, privacy |
| Low conversion rates | High | Medium | Strong trial experience, clear value proposition |
| Negative reviews | Medium | Medium | Robust beta testing, excellent support |

### 11.3 Operational Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| License server downtime | High | Low | Offline grace period, status page |
| Support volume overwhelming | Medium | Low | Comprehensive docs, FAQ, automated responses |
| Payment fraud | Low | Low | Use established payment processors with fraud detection |

---

## 12. Open Questions

1. **Model Hosting:** Host models ourselves or download from Hugging Face?
   - **Recommendation:** Self-host to ensure availability and consistency

2. **Analytics:** Include crash reporting and usage analytics?
   - **Recommendation:** Opt-in only, use privacy-focused tool (TelemetryDeck)

3. **Updates:** Auto-update mechanism?
   - **Recommendation:** Use Sparkle framework for seamless updates

4. **Support:** What support channels to offer?
   - **Recommendation:** Email + public GitHub discussions for first year

5. **Refund Policy:** How generous?
   - **Recommendation:** 30-day money-back guarantee (builds trust)

---

## 13. Appendices

### A. Competitive Feature Matrix

| Feature | EchoTune | SuperWhisper | MacWhisper | Voice Type | Apple Dictation |
|---------|----------|--------------|------------|------------|-----------------|
| Real-time dictation | ✓ | ✓ | ✗ | ✓ | ✓ |
| 100% Local | ✓ | ✓ | ✓ | ✓ | ✗ |
| Global shortcut | ✓ | ✓ | ✗ | ✓ | ✓ |
| Multiple models | ✓ | ✓ | ✓ | ✓ | ✗ |
| One-time purchase | ✓ | ✗ | ✓ | ✓ | ✓ |
| Launch at startup | ✓ | ✓ | ✗ | ✓ | N/A |
| Voice commands | ✓ (P2) | ✓ | ✗ | ✗ | Limited |
| Price | $29.99 | $10/mo | $20-30 | $15 | Free |

### B. Technical References

- whisper.cpp: https://github.com/ggerganov/whisper.cpp
- MLX Whisper: https://github.com/ml-explore/mlx-examples/tree/main/whisper
- KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts
- Keygen: https://keygen.sh
- ServiceManagement docs: https://developer.apple.com/documentation/servicemanagement

### C. Design Mockups
*(To be created in design phase)*

### D. Glossary

- **LLM:** Large Language Model
- **Whisper:** OpenAI's speech recognition model
- **STT:** Speech-to-Text
- **RTF:** Real-Time Factor (processing speed vs. audio length)
- **DAU/MAU:** Daily/Monthly Active Users
- **CAC:** Customer Acquisition Cost
- **LTV:** Lifetime Value

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Oct 25, 2025 | Initial | First comprehensive PRD |

---

**Next Steps:**
1. Review and approve PRD
2. Create detailed technical design document
3. Set up development environment
4. Begin Phase 1 development
5. Establish beta testing program
