# EchoTune Troubleshooting Guide

Complete troubleshooting guide for common issues with EchoTune.

---

## 📋 Quick Diagnosis

**Is your issue:**
- [Recording not working?](#-recording-issues)
- [Text not appearing?](#-text-insertion-issues)
- [Poor accuracy?](#-accuracy-issues)
- [App crashing?](#-crashes--stability)
- [Performance problems?](#-performance-issues)
- [License problems?](#-license--activation-issues)
- [Permission issues?](#-permission-issues)

---

## 🎤 Recording Issues

### Problem: Can't Start Recording

**Symptom:** Pressing ⌘⇧D does nothing, or error message appears.

**Solutions:**

1. **Check microphone permission**
   ```
   System Settings → Privacy & Security → Microphone
   → Ensure EchoTune is ON
   ```

2. **Verify keyboard shortcut**
   ```
   EchoTune Settings → Shortcuts
   → Confirm shortcut is set to ⌘⇧D
   → Try changing to different shortcut
   ```

3. **Check if another app uses same shortcut**
   ```
   System Settings → Keyboard → Keyboard Shortcuts
   → Look for conflicts
   → Disable conflicting shortcuts
   ```

4. **Restart EchoTune**
   ```
   ⌘Q to quit
   Reopen from Applications
   ```

### Problem: No Audio Being Captured

**Symptom:** Recording starts but waveform is flat, no transcription produced.

**Solutions:**

1. **Check microphone is selected**
   ```
   EchoTune Settings → General → Input Device
   → Select correct microphone
   ```

2. **Test microphone in other apps**
   ```
   Open Voice Memos
   Record something
   If doesn't work → microphone hardware issue
   ```

3. **Check system input volume**
   ```
   System Settings → Sound → Input
   → Adjust input volume slider
   → Speak and watch input level meter
   ```

4. **Check microphone isn't muted**
   - Some mics have physical mute buttons
   - Check headset controls
   - Check Mac's mic mute (if equipped)

5. **Try different microphone**
   ```
   Use built-in Mac mic
   Or try USB headset
   Or Bluetooth headset
   ```

### Problem: Recording Button Grayed Out

**Symptom:** Can't click record button in app.

**Solutions:**

1. **AI model not loaded**
   ```
   Settings → AI Models
   → Select a model
   → Wait for model to download/load
   ```

2. **Trial expired**
   ```
   Check trial status in footer
   If expired → Purchase or enter license key
   ```

3. **Permissions not granted**
   ```
   Check both Microphone and Accessibility
   Grant both permissions
   Restart app
   ```

---

## ✍️ Text Insertion Issues

### Problem: Text Not Appearing Anywhere

**Symptom:** Recording completes but text doesn't appear in any app.

**Solutions:**

1. **Check Accessibility permission** ⚠️ Most common issue
   ```
   System Settings → Privacy & Security → Accessibility
   → Ensure EchoTune is ON
   → IMPORTANT: Quit and restart EchoTune after enabling!
   ```

2. **Verify cursor is in text field**
   ```
   Click in text field first
   Then start recording
   ```

3. **Check insertion method**
   ```
   Settings → Behavior → Text Insertion
   → Try "Type" vs "Paste"
   → Type = simulates keyboard
   → Paste = uses clipboard
   ```

4. **Test in simple app first**
   ```
   Open TextEdit
   Click in document
   Try recording
   If works → other app may be blocking input
   ```

### Problem: Text Appears in Wrong App

**Symptom:** Text inserted into different app than expected.

**Solution:**

- **Focus issue**
  ```
  Click in destination app/field BEFORE recording
  Wait 1 second for focus to register
  Then press ⌘⇧D to record
  ```

### Problem: Text Has Weird Formatting

**Symptom:** Extra spaces, wrong capitalization, or strange characters.

**Solutions:**

1. **Check language settings**
   ```
   Settings → AI Models → Language
   → Ensure correct language selected
   ```

2. **Disable auto-formatting in destination app**
   ```
   Some apps auto-correct as you type
   Disable auto-correct temporarily
   ```

3. **Try paste instead of type**
   ```
   Settings → Behavior → Text Insertion → Paste
   ```

### Problem: Text Only Works in Some Apps

**Symptom:** Works in TextEdit but not in [specific app].

**Cause:** Some apps block programmatic text insertion for security.

**Workaround:**
```
Settings → Behavior → Text Insertion → Paste
This uses clipboard which works in more apps
```

**Apps with known issues:**
- Password managers
- Banking apps
- Some games
- Protected PDF forms

---

## 🎯 Accuracy Issues

### Problem: Transcription is Gibberish

**Symptom:** Text makes no sense, random words, incorrect language.

**Solutions:**

1. **Check selected language**
   ```
   Settings → AI Models → Language
   → Must match language you're speaking
   ```

2. **Verify microphone quality**
   ```
   Test in Voice Memos
   Play back to check audio quality
   If audio is garbled → mic hardware issue
   ```

3. **Check for background noise**
   ```
   Record in quiet environment
   Close windows
   Turn off fans/AC
   ```

4. **Try larger AI model**
   ```
   Settings → AI Models
   → Switch from Tiny to Base or Small
   → Larger models are more accurate
   ```

### Problem: Missing Words or Cuts Off

**Symptom:** First/last few words missing, or gaps in transcription.

**Solutions:**

1. **Pause before and after speaking**
   ```
   Press ⌘⇧D
   Wait 1 second
   Start speaking
   Finish speaking
   Wait 1 second
   Press ⌘⇧D again
   ```

2. **Adjust silence detection**
   ```
   Settings → Recording → Silence Detection
   → Increase threshold
   ```

3. **Speak more slowly**
   - Rushing can cause missed words
   - Normal speaking pace is best

### Problem: Wrong Words but Close

**Symptom:** "Their" instead of "there", "to" instead of "too".

**Solution:**

1. **Use larger model**
   ```
   Whisper Medium has better context understanding
   Or try Deepgram Nova (cloud)
   ```

2. **Enunciate clearly**
   - Pronounce word endings
   - Don't mumble

3. **Add context**
   - Speak in full sentences
   - AI uses context to disambiguate

---

## 💥 Crashes & Stability

### Problem: App Crashes on Launch

**Symptom:** App opens and immediately closes, or shows error and quits.

**Solutions:**

1. **Launch in safe mode**
   ```
   Hold Shift while opening EchoTune
   This skips loading certain components
   ```

2. **Reset preferences**
   ```bash
   # In Terminal:
   rm ~/Library/Preferences/com.echotune.EchoTune.plist
   rm -rf ~/Library/Application\ Support/EchoTune
   ```
   Then restart EchoTune.

3. **Check Console for errors**
   ```
   Open Console.app
   Filter for "EchoTune"
   Look for error messages
   Email support@echotune.app with error details
   ```

4. **Reinstall app**
   ```
   Delete EchoTune from Applications
   Empty Trash
   Redownload and install
   ```

5. **Check macOS version**
   ```
   EchoTune requires macOS 14+
    → About This Mac to check version
   If older → Upgrade macOS
   ```

### Problem: Crashes During Recording

**Symptom:** App quits while recording or transcribing.

**Solutions:**

1. **Check available RAM**
   ```
   Activity Monitor → Memory tab
   If memory pressure is red → Close other apps
   Larger AI models need more RAM
   ```

2. **Try smaller AI model**
   ```
   Switch from Medium to Small or Tiny
   Smaller models use less memory
   ```

3. **Check storage space**
   ```
   Ensure at least 5GB free disk space
    → About This Mac → Storage
   ```

4. **Update macOS**
   ```
   Software Update
   Install available updates
   Restart Mac
   ```

### Problem: App Freezes

**Symptom:** App stops responding, beachball cursor.

**Solutions:**

1. **Wait for AI model to load**
   - First transcription takes 10-15 seconds
   - AI model loading into memory
   - Subsequent transcriptions are instant

2. **Force quit and restart**
   ```
   ⌘⌥Esc → Select EchoTune → Force Quit
   Reopen from Applications
   ```

3. **Check Activity Monitor**
   ```
   Look for high CPU usage
   If "EchoTuneHelper" at 100% → AI processing
   Wait for completion
   ```

---

## 🐌 Performance Issues

### Problem: Slow Transcription

**Symptom:** Takes a long time to produce text after recording.

**Solutions:**

1. **First time is always slower**
   - AI model loads into memory (10-15 sec)
   - Subsequent transcriptions are fast

2. **Use smaller model**
   ```
   Tiny: ~1-2 seconds
   Base: ~2-4 seconds
   Small: ~5-10 seconds
   Medium: ~15-30 seconds
   ```

3. **Switch to cloud model**
   ```
   Groq Whisper: ~0.5-2 seconds (ultra fast!)
   Requires internet and API key
   ```

4. **Check CPU usage**
   ```
   Activity Monitor → CPU tab
   Close other CPU-intensive apps
   ```

5. **Restart Mac**
   - Fresh start often helps
   - Clears memory leaks from other apps

### Problem: App Uses Too Much RAM

**Symptom:** High memory usage shown in Activity Monitor.

**Normal memory usage:**
- App idle: 100-200MB
- Whisper Tiny loaded: 500-800MB
- Whisper Base loaded: 1-1.5GB
- Whisper Small loaded: 2-3GB
- Whisper Medium loaded: 4-5GB

**Solutions:**

1. **Use smaller model**
   ```
   Switch from Medium to Small or Base
   ```

2. **Quit and relaunch regularly**
   ```
   ⌘Q after extended use
   Clears cached data
   ```

3. **Close other apps**
   - Free up system memory
   - Give EchoTune more resources

### Problem: High CPU Usage

**Symptom:** Fans spinning, Mac getting hot, CPU at 100%.

**This is normal when:**
- First-time loading AI model
- Actively transcribing audio
- Processing long recordings

**Not normal if:**
- CPU stays high when idle
- Happens with cloud models (shouldn't use much CPU)

**Solutions:**

1. **Use cloud model (Groq)**
   - Offloads processing to server
   - Your Mac just sends/receives data

2. **Wait for transcription to complete**
   - CPU spike is temporary
   - Should return to normal after

3. **Check for runaway process**
   ```
   Activity Monitor
   If "EchoTuneHelper" using CPU when idle → Bug
   Force quit helper process
   Email support@echotune.app
   ```

---

## 🔑 License & Activation Issues

### Problem: "Invalid License Key"

**Symptom:** Error when entering license key.

**Solutions:**

1. **Check format**
   ```
   Correct format: XXXXX-XXXXX-XXXXX-XXXXX
   Must include dashes
   All uppercase
   No spaces
   ```

2. **Copy-paste from email**
   - Don't type manually
   - Avoid typos
   - Check for extra spaces

3. **Verify purchase**
   - Check email receipt
   - Ensure license key is for EchoTune
   - Not an order confirmation

### Problem: "Activation Limit Exceeded"

**Symptom:** Can't activate on new device.

**Cause:** License already activated on maximum number of devices.

**Solutions:**

1. **Deactivate on another device**
   ```
   On old Mac:
   Settings → License → Deactivate License
   Then try again on new Mac
   ```

2. **Check activation count**
   - Single license: 1 device max
   - 3-device: 3 devices max
   - etc.

3. **Contact support**
   ```
   If you don't have access to old device
   Email support@echotune.app
   Include license key (first and last segment)
   We can reset activations
   ```

### Problem: "License Expired"

**Symptom:** Error message says license has expired.

**Cause:** Time-limited license expired (rare, most licenses are lifetime).

**Solution:**

1. **Check license details**
   - Most licenses are lifetime
   - Some promotional licenses may have expiry

2. **Contact support**
   ```
   Email support@echotune.app with:
   - License key
   - Purchase date
   - Order number
   ```

### Problem: Lost License Key

**Solution:**

**App Store purchase:**
- No license key needed
- Restore purchases: Settings → Restore Purchases

**Direct purchase:**
1. Check email for receipt from Polar
2. Search for "EchoTune" or "License"
3. If not found → Email support@echotune.app with:
   - Purchase email address
   - Approximate purchase date
   - Transaction/order ID if available

---

## 🔐 Permission Issues

### Problem: Microphone Permission Stuck

**Symptom:** Can't grant microphone permission, greyed out, or reverts.

**Solutions:**

1. **Reset TCC database** (⚠️ Advanced)
   ```bash
   tccutil reset Microphone com.echotune.EchoTune
   ```
   Then restart EchoTune and grant again.

2. **Check Screen Time restrictions**
   ```
   System Settings → Screen Time → Content & Privacy
   → Ensure app isn't blocked
   ```

3. **Restart Mac**
   - Permissions system can get stuck
   - Restart clears it

### Problem: Accessibility Permission Not Detected

**Symptom:** EchoTune says accessibility not granted, but it's ON in System Settings.

**Solution:** ⚠️ **MUST RESTART APP AFTER GRANTING**

```
1. Grant permission in System Settings
2. Completely quit EchoTune (⌘Q)
3. Wait 3 seconds
4. Reopen EchoTune
5. Check permission status again
```

If still not working:
```bash
# Reset accessibility TCC
tccutil reset Accessibility com.echotune.EchoTune
```

Then grant again and restart.

### Problem: Permissions Keep Getting Revoked

**Symptom:** Have to re-grant permissions frequently.

**Causes:**
- Installing updates
- Changing app location
- macOS security updates

**Solutions:**

1. **Keep app in Applications folder**
   ```
   Don't run from Downloads or Desktop
   Move to /Applications/
   ```

2. **Don't move app after granting permissions**
   - Moving app revokes permissions
   - Reinstall if you moved it

3. **Check for macOS security updates**
   - Updates can reset TCC database
   - Re-grant after major updates

---

## 🌐 Cloud Models Issues

### Problem: "API Key Invalid"

**Solutions:**

1. **Check key format**
   - No spaces
   - Copy-paste from provider dashboard
   - Don't type manually

2. **Verify key is for correct service**
   - Groq key for Groq
   - Deepgram key for Deepgram
   - Not interchangeable

3. **Check key permissions**
   - Key must have "transcription" permissions
   - Some keys are scoped to specific APIs

4. **Regenerate key**
   - Generate new key in provider dashboard
   - Delete old key
   - Enter new key in EchoTune

### Problem: "API Rate Limit Exceeded"

**Symptom:** Error message about too many requests.

**Solutions:**

1. **Wait and try again**
   - Rate limits reset after time period
   - Usually 1 minute to 1 hour

2. **Upgrade API plan**
   - Free tiers have low limits
   - Paid plans have higher limits

3. **Switch to local model temporarily**
   - Use Whisper while waiting
   - No rate limits

### Problem: Cloud Transcription Fails

**Symptoms:** Errors, no results, timeout.

**Solutions:**

1. **Check internet connection**
   ```
   Open Safari
   Visit google.com
   If doesn't load → internet issue
   ```

2. **Check provider status**
   - status.groq.com
   - status.deepgram.com
   - May be temporary outage

3. **Try different cloud model**
   - If Groq fails, try Deepgram
   - Or use local model

4. **Check API credits/quota**
   - Log into provider dashboard
   - Verify you have credits remaining
   - Add credits if needed

---

## 🔧 Advanced Troubleshooting

### Collecting Diagnostic Information

**For support requests, include:**

1. **macOS version**
   ```
    → About This Mac
   ```

2. **EchoTune version**
   ```
   EchoTune → About EchoTune
   ```

3. **Console logs**
   ```
   Open Console.app
   Filter for "EchoTune"
   Copy recent error messages
   ```

4. **System info**
   ```bash
   system_profiler SPSoftwareDataType SPHardwareDataType
   ```

### Resetting EchoTune Completely

**Nuclear option - erases all settings and data:**

```bash
# Quit EchoTune first
osascript -e 'quit app "EchoTune"'

# Delete all EchoTune data
rm ~/Library/Preferences/com.echotune.EchoTune.plist
rm -rf ~/Library/Application\ Support/EchoTune
rm -rf ~/Library/Caches/com.echotune.EchoTune
rm -rf ~/Library/Saved\ Application\ State/com.echotune.EchoTune.savedState

# Reset TCC permissions
tccutil reset Microphone com.echotune.EchoTune
tccutil reset Accessibility com.echotune.EchoTune

# Restart Mac
sudo reboot
```

Then reinstall EchoTune fresh.

### Checking File Permissions

**If EchoTune can't write files:**

```bash
# Check Application Support permissions
ls -la ~/Library/Application\ Support/ | grep EchoTune

# Should show: drwx------ (owner can read/write)

# Fix if needed:
chmod 700 ~/Library/Application\ Support/EchoTune
```

---

## 📞 When to Contact Support

Contact support@echotune.app if:

- None of the above solutions work
- App consistently crashes
- Data loss or corruption
- Billing/license issues
- Feature requests
- Bug reports

**Include in your email:**
- macOS version
- EchoTune version
- Detailed description of issue
- Steps to reproduce
- Screenshots/screen recording
- Console logs (if crash)

**Response time:** Within 48 hours (Monday-Friday)

---

## 🔄 Keeping EchoTune Updated

Many issues are fixed in updates. Always use latest version:

**App Store version:**
```
App Store → Updates tab
Install any EchoTune updates
```

**Direct purchase:**
- Check echotune.app/download
- Download latest version
- Or enable auto-update in settings (if available)

---

## ✅ Quick Fixes Checklist

Before contacting support, try these:

- [ ] Restart EchoTune
- [ ] Restart Mac
- [ ] Check all permissions are granted
- [ ] Update to latest version
- [ ] Try different AI model
- [ ] Test in simple app (TextEdit)
- [ ] Check internet connection (for cloud models)
- [ ] Review Console.app for errors
- [ ] Check available RAM and storage

---

**Still stuck?** Email support@echotune.app - we're here to help! 🤝

Last Updated: November 2, 2025
