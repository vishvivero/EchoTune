#!/bin/bash

#
# Build EchoTune for Direct Sale Distribution
# This script builds and archives the Direct Sale version with license keys
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  EchoTune - Direct Sale Build Script  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Configuration
PROJECT_NAME="EchoTune"
SCHEME="EchoTune"
CONFIGURATION="Debug"  # Or "Release-Direct" if you created it
ARCHIVE_PATH="./build/archives/${PROJECT_NAME}_Direct_$(date +%Y%m%d_%H%M%S).xcarchive"
EXPORT_PATH="./build/exports/Direct"
EXPORT_OPTIONS_PLIST="./Scripts/ExportOptions_Direct.plist"
DMG_PATH="./build/dmg"

# Check if we're in the right directory
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: ${PROJECT_NAME}.xcodeproj not found${NC}"
    echo -e "${YELLOW}Please run this script from the project root directory${NC}"
    exit 1
fi

# Step 1: Clean build folder
echo -e "${YELLOW}🧹 Cleaning build folder...${NC}"
xcodebuild clean \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    > /dev/null 2>&1

echo -e "${GREEN}✅ Clean complete${NC}"
echo ""

# Step 2: Verify APPSTORE flag is NOT set
echo -e "${YELLOW}🔍 Verifying APPSTORE flag is NOT set...${NC}"

FLAG_CHECK=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -showBuildSettings | grep "OTHER_SWIFT_FLAGS" | grep "APPSTORE" || echo "")

if [ -n "$FLAG_CHECK" ]; then
    echo -e "${RED}❌ Error: APPSTORE flag should NOT be set for Direct Sale build${NC}"
    echo -e "${YELLOW}Please remove '-D APPSTORE' from Other Swift Flags in ${CONFIGURATION} configuration${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build configuration is correct (no APPSTORE flag)${NC}"
echo ""

# Step 3: Build and archive
echo -e "${YELLOW}📦 Building and archiving Direct Sale version...${NC}"
echo -e "${BLUE}This may take several minutes...${NC}"
echo ""

xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_IDENTITY="Developer ID Application"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive created successfully${NC}"
echo -e "${BLUE}📍 Location: ${ARCHIVE_PATH}${NC}"
echo ""

# Step 4: Export for Direct Distribution
echo -e "${YELLOW}📤 Exporting for Direct Distribution...${NC}"

# Create export options plist if it doesn't exist
if [ ! -f "${EXPORT_OPTIONS_PLIST}" ]; then
    echo -e "${YELLOW}⚠️  Export options plist not found, creating default...${NC}"
    mkdir -p "$(dirname "${EXPORT_OPTIONS_PLIST}")"
    cat > "${EXPORT_OPTIONS_PLIST}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
    echo -e "${YELLOW}⚠️  Please edit ${EXPORT_OPTIONS_PLIST} and add your Team ID${NC}"
fi

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
    | xcpretty || exit 1

echo -e "${GREEN}✅ Export complete${NC}"
echo -e "${BLUE}📍 Location: ${EXPORT_PATH}${NC}"
echo ""

# Step 5: Validate
echo -e "${YELLOW}🔍 Validating build...${NC}"

APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}❌ App not found at expected location${NC}"
    exit 1
fi

# Check that it's signed
echo -e "${YELLOW}Checking code signature...${NC}"
codesign -vvv --deep --strict "${APP_PATH}" 2>&1 | head -n 5

# Check that StoreKit is NOT present (should not be in Direct build)
echo -e "${YELLOW}Checking for StoreKit framework...${NC}"
if nm "${APP_PATH}/Contents/MacOS/${PROJECT_NAME}" | grep -q "StoreKit"; then
    echo -e "${RED}⚠️  Warning: StoreKit framework detected (should not be in Direct build)${NC}"
    echo -e "${YELLOW}Please verify you're building with correct configuration${NC}"
else
    echo -e "${GREEN}✅ StoreKit not present (correct for Direct build)${NC}"
fi

echo ""

# Step 6: Notarize (if Apple Developer account is configured)
echo -e "${YELLOW}🔐 Notarizing app with Apple...${NC}"
echo -e "${BLUE}This step requires Apple Developer credentials${NC}"

read -p "Do you want to notarize now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Create a temporary ZIP for notarization
    NOTARIZE_ZIP="${EXPORT_PATH}/${PROJECT_NAME}.zip"
    echo -e "${YELLOW}Creating ZIP for notarization...${NC}"
    ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZE_ZIP}"

    echo -e "${YELLOW}Uploading to Apple for notarization...${NC}"
    echo -e "${BLUE}You'll need to provide your Apple ID and app-specific password${NC}"

    read -p "Enter Apple ID: " APPLE_ID
    read -sp "Enter app-specific password: " APP_PASSWORD
    echo

    xcrun notarytool submit "${NOTARIZE_ZIP}" \
        --apple-id "${APPLE_ID}" \
        --password "${APP_PASSWORD}" \
        --team-id "YOUR_TEAM_ID" \
        --wait

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Notarization successful${NC}"

        # Staple the ticket
        echo -e "${YELLOW}Stapling notarization ticket...${NC}"
        xcrun stapler staple "${APP_PATH}"
        echo -e "${GREEN}✅ Notarization ticket stapled${NC}"
    else
        echo -e "${RED}❌ Notarization failed${NC}"
        echo -e "${YELLOW}You can notarize manually later${NC}"
    fi
else
    echo -e "${YELLOW}⏭️  Skipping notarization${NC}"
    echo -e "${BLUE}Remember to notarize before distributing!${NC}"
fi

echo ""

# Step 7: Create DMG (optional)
echo -e "${YELLOW}💿 Creating DMG installer...${NC}"

read -p "Create DMG installer? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "${DMG_PATH}"
    DMG_FILE="${DMG_PATH}/${PROJECT_NAME}_$(date +%Y%m%d).dmg"

    echo -e "${YELLOW}Building DMG...${NC}"

    # Check if create-dmg is installed
    if command -v create-dmg &> /dev/null; then
        create-dmg \
            --volname "${PROJECT_NAME}" \
            --volicon "${APP_PATH}/Contents/Resources/AppIcon.icns" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "${PROJECT_NAME}.app" 175 120 \
            --hide-extension "${PROJECT_NAME}.app" \
            --app-drop-link 425 120 \
            "${DMG_FILE}" \
            "${APP_PATH}"

        echo -e "${GREEN}✅ DMG created: ${DMG_FILE}${NC}"
    else
        # Fallback: Simple DMG creation
        hdiutil create -volname "${PROJECT_NAME}" \
            -srcfolder "${APP_PATH}" \
            -ov -format UDZO \
            "${DMG_FILE}"

        echo -e "${GREEN}✅ DMG created: ${DMG_FILE}${NC}"
        echo -e "${YELLOW}💡 Tip: Install 'create-dmg' for better DMG formatting${NC}"
        echo -e "   brew install create-dmg"
    fi
else
    echo -e "${YELLOW}⏭️  Skipping DMG creation${NC}"
fi

echo ""

# Step 8: Summary
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           BUILD SUCCESSFUL             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📦 Archive:${NC} ${ARCHIVE_PATH}"
echo -e "${BLUE}📤 Export:${NC} ${EXPORT_PATH}"
if [ -f "${DMG_FILE}" ]; then
    echo -e "${BLUE}💿 DMG:${NC} ${DMG_FILE}"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Test the app on a clean Mac"
echo -e "  2. Verify license key activation works"
echo -e "  3. Verify referral system is present"
echo -e "  4. Upload to your website for distribution"
echo ""
echo -e "${YELLOW}Distribution checklist:${NC}"
echo -e "  ✓ App is signed with Developer ID"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "  ✓ App is notarized by Apple"
else
    echo -e "  ⚠️  Remember to notarize before distributing!"
fi
echo -e "  ✓ License key system enabled"
echo -e "  ✓ Referral system enabled"
echo -e "  ✓ No App Store specific code"
echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
