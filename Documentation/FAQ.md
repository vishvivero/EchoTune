# EchoTune - Frequently Asked Questions (FAQ)

Common questions and answers about EchoTune.

---

## 📱 General Questions

### What is EchoTune?

EchoTune is an AI-powered voice-to-text transcription app for Mac. Press a keyboard shortcut anywhere on your Mac, speak naturally, and watch your words appear in any app—no copying or pasting needed.

### How is EchoTune different from macOS built-in dictation?

| Feature | EchoTune | macOS Dictation |
|---------|----------|-----------------|
| AI Models | Multiple (Whisper, Groq, Deepgram) | Limited |
| Offline | ✅ Yes | Limited |
| Accuracy | Higher | Good |
| Languages | 99+ | ~50 |
| Customization | Full control | Limited |
| Privacy | Local processing | Sent to Apple |
| Session history | ✅ Yes | ❌ No |
| Statistics | ✅ Yes | ❌ No |

### What are the system requirements?

- **macOS**: 14 (Sonoma) or later
- **Processor**: Apple Silicon or Intel
- **RAM**: 8GB minimum (16GB recommended for local models)
- **Storage**: 2GB free space (for AI models)
- **Microphone**: Built-in or external
- **Internet**: Optional (required for cloud models only)

### Does EchoTune work offline?

**Yes!** Local AI models (Whisper) work completely offline. No internet connection needed.

Cloud models (Groq, Deepgram) require internet.

---

## 💰 Pricing & Licensing

### How much does EchoTune cost?

EchoTune is open source (GPL-3.0) — you can build it yourself for free.

A signed, notarized build with a license key is **$10 (one-time)**, which
supports development and saves you building from source.

### Is there a free trial?

**Yes!** A 7-day free trial with full access to all features. No credit card
required.

### Is it a subscription?

**No!** One-time purchase. Pay once, use forever.

### Do I need to pay for AI models?

**Local models (Whisper):** Free, included with purchase

**Cloud models (Groq, Deepgram):** Optional, you provide your own API key
- Groq: Free tier available, then pay-as-you-go
- Deepgram: Free credits included, then pay-as-you-go

### What's the refund policy?

**App Store purchases:** Apple's standard 14-day refund policy

**Direct purchases:** 14-day money-back guarantee, no questions asked
- Contact: support@echotune.app

### Can I use EchoTune on multiple Macs?

A license activates EchoTune on your Mac. To move to a new machine, deactivate
on the old one first, then activate on the new one.

---

## 🔒 Privacy & Security

### Is my voice data stored?

**No.** Audio recordings are NOT stored anywhere. They're processed and immediately discarded after transcription.

### Where is my data processed?

**Local models:** Everything happens on your Mac. Nothing leaves your device.

**Cloud models:** Audio is sent to the provider (Groq or Deepgram) for processing. You control when this happens by choosing cloud models.

### Does EchoTune collect analytics?

Only if you opt in. Crash reporting is **off by default** and carries no
personally identifying information. Usage statistics (word count, session
count) are stored locally on your Mac only.

### Is EchoTune GDPR compliant?

**Yes.** We collect minimal data, process locally by default, and give you full control over your information.

### Can I export my data?

**Yes.** Settings → Privacy → Export Data

Exports all your transcriptions and statistics in JSON format.

### What permissions does EchoTune need?

1. **Microphone:** To record your voice
2. **Accessibility:** To insert text into other apps

Both are required for EchoTune to work. You control when recordings happen.

---

## 🎤 Recording & Transcription

### What languages are supported?

99+ languages including:
- English, Spanish, French, German, Italian, Portuguese
- Dutch, Russian, Polish, Turkish, Greek, Czech
- Arabic, Hebrew, Persian, Urdu
- Hindi, Bengali, Tamil, Telugu, Punjabi
- Chinese (Mandarin, Cantonese), Japanese, Korean
- Vietnamese, Thai, Indonesian, Malay
- And many more!

### Does it work with my accent?

**Yes.** Whisper AI is trained on diverse accents worldwide. It handles:
- British, American, Australian, Canadian English
- Regional accents (Southern US, Scottish, Irish, etc.)
- Non-native speakers
- Technical and professional terminology

For best results, use larger models (Small or Medium) or cloud models.

### Can I use it for dictating code?

**Yes!** Enable "Code Mode" in settings for better programming language support.

Example:
```
"function add numbers opening parenthesis a comma b closing parenthesis
opening brace return a plus b closing brace"
```

Produces:
```javascript
function addNumbers(a, b) {
    return a + b;
}
```

### How do I add punctuation?

**Method 1: Say it**
- "period" → .
- "comma" → ,
- "question mark" → ?
- "exclamation point" → !
- "new line" → ↵
- "new paragraph" → ↵↵

**Method 2: Enable auto-punctuation**
- Settings → AI Models → Auto Punctuation: ON
- AI adds punctuation automatically based on context

### Does it work in all apps?

**Works in:**
- ✅ Email (Mail, Outlook, Gmail in browser)
- ✅ Notes, documents (Notes, Pages, Word)
- ✅ Code editors (VSCode, Xcode, Sublime)
- ✅ Chat apps (Slack, Messages, Discord, Teams)
- ✅ Browsers (Chrome, Safari, Firefox)
- ✅ Any text field or text editor

**May not work in:**
- ❌ Some games
- ❌ Protected/encrypted fields
- ❌ Apps that block programmatic input

### Can I transcribe audio files?

**Currently:** EchoTune is designed for live dictation.

**Coming soon:** Upload audio/video files for transcription (planned for v2.0).

---

## 🤖 AI Models

### Which AI model should I use?

**Depends on your priority:**

**For privacy:** Whisper Base or Small (local)
**For speed:** Groq Whisper (cloud)
**For accuracy:** Whisper Medium (local) or Deepgram Nova (cloud)
**Balanced:** Whisper Base (local)

### Why are cloud models faster?

Cloud models run on powerful servers with specialized hardware (GPUs). Your Mac processes audio locally, which is more private but slower.

### Do I need an API key?

**For local models (Whisper):** No API key needed

**For cloud models:** Yes, you provide your own API key
- Groq: console.groq.com
- Deepgram: console.deepgram.com

Both offer free tiers to get started.

### How much do cloud API keys cost?

**Groq (as of 2025):**
- Free tier: 14,400 requests/day
- After that: Pay-as-you-go, ~$0.05-0.10 per hour of audio

**Deepgram (as of 2025):**
- $200 free credits
- After that: ~$0.0125 per minute of audio

Check provider websites for current pricing.

### Can I switch models mid-transcription?

No, choose your model before starting a recording. You can switch between recordings.

---

## 🛠️ Technical Questions

### Why does the first transcription take longer?

The AI model loads into memory on first use. This takes 10-15 seconds. Subsequent transcriptions are instant.

### How much RAM do local models use?

- **Whisper Tiny:** ~500MB
- **Whisper Base:** ~1GB
- **Whisper Small:** ~2GB
- **Whisper Medium:** ~4GB

### Can I use EchoTune on Mac M1/M2/M3?

**Yes!** EchoTune is optimized for Apple Silicon and runs even faster on M-series chips.

### Does it work on Intel Macs?

**Yes!** EchoTune supports both Apple Silicon and Intel Macs.

Older Intel Macs may be slower with larger models. Use Tiny or Base for better performance.

### Why isn't text appearing in some apps?

Some apps block programmatic text insertion for security. Try:
1. Use "Paste" instead of "Insert" (Settings → Behavior)
2. Or manually paste from clipboard

### Can I customize the keyboard shortcut?

**Yes!** Settings → Shortcuts → Start/Stop Recording → Click → Press your preferred keys

---

## 🔧 Troubleshooting

### EchoTune won't launch

1. Check macOS version (needs 14+)
2. Restart Mac
3. Reinstall EchoTune
4. Check Console.app for errors

### Microphone permission denied

1. System Settings → Privacy & Security → Microphone
2. Find EchoTune in list
3. Toggle ON
4. Restart EchoTune

### Accessibility permission not working

**Common issue:** Must restart EchoTune after granting permission

**Fix:**
1. Grant permission in System Settings
2. Quit EchoTune completely (⌘Q)
3. Reopen EchoTune
4. Test recording

### Poor transcription accuracy

**Try:**
1. Speak more clearly and slowly
2. Use larger model (Small or Medium)
3. Switch to cloud model
4. Check microphone input levels
5. Reduce background noise
6. Select correct language in settings

### "License activation failed"

**Check:**
1. License key entered correctly (including dashes)
2. Internet connection active
3. License not already used on max devices
4. License not expired

**Still not working?**
Email support@echotune.app with your license key (first and last segments only).

### App crashes on launch

1. Hold Shift while launching (safe mode)
2. Reset settings: Settings → Advanced → Reset to Defaults
3. Delete preferences:
   ```bash
   rm ~/Library/Preferences/com.echotune.EchoTune.plist
   ```
4. Reinstall app

---

## 🚀 Features & Roadmap

### What features are planned for future versions?

**Coming in v1.x:**
- More local AI models
- Better code dictation
- Templates and macros
- Custom vocabulary
- Speaker diarization (multi-speaker detection)

**Planned for v2.0:**
- Audio file transcription
- Real-time translation
- Voice commands
- iOS companion app
- Team features

### Can I suggest features?

**Yes!** We love feedback.
- Email: support@echotune.app
- Or vote on roadmap: echotune.app/roadmap

### Is there a Windows or Linux version?

Currently macOS only. Windows support is under consideration based on demand.

---

## 💼 Business & Teams

### Can I use EchoTune for my business?

**Yes!** Commercial use is included in all licenses.

For teams of 10+ people, consider the 10-device pack or contact us for volume licensing.

### Is there a team/enterprise plan?

Currently, purchase multi-device packs (3, 5, or 10 devices).

Custom enterprise plans available on request: support@echotune.app

### Can I get an invoice?

**App Store purchases:** Request from Apple

**Direct purchases:** Invoices emailed automatically via Polar

Need custom invoice format? Contact support@echotune.app

### Do you offer educational discounts?

Currently no educational pricing, but we're considering it. Contact us for bulk educational purchases.

---

## 📞 Support & Community

### How do I get support?

**Email:** support@echotune.app
**Response time:** Within 48 hours
**Hours:** Monday-Friday, 9am-5pm EST

### Is there a community?

**Discord:** discord.gg/echotune (coming soon)
**Reddit:** r/echotune (coming soon)
**Twitter:** @echotuneapp

### How do I report a bug?

Email support@echotune.app with:
- macOS version
- EchoTune version (Help → About)
- Steps to reproduce
- Screenshots/screen recording if possible

### Where can I leave a review?

**App Store version:** Rate in App Store
**Direct purchase:** Leave review on echotune.app

We appreciate honest feedback! 🙏

---

## 🎁 Referral Program (Direct Purchase Only)

### How does the referral program work?

1. Settings → Referral
2. Copy your unique link
3. Share with friends/colleagues
4. Earn 20% commission on each sale
5. Get paid via PayPal or credit

### When do I get paid?

Commissions paid monthly, minimum $50 threshold.

### Can App Store users use referrals?

No, referral program is only for direct purchases (due to Apple's policies).

---

## 📚 Additional Resources

### Where can I find more help?

- **User Guide:** Full documentation at echotune.app/docs
- **Video Tutorials:** echotune.app/tutorials
- **Blog:** echotune.app/blog
- **Status Page:** status.echotune.app

### How do I stay updated?

- **Email Newsletter:** Subscribe at echotune.app
- **Twitter:** @echotuneapp
- **Product Updates:** Announced in app

---

## ❓ Still Have Questions?

Can't find your answer here? Contact us:

**Email:** support@echotune.app
**Website:** echotune.app/support

We typically respond within 48 hours.

---

**Last Updated:** November 2, 2025
**Version:** 1.0

For the most up-to-date FAQ, visit: echotune.app/faq
