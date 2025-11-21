# EchoTune Build Scripts

Automated build scripts for creating both App Store and Direct Sale versions of EchoTune.

---

## 📋 Available Scripts

### `build_all.sh` - Master Build Script (Recommended)
Interactive menu-driven script to build both versions.

```bash
./Scripts/build_all.sh
```

**Features:**
- Interactive menu
- Build App Store version
- Build Direct Sale version
- Build both versions
- Clean all builds
- Verify build configurations

### `build_app_store.sh` - App Store Build
Builds the App Store version with StoreKit IAP.

```bash
./Scripts/build_app_store.sh
```

**Produces:**
- Archive: `./build/archives/EchoTune_AppStore_[timestamp].xcarchive`
- Export: `./build/exports/AppStore/EchoTune.app`

**Configuration:**
- Uses `Release` configuration
- Includes `-D APPSTORE` flag
- Code signed with Developer ID
- Ready for App Store Connect upload

### `build_direct_sale.sh` - Direct Sale Build
Builds the Direct Sale version with license keys.

```bash
./Scripts/build_direct_sale.sh
```

**Produces:**
- Archive: `./build/archives/EchoTune_Direct_[timestamp].xcarchive`
- Export: `./build/exports/Direct/EchoTune.app`
- Optional DMG: `./build/dmg/EchoTune_[date].dmg`

**Configuration:**
- Uses `Debug` configuration (or `Release-Direct`)
- No `APPSTORE` flag
- Code signed with Developer ID
- Optional notarization
- Optional DMG creation

---

## 🚀 Quick Start

### First Time Setup

1. Make scripts executable (already done):
```bash
chmod +x Scripts/*.sh
```

2. Edit export options:
```bash
# Edit and add your Team ID
open Scripts/ExportOptions_AppStore.plist
open Scripts/ExportOptions_Direct.plist
```

3. Run master build script:
```bash
./Scripts/build_all.sh
```

---

## 📦 Build Output Structure

```
./build/
├── archives/
│   ├── EchoTune_AppStore_20250102_143022.xcarchive
│   └── EchoTune_Direct_20250102_143500.xcarchive
├── exports/
│   ├── AppStore/
│   │   └── EchoTune.app
│   └── Direct/
│       ├── EchoTune.app
│       └── EchoTune.zip (for notarization)
└── dmg/
    └── EchoTune_20250102.dmg
```

---

## ⚙️ Prerequisites

### Required Tools

- **Xcode** (with Command Line Tools)
- **xcodebuild** (comes with Xcode)
- **codesign** (comes with Xcode)

### Optional Tools

- **xcpretty** - Pretty output formatting
```bash
gem install xcpretty
```

- **create-dmg** - Better DMG creation
```bash
brew install create-dmg
```

### Required Configuration

1. **Apple Developer Account** ($99/year)
2. **Developer ID Certificate** installed in Keychain
3. **Team ID** configured in export options

---

## 🔐 Code Signing & Notarization

### Code Signing

Scripts automatically sign with "Developer ID Application" certificate.

**Verify certificate is installed:**
```bash
security find-identity -v -p codesigning
```

**Should show:**
```
1) ABC123... "Developer ID Application: Your Name (TEAM_ID)"
```

### Notarization

Direct Sale build script offers optional notarization.

**Requirements:**
- Apple Developer account
- App-specific password generated at appleid.apple.com

**Manual notarization:**
```bash
# Create ZIP
ditto -c -k --keepParent ./build/exports/Direct/EchoTune.app ./EchoTune.zip

# Submit for notarization
xcrun notarytool submit ./EchoTune.zip \
    --apple-id "your@email.com" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --team-id "TEAMID" \
    --wait

# Staple ticket
xcrun stapler staple ./build/exports/Direct/EchoTune.app
```

---

## 🧪 Testing Builds

### Test App Store Build

```bash
# Build
./Scripts/build_app_store.sh

# Run
open ./build/exports/AppStore/EchoTune.app

# Verify:
# - No referral banner
# - Purchase sheet appears
# - No license key UI
# - StoreKit present
```

### Test Direct Sale Build

```bash
# Build
./Scripts/build_direct_sale.sh

# Run
open ./build/exports/Direct/EchoTune.app

# Verify:
# - Referral banner present
# - License entry available
# - No purchase sheet
# - No StoreKit code
```

---

## 🐛 Troubleshooting

### "Archive failed"

**Check:**
- Xcode is installed
- Command Line Tools are installed: `xcode-select --install`
- No compilation errors in project
- All dependencies resolved

### "Code signing failed"

**Check:**
- Developer ID certificate installed
- Certificate not expired
- Correct Team ID in export options

**List certificates:**
```bash
security find-identity -v -p codesigning
```

### "APPSTORE flag not set" or "should NOT be set"

**Fix:**
1. Open Xcode
2. Select target → Build Settings
3. Search "Other Swift Flags"
4. Ensure:
   - Release: Has `-D APPSTORE`
   - Debug: No `-D APPSTORE`

**Or run:**
```bash
./Scripts/build_all.sh
# Choose option 5: Verify build configurations
```

### "Export failed"

**Check:**
- Export options plist has correct Team ID
- Provisioning profiles are valid
- App entitlements are correct

**Update Team ID:**
```bash
# Edit these files
nano Scripts/ExportOptions_AppStore.plist
nano Scripts/ExportOptions_Direct.plist

# Replace YOUR_TEAM_ID with your actual Team ID
```

### "Notarization failed"

**Common causes:**
- Incorrect Apple ID or password
- App-specific password not generated
- Wrong Team ID
- App not properly signed

**Generate app-specific password:**
1. Go to appleid.apple.com
2. Sign in
3. Security → App-Specific Passwords
4. Generate new password
5. Use that in notarization command

---

## 📚 Advanced Usage

### Build Specific Configuration

```bash
# Build with custom configuration
xcodebuild archive \
    -project EchoTune.xcodeproj \
    -scheme EchoTune \
    -configuration "Release-Direct" \
    -archivePath ./custom.xcarchive
```

### Custom Build Variables

Edit scripts to customize:
```bash
# In build_app_store.sh or build_direct_sale.sh
CONFIGURATION="YourCustomConfig"
ARCHIVE_PATH="./custom/path/"
```

### Batch Building

```bash
# Build multiple versions in sequence
for version in AppStore Direct; do
    ./Scripts/build_${version,,}.sh
done
```

### CI/CD Integration

Scripts are designed to work in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Build App Store Version
  run: ./Scripts/build_app_store.sh
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
```

---

## 📝 Checklist Before Distribution

### App Store Version
- [ ] Built with Release configuration
- [ ] APPSTORE flag verified
- [ ] No license key UI
- [ ] StoreKit present
- [ ] Code signed
- [ ] Validated in Xcode Organizer
- [ ] Uploaded to App Store Connect

### Direct Sale Version
- [ ] Built with Debug/Release-Direct
- [ ] No APPSTORE flag
- [ ] License keys work
- [ ] Referral system present
- [ ] Code signed with Developer ID
- [ ] Notarized by Apple
- [ ] DMG created (optional)
- [ ] Tested on clean Mac

---

## 🎯 Common Workflows

### Daily Development Build
```bash
# Quick build for testing
xcodebuild -project EchoTune.xcodeproj \
    -scheme EchoTune \
    -configuration Debug \
    build
```

### Release Candidate Build
```bash
# Build both versions for testing
./Scripts/build_all.sh
# Choose option 3: Both versions
```

### Final Release Build
```bash
# 1. Build both versions
./Scripts/build_all.sh

# 2. Test thoroughly
open ./build/exports/AppStore/EchoTune.app
open ./build/exports/Direct/EchoTune.app

# 3. Upload App Store version
# (via Xcode Organizer or altool)

# 4. Notarize Direct version
# (if not done during build)

# 5. Create DMG and upload to website
```

---

## 🆘 Getting Help

**Build issues:**
1. Run verification: `./Scripts/build_all.sh` → Option 5
2. Check build logs in console
3. Clean and rebuild: `./Scripts/build_all.sh` → Option 4

**Configuration issues:**
- See: `BUILD_CONFIGURATION_GUIDE.md`

**Distribution issues:**
- App Store: `HYBRID_LAUNCH_STRATEGY.md`
- Direct Sale: `PHASED_IMPLEMENTATION_PLAN.md`

---

## ✅ Script Status

- ✅ `build_all.sh` - Tested and ready
- ✅ `build_app_store.sh` - Tested and ready
- ✅ `build_direct_sale.sh` - Tested and ready
- ✅ Export options templates created
- ✅ Error handling implemented
- ✅ Color-coded output
- ✅ Interactive prompts
- ✅ Validation checks

---

**Happy building! 🚀**

For questions or issues, see documentation in project root or contact support@echotune.app
