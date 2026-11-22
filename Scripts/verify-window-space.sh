#!/bin/bash
#
# verify-window-space.sh — reproduce and verify EchoTune's
# "window is stranded in a foreign fullscreen Space, so nothing is clickable and it
# cannot be closed" bug.
#
# EchoTune is a menu-bar (LSUIElement) app that also owns standard windows. If one of
# those windows is ordered front while *another* app's fullscreen Space is active, macOS
# parks it inside that Space: no menu bar, WindowServer owns the frame (so AppKit's copy
# silently drifts out of sync), and clicks fall through to the app behind.
#
# Commands:
#   arm                   put a throwaway fullscreen app in front (active Space = fullscreen)
#   disarm                leave fullscreen and quit the helper app
#   launch <App.app>      kill + relaunch a bundle (so its launch path runs)
#   check [App] [--close] run the evidence checks (add --close to press the close button)
#   scenario <App.app>    arm -> launch -> check --close  (the full regression scenario)
#
# Env: FULLSCREEN_APP (default TextEdit), APP_BUNDLE (default /Applications/EchoTune.app)

set -uo pipefail

TOOLS_DIR="${TMPDIR:-/tmp}/et-space-tools"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FULLSCREEN_APP="${FULLSCREEN_APP:-TextEdit}"
APP_BUNDLE="${APP_BUNDLE:-/Applications/EchoTune.app}"

# ------------------------------------------------------------------ helper binaries
build_tools() {
  mkdir -p "$TOOLS_DIR"
  cat > "$TOOLS_DIR/spacego.swift.new" <<'SWIFT'
import Cocoa
typealias CID = UInt32
let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)!
func sym<T>(_ n: String) -> T? { guard let s = dlsym(h, n) else { return nil }; return unsafeBitCast(s, to: T.self) }
let mainConn = sym("CGSMainConnectionID") as (@convention(c) () -> CID)?
let copyMD = sym("CGSCopyManagedDisplaySpaces") as (@convention(c) (CID) -> Unmanaged<CFArray>?)?
let setSpace = sym("CGSManagedDisplaySetCurrentSpace") as (@convention(c) (CID, CFString, UInt64) -> Int32)?
let spaceType = sym("CGSSpaceGetType") as (@convention(c) (CID, UInt64) -> Int32)?
let getActive = sym("CGSGetActiveSpace") as (@convention(c) (CID) -> UInt64)?
let cid = mainConn!()
func tn(_ t: Int32) -> String { t == 0 ? "user" : t == 4 ? "FULLSCREEN" : t == 5 ? "tiled" : "type\(t)" }
func displays() -> [(String, [(UInt64, Int32, String)])] {
  var r: [(String, [(UInt64, Int32, String)])] = []
  if let md = copyMD?(cid)?.takeRetainedValue() as? [[String: Any]] {
    for d in md {
      var s: [(UInt64, Int32, String)] = []
      for e in d["Spaces"] as? [[String: Any]] ?? [] {
        if let i = e["id64"] as? UInt64 { s.append((i, spaceType!(cid, i), "\(e["appName"] as? String ?? "")\(e["appName"] == nil ? "" : " ")pid=\(e["pid"] as? Int ?? 0)")) }
      }
      r.append(((d["Display Identifier"] as? String) ?? "?", s))
    }
  }
  return r
}
let args = CommandLine.arguments
if args.count > 1, args[1] == "list" {
  let a = getActive!(cid); print("active=\(a) [\(tn(spaceType!(cid, a)))]")
  for (uuid, ss) in displays() { print("display \(uuid)"); for (i, t, o) in ss { print("  \(i) [\(tn(t))] \(o)") } }
} else if args.count > 2, args[1] == "goto" {
  let target = UInt64(args[2])!
  if let d = displays().first(where: { $0.1.contains { $0.0 == target } }) {
    let rc = setSpace!(cid, d.0 as CFString, target)
    print("switched display \(d.0) -> \(target) (rc=\(rc))")
  } else { print("space \(target) not found"); exit(1) }
} else if args.count > 2, args[1] == "find" {
  // find the first space of the given type owned by the given pid (or app name)
  let want = tn(Int32(args[3])!); let key = args[2]
  for (_, ss) in displays() { for (i, t, o) in ss where tn(t) == want && (o.contains("pid=\(key)") || o.contains(key)) { print(i); exit(0) } }
  exit(1)
} else { print("usage: spacego list | goto <id> | find <app> <type>"); exit(1) }
SWIFT
  if ! cmp -s "$TOOLS_DIR/spacego.swift" "$TOOLS_DIR/spacego.swift.new" || [[ ! -x "$TOOLS_DIR/spacego" ]]; then
    mv "$TOOLS_DIR/spacego.swift.new" "$TOOLS_DIR/spacego.swift"
    swiftc -O -o "$TOOLS_DIR/spacego" "$TOOLS_DIR/spacego.swift" >/dev/null 2>&1
  else
    rm -f "$TOOLS_DIR/spacego.swift.new"
  fi
  if [[ ! -x "$TOOLS_DIR/window-space-check" || "$REPO_DIR/Scripts/window-space-check.swift" -nt "$TOOLS_DIR/window-space-check" ]]; then
    swiftc -O -o "$TOOLS_DIR/window-space-check" "$REPO_DIR/Scripts/window-space-check.swift" >/dev/null 2>&1
  fi
  [[ -x "$TOOLS_DIR/spacego" && -x "$TOOLS_DIR/window-space-check" ]]
}

active_space_type() { "$TOOLS_DIR/spacego" list | head -1; }

# ------------------------------------------------------------------------- fullscreen
arm() {
  build_tools || { echo "!! could not build tools"; return 1; }
  for _ in $(seq 1 6); do
    pgrep -x "$FULLSCREEN_APP" >/dev/null || open -a "$FULLSCREEN_APP"
    sleep 1
    local windows
    windows=$(osascript -e "tell application \"System Events\" to tell process \"$FULLSCREEN_APP\" to get count of windows" 2>/dev/null)
    if [[ "${windows:-0}" == "0" ]]; then
      osascript -e "tell application \"System Events\" to tell process \"$FULLSCREEN_APP\" to set frontmost to true" >/dev/null 2>&1
      sleep 0.5
      osascript -e 'tell application "System Events" to keystroke "n" using command down' >/dev/null 2>&1
      sleep 1
    fi
    local fs
    fs=$(osascript -e "tell application \"System Events\" to tell process \"$FULLSCREEN_APP\" to get value of attribute \"AXFullScreen\" of window 1" 2>/dev/null)
    if [[ "$fs" != "true" ]]; then
      osascript -e "tell application \"System Events\" to tell process \"$FULLSCREEN_APP\" to set value of attribute \"AXFullScreen\" of window 1 to true" >/dev/null 2>&1
      sleep 2
    fi
    local id
    id=$("$TOOLS_DIR/spacego" find "$(pgrep -x "$FULLSCREEN_APP" | head -1)" 4 2>/dev/null)
    if [[ -n "${id:-}" ]]; then
      "$TOOLS_DIR/spacego" goto "$id" >/dev/null
      sleep 1.5
      if "$TOOLS_DIR/spacego" list | head -1 | grep -q "FULLSCREEN"; then
        echo "ARMED: $("$TOOLS_DIR/spacego" list | head -1)  (foreign fullscreen Space)"
        return 0
      fi
    fi
  done
  echo "FAILED to arm a foreign fullscreen Space ($("$TOOLS_DIR/spacego" list | head -1))"
  return 1
}

disarm() {
  build_tools
  osascript -e "tell application \"System Events\" to tell process \"$FULLSCREEN_APP\" to set value of attribute \"AXFullScreen\" of window 1 to false" >/dev/null 2>&1
  local desktop
  desktop=$("$TOOLS_DIR/spacego" list | grep -m1 "\[user\]" | awk '{print $1}')
  [[ -n "${desktop:-}" ]] && "$TOOLS_DIR/spacego" goto "$desktop" >/dev/null
  sleep 1.5
  if [[ "$FULLSCREEN_APP" == "TextEdit" ]]; then pkill -x TextEdit >/dev/null 2>&1; fi
  echo "DISARMED: $("$TOOLS_DIR/spacego" list | head -1)"
}

launch_app() {
  build_tools
  local bundle="${1:-$APP_BUNDLE}"
  # kill *any* EchoTune instance so this is a genuine fresh-launch path
  pkill -f "EchoTune.app/Contents/MacOS" >/dev/null 2>&1
  sleep 1
  open -a "$bundle"
  sleep 4
}

check() {
  build_tools
  "$TOOLS_DIR/window-space-check" "${1:-EchoTune}" ${2:-}
}

scenario() {
  local bundle="${1:-$APP_BUNDLE}"
  echo "### scenario: launch $bundle while another app is fullscreen"
  arm || return 1
  launch_app "$bundle"
  echo "--- checks"
  check EchoTune --close
  local rc=$?
  echo "### scenario exit=$rc"
  return $rc
}

case "${1:-check}" in
  arm)      arm ;;
  disarm)   disarm ;;
  launch)   shift; launch_app "${1:-}" ;;
  check)    shift; check "$@" ;;
  scenario) shift; scenario "${1:-}" ;;
  *)        echo "usage: $0 {arm|disarm|launch <app>|check [App] [--close]|scenario <app>}"; exit 1 ;;
esac
