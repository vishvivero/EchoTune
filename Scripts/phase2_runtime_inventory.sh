#!/bin/bash
# Capture runtime benchmark prerequisites without launching the app or downloading models.
# Usage: Scripts/phase2_runtime_inventory.sh [output-directory]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/experiments/baseline/runtime-inventory-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"

{
  echo "# EchoTune Phase 2 Runtime Inventory"
  echo
  echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repository: $ROOT"
  echo "commit: $(git -C "$ROOT" rev-parse HEAD)"
  echo "branch: $(git -C "$ROOT" branch --show-current)"
  echo
  echo "## Host"
  sw_vers
  xcodebuild -version
  uname -a
  sysctl -n hw.model 2>/dev/null || true
  sysctl -n hw.memsize 2>/dev/null || true
  df -h / | tail -1
  echo
  echo "## Model roots"
  for path in \
    "$HOME/Library/Application Support/EchoTune/Models" \
    "$HOME/Library/Application Support/EchoTune/WhisperModels" \
    "$HOME/Documents/huggingface" \
    "$HOME/Library/Developer/Xcode/DerivedData"; do
    if [ -e "$path" ]; then
      echo "EXISTS $path"
      du -sh "$path" 2>/dev/null || true
    else
      echo "MISSING $path"
    fi
  done
  echo
  echo "## Installed model candidates"
  find "$HOME/Library/Application Support/EchoTune" "$HOME/Documents/huggingface" \
    -type d \( -name '*.mlmodelc' -o -name '*whisper*' -o -name '*parakeet*' \) \
    -print 2>/dev/null | sort || true
  echo
  echo "## Audio fixtures"
  find "$ROOT/experiments/fixtures" -type f -maxdepth 2 -print 2>/dev/null | sort || true
  echo
  echo "## Existing performance hooks"
  grep -RIl 'PerformanceMonitor\|startTranscription\|endTranscription' \
    "$ROOT/EchoTune" --include='*.swift' | sort
} > "$OUT/inventory.txt"

# Keep machine-readable facts separate from the human report.
python3 - "$OUT/inventory.json" <<'PY'
import json, os, platform, subprocess, sys
out = sys.argv[1]
def run(*args):
    try: return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception: return None
payload = {
    "timestamp_utc": run("date", "-u", "+%Y-%m-%dT%H:%M:%SZ"),
    "commit": run("git", "-C", os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rev-parse", "HEAD"),
    "host": platform.platform(),
    "machine": platform.machine(),
    "xcode": run("xcodebuild", "-version"),
    "model_roots": [os.path.expanduser("~/Library/Application Support/EchoTune/Models"), os.path.expanduser("~/Library/Application Support/EchoTune/WhisperModels")],
}
json.dump(payload, open(out, "w"), indent=2)
PY
printf 'Wrote %s\n' "$OUT"
printf '%s\n' "$OUT/inventory.txt" "$OUT/inventory.json"
