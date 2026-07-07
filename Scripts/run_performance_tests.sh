#!/bin/bash
#
# EchoTune Performance Testing Suite
# Automated benchmark execution and analysis
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 EchoTune Performance Benchmark Suite${NC}"
echo "========================================"
echo ""

# Get system information
echo -e "${BLUE}📊 System Information${NC}"
echo "Device: $(system_profiler SPHardwareDataType | grep 'Model Name' | awk -F': ' '{print $2}')"
echo "Chip: $(sysctl -n machdep.cpu.brand_string)"
echo "OS: $(sw_vers -productName) $(sw_vers -productVersion)"
echo "Architecture: $(uname -m)"
echo ""

# Check if app is built
APP_PATH="/Users/vishnuraj/Library/Developer/Xcode/DerivedData/EchoTune-hhbabwldyambijecdujomsccmhtz/Build/Products/Debug/EchoTune.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${YELLOW}⚠️  App not found at expected path. Building now...${NC}"
    cd /Users/vishnuraj/Downloads/EchoTune
    xcodebuild -project EchoTune.xcodeproj -scheme EchoTune -configuration Debug build
    echo -e "${GREEN}✅ Build complete${NC}"
fi

# Create test results directory
RESULTS_DIR="/Users/vishnuraj/Downloads/EchoTune/BenchmarkResults"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$RESULTS_DIR/benchmark_$TIMESTAMP.csv"
REPORT_FILE="$RESULTS_DIR/benchmark_report_$TIMESTAMP.md"

echo -e "${BLUE}📁 Results will be saved to:${NC}"
echo "  CSV: $RESULT_FILE"
echo "  Report: $REPORT_FILE"
echo ""

# Test scenarios
echo -e "${BLUE}🧪 Test Scenarios${NC}"
echo "This script will guide you through manual performance testing."
echo ""
echo "We'll test the following scenarios:"
echo "  1. 5-second speech recording"
echo "  2. 10-second speech recording"
echo "  3. Pure silence (3 seconds)"
echo "  4. Mixed speech and silence (10 seconds)"
echo ""

# Manual testing instructions
echo -e "${YELLOW}📝 Manual Testing Instructions${NC}"
echo ""
echo "Since we need real-time transcription tests, please follow these steps:"
echo ""
echo "1. Launch EchoTune:"
echo "   open \"$APP_PATH\""
echo ""
echo "2. Enable performance monitoring:"
echo "   - Go to Settings → Advanced"
echo "   - Enable 'Performance Monitoring'"
echo ""
echo "3. Run each test scenario:"
echo ""
echo "   Test 1: 5-second speech"
echo "   - Press ⌘⇧D to start recording"
echo "   - Speak for exactly 5 seconds"
echo "   - Press ⌘⇧D to stop"
echo "   - Note the performance metrics in console"
echo ""
echo "   Test 2: 10-second speech"
echo "   - Press ⌘⇧D to start recording"
echo "   - Speak for exactly 10 seconds"
echo "   - Press ⌘⇧D to stop"
echo "   - Note the performance metrics"
echo ""
echo "   Test 3: Pure silence (3 seconds)"
echo "   - Press ⌘⇧D to start recording"
echo "   - Stay completely silent for 3 seconds"
echo "   - Press ⌘⇧D to stop"
echo "   - Should be skipped by VAD (~0.2s total)"
echo ""
echo "   Test 4: Mixed speech/silence (10 seconds)"
echo "   - Press ⌘⇧D to start recording"
echo "   - Speak for 3s, silence for 4s, speak for 3s"
echo "   - Press ⌘⇧D to stop"
echo "   - Note the performance metrics"
echo ""

# Automated metrics collection
echo -e "${BLUE}📊 Automated Metrics Collection${NC}"
echo ""
echo "To collect performance metrics automatically:"
echo ""
echo "1. Keep Console.app open filtered to 'EchoTune'"
echo "2. Look for these metrics after each test:"
echo "   - ⏱️ Recording duration"
echo "   - 🔄 Audio conversion time"
echo "   - 📊 VAD analysis (if enabled)"
echo "   - 🎙️ Transcription time"
echo "   - ⚡ Total latency"
echo "   - 📈 Real-Time Factor (RTF)"
echo ""

# Instruments profiling (optional)
echo -e "${BLUE}🔬 Advanced Profiling with Instruments (Optional)${NC}"
echo ""
echo "For detailed GPU/CPU utilization analysis:"
echo ""
echo "1. Open Instruments:"
echo "   instruments -t 'Time Profiler' -D '$RESULTS_DIR/profile_$TIMESTAMP.trace' '$APP_PATH'"
echo ""
echo "2. Or use Xcode:"
echo "   - Product → Profile (⌘I)"
echo "   - Select 'Metal System Trace' template"
echo "   - Record while running test scenarios"
echo "   - Analyze GPU utilization and compute unit usage"
echo ""

# Export performance metrics
echo -e "${BLUE}💾 Exporting Performance Metrics${NC}"
echo ""
echo "After running tests, export metrics from EchoTune:"
echo ""
echo "1. Go to Settings → Advanced"
echo "2. Click 'Export Metrics'"
echo "3. Save to: $RESULT_FILE"
echo ""

# Analysis script
echo -e "${BLUE}📈 Performance Analysis${NC}"
echo ""
echo "After collecting data, run the analysis script:"
echo "  python3 Scripts/analyze_performance.py $RESULT_FILE"
echo ""

# Expected results
echo -e "${GREEN}🎯 Expected Performance Targets${NC}"
echo ""
echo "Phase 1 (File I/O Optimization):"
echo "  - 10s audio → ~5.5s processing"
echo "  - RTF: ~0.55x"
echo "  - Improvement: 30-40% vs baseline"
echo ""
echo "Phase 2 (VAD Pre-filtering):"
echo "  - 10s speech → ~4.0s processing"
echo "  - 10s silence → ~0.2s processing (97% faster!)"
echo "  - RTF: ~0.40x (speech), ~0.02x (silence)"
echo ""
echo "Phase 3 (Metal Acceleration):"
echo "  - 10s speech → ~2.0s processing"
echo "  - RTF: ~0.20x"
echo "  - First transcription: instant (preloaded)"
echo "  - Improvement: 2-3x vs Phase 2"
echo ""
echo "  Total vs Baseline: 75-81% faster ✅"
echo ""

# Quick RTF calculator
echo -e "${BLUE}🧮 Quick RTF Calculator${NC}"
echo ""
echo "Enter your test results to calculate RTF:"
echo ""

read -p "Audio duration (seconds): " AUDIO_DURATION
read -p "Processing time (seconds): " PROCESSING_TIME

if [ ! -z "$AUDIO_DURATION" ] && [ ! -z "$PROCESSING_TIME" ]; then
    RTF=$(echo "scale=2; $PROCESSING_TIME / $AUDIO_DURATION" | bc)
    SPEEDUP=$(echo "scale=2; $AUDIO_DURATION / $PROCESSING_TIME" | bc)
    echo ""
    echo -e "${GREEN}Results:${NC}"
    echo "  RTF: ${RTF}x"
    echo "  Speedup: ${SPEEDUP}x faster than real-time"
    echo ""
    if (( $(echo "$RTF < 0.2" | bc -l) )); then
        echo -e "${GREEN}✅ Exceeds Phase 3 target (< 0.2x)${NC}"
    elif (( $(echo "$RTF < 0.4" | bc -l) )); then
        echo -e "${YELLOW}⚠️  Close to target, but room for improvement${NC}"
    else
        echo -e "${RED}❌ Below target - check Metal configuration${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ Benchmark suite ready!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run manual tests following instructions above"
echo "  2. Export metrics from EchoTune"
echo "  3. Run analysis: python3 Scripts/analyze_performance.py"
echo ""
