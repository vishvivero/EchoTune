#!/bin/bash

#
# Build EchoTune - All Versions
# Master script to build both App Store and Direct Sale versions
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     ███████╗ ██████╗██╗  ██╗ ██████╗                ║
║     ██╔════╝██╔════╝██║  ██║██╔═══██╗               ║
║     █████╗  ██║     ███████║██║   ██║               ║
║     ██╔══╝  ██║     ██╔══██║██║   ██║               ║
║     ███████╗╚██████╗██║  ██║╚██████╔╝               ║
║     ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝                ║
║                                                       ║
║            MASTER BUILD SYSTEM                        ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check for required tools
echo -e "${YELLOW}🔍 Checking build environment...${NC}"

MISSING_TOOLS=()

if ! command -v xcodebuild &> /dev/null; then
    MISSING_TOOLS+=("xcodebuild")
fi

if ! command -v xcpretty &> /dev/null; then
    echo -e "${YELLOW}⚠️  xcpretty not found (optional but recommended)${NC}"
    echo -e "${BLUE}Install with: gem install xcpretty${NC}"
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing required tools: ${MISSING_TOOLS[*]}${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build environment OK${NC}"
echo ""

# Menu
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  What would you like to build?${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} App Store version only"
echo -e "  ${GREEN}2)${NC} Direct Sale version only"
echo -e "  ${GREEN}3)${NC} Both versions (recommended)"
echo -e "  ${GREEN}4)${NC} Clean all builds"
echo -e "  ${GREEN}5)${NC} Verify build configurations"
echo -e "  ${GREEN}6)${NC} Exit"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}Building App Store version...${NC}"
        echo ""
        bash ./Scripts/build_app_store.sh
        ;;

    2)
        echo ""
        echo -e "${BLUE}Building Direct Sale version...${NC}"
        echo ""
        bash ./Scripts/build_direct_sale.sh
        ;;

    3)
        echo ""
        echo -e "${BLUE}Building both versions...${NC}"
        echo ""

        # Build App Store version
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  Step 1/2: App Store Version${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        bash ./Scripts/build_app_store.sh

        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  Step 2/2: Direct Sale Version${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        bash ./Scripts/build_direct_sale.sh

        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║    ALL BUILDS COMPLETED SUCCESSFULLY   ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}📦 App Store version:${NC} ./build/exports/AppStore/"
        echo -e "${BLUE}📦 Direct Sale version:${NC} ./build/exports/Direct/"
        echo ""
        ;;

    4)
        echo ""
        echo -e "${YELLOW}🧹 Cleaning all builds...${NC}"

        # Clean Xcode build folder
        if [ -d "./build" ]; then
            echo -e "${YELLOW}Removing ./build directory...${NC}"
            rm -rf ./build
            echo -e "${GREEN}✅ Build directory cleaned${NC}"
        fi

        # Clean Xcode derived data for this project
        echo -e "${YELLOW}Cleaning Xcode derived data...${NC}"
        xcodebuild clean -project EchoTune.xcodeproj -scheme EchoTune -configuration Release > /dev/null 2>&1
        xcodebuild clean -project EchoTune.xcodeproj -scheme EchoTune -configuration Debug > /dev/null 2>&1

        echo -e "${GREEN}✅ All builds cleaned${NC}"
        echo ""
        ;;

    5)
        echo ""
        echo -e "${YELLOW}🔍 Verifying build configurations...${NC}"
        echo ""

        # Check Release configuration
        echo -e "${CYAN}━━━ Release (App Store) Configuration ━━━${NC}"
        RELEASE_FLAGS=$(xcodebuild -project EchoTune.xcodeproj \
            -scheme EchoTune \
            -configuration Release \
            -showBuildSettings | grep "OTHER_SWIFT_FLAGS" || echo "")

        if echo "$RELEASE_FLAGS" | grep -q "APPSTORE"; then
            echo -e "${GREEN}✅ APPSTORE flag is SET (correct for App Store)${NC}"
        else
            echo -e "${RED}❌ APPSTORE flag is NOT SET${NC}"
            echo -e "${YELLOW}   Please add '-D APPSTORE' to Release configuration${NC}"
        fi

        echo ""

        # Check Debug configuration
        echo -e "${CYAN}━━━ Debug (Direct Sale) Configuration ━━━${NC}"
        DEBUG_FLAGS=$(xcodebuild -project EchoTune.xcodeproj \
            -scheme EchoTune \
            -configuration Debug \
            -showBuildSettings | grep "OTHER_SWIFT_FLAGS" || echo "")

        if echo "$DEBUG_FLAGS" | grep -q "APPSTORE"; then
            echo -e "${RED}❌ APPSTORE flag is SET (should not be for Direct Sale)${NC}"
            echo -e "${YELLOW}   Please remove '-D APPSTORE' from Debug configuration${NC}"
        else
            echo -e "${GREEN}✅ APPSTORE flag is NOT SET (correct for Direct Sale)${NC}"
        fi

        echo ""
        echo -e "${YELLOW}Configuration Summary:${NC}"
        echo -e "  Release (App Store):  $(echo "$RELEASE_FLAGS" | grep -q "APPSTORE" && echo "${GREEN}✅ Configured${NC}" || echo "${RED}❌ Not configured${NC}")"
        echo -e "  Debug (Direct Sale):  $(echo "$DEBUG_FLAGS" | grep -q "APPSTORE" && echo "${RED}❌ Misconfigured${NC}" || echo "${GREEN}✅ Configured${NC}")"
        echo ""
        ;;

    6)
        echo ""
        echo -e "${BLUE}👋 Goodbye!${NC}"
        exit 0
        ;;

    *)
        echo ""
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✨ Done!${NC}"
