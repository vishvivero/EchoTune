#!/bin/bash
# Scripts/precompile_models.sh
#
# Pre-compiles WhisperKit CoreML models and copies them into the EchoTune
# app bundle resources. This eliminates the 5-8 minute first-launch penalty.
#
# Usage:
#   1. First, let the app download + compile the model normally (run once)
#   2. Then run: ./Scripts/precompile_models.sh
#   3. Rebuild the app — compiled models are now bundled
#
# Compiled models are copied from ~/Library/Developer/Xcode/DerivedData/...
# into EchoTune/Resources/CompiledModels/ for embedding in the .app bundle.
#
# At runtime, WhisperEngine.loadModel() checks for pre-compiled models in the
# bundle and symlinks them before WhisperKit init, skipping CoreML compilation.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES_DIR="$PROJECT_DIR/EchoTune/Resources/CompiledModels"

echo "=== EchoTune Pre-Compile Model Script ==="
echo ""

# Find compiled .mlmodelc files in DerivedData
DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 3 -type d -name "*.mlmodelc" -path "*/WhisperKit*" 2>/dev/null | head -5)

if [ -z "$DERIVED_DATA" ]; then
    echo "⚠️  No compiled .mlmodelc files found in DerivedData."
    echo "   Run the app once with a WhisperKit model to trigger compilation first."
    echo "   Look in: ~/Library/Developer/Xcode/DerivedData/EchoTune-*/Build/"
    echo ""
    exit 1
fi

echo "📦 Found compiled models:"
echo "$DERIVED_DATA"
echo ""

# Collect all .mlmodelc directories
mkdir -p "$RESOURCES_DIR"

FOUND=0
for dir in $(find ~/Library/Developer/Xcode/DerivedData -maxdepth 5 -type d -name "*.mlmodelc" 2>/dev/null); do
    # Only copy WhisperKit-related models
    if echo "$dir" | grep -qi "whisper\|melspectrogram\|audioencoder\|textdecoder"; then
        name=$(basename "$dir")
        echo "   → Copying $name..."
        rm -rf "$RESOURCES_DIR/$name"
        cp -R "$dir" "$RESOURCES_DIR/$name"
        FOUND=$((FOUND + 1))
    fi
done

echo ""
echo "✅ Copied $FOUND compiled models to:"
echo "   $RESOURCES_DIR"
echo ""
echo "📋 Now add this directory to the Xcode target as a folder reference"
echo "   (File → Add Files to EchoTune → select the CompiledModels folder)"
echo "   so it gets bundled into EchoTune.app/Contents/Resources/"
