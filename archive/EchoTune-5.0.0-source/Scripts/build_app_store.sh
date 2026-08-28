#!/bin/bash

#
# Build EchoTune for App Store Distribution
# This script builds and archives the App Store version with StoreKit IAP
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  EchoTune - App Store Build Script    ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""

# Configuration
PROJECT_NAME="EchoTune"
SCHEME="EchoTune"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/archives/${PROJECT_NAME}_AppStore_$(date +%Y%m%d_%H%M%S).xcarchive"
EXPORT_PATH="./build/exports/AppStore"
EXPORT_OPTIONS_PLIST="./Scripts/ExportOptions_AppStore.plist"

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

# Step 2: Verify APPSTORE flag is set
echo -e "${YELLOW}🔍 Verifying APPSTORE build flag...${NC}"

FLAG_CHECK=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -showBuildSettings | grep "OTHER_SWIFT_FLAGS" | grep "APPSTORE" || echo "")

if [ -z "$FLAG_CHECK" ]; then
    echo -e "${RED}❌ Error: APPSTORE flag not set in Release configuration${NC}"
    echo -e "${YELLOW}Please add '-D APPSTORE' to Other Swift Flags in Release configuration${NC}"
    echo -e "${YELLOW}See BUILD_CONFIGURATION_GUIDE.md for instructions${NC}"
    exit 1
fi

echo -e "${GREEN}✅ APPSTORE flag is set${NC}"
echo ""

# Step 3: Build and archive
echo -e "${YELLOW}📦 Building and archiving App Store version...${NC}"
echo -e "${BLUE}This may take several minutes...${NC}"
echo ""

xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    | xcpretty || exit 1

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}❌ Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive created successfully${NC}"
echo -e "${BLUE}📍 Location: ${ARCHIVE_PATH}${NC}"
echo ""

# Step 4: Export for App Store
echo -e "${YELLOW}📤 Exporting for App Store Connect...${NC}"

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
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
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

# Check for StoreKit framework (should be present in App Store build)
echo -e "${YELLOW}Checking for StoreKit framework...${NC}"
if nm "${APP_PATH}/Contents/MacOS/${PROJECT_NAME}" | grep -q "StoreKit"; then
    echo -e "${GREEN}✅ StoreKit framework detected (correct for App Store build)${NC}"
else
    echo -e "${RED}⚠️  Warning: StoreKit framework not detected${NC}"
fi

echo ""

# Step 6: Summary
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           BUILD SUCCESSFUL             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📦 Archive:${NC} ${ARCHIVE_PATH}"
echo -e "${BLUE}📤 Export:${NC} ${EXPORT_PATH}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Open Xcode Organizer (Window → Organizer)"
echo -e "  2. Select the archive from 'Archives' tab"
echo -e "  3. Click 'Distribute App'"
echo -e "  4. Choose 'App Store Connect'"
echo -e "  5. Follow the wizard to upload"
echo ""
echo -e "${YELLOW}Or upload manually:${NC}"
echo -e "  xcrun altool --upload-app -f '${EXPORT_PATH}/${PROJECT_NAME}.pkg' -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD"
echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
