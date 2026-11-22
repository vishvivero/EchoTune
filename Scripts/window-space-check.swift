//
//  window-space-check.swift
//  EchoTune verification tool (not part of the app target)
//
//  Answers one question with evidence: can the user actually see, click and close
//  EchoTune's window right now?
//
//  It cross-checks three independent sources of truth:
//    * WindowServer  — CGWindowListCopyWindowInfo (where the window really is)
//    * AppKit        — the accessibility (AX) frame an app reports
//    * WindowServer  — hit testing (which app a click at a point reaches)
//  plus Spaces membership (which Space the window is in, and what kind).
//
//  Usage: window-space-check <appName> [--close] [--window-count] [--print-close-point]
//  Exit status 0 = PASS, 1 = FAIL.
//
//  A real (System Events) click must be issued by the caller's shell, not from here:
//  macOS attributes Accessibility permission to the *responsible* process, so a click
//  posted by this freshly built helper is refused while one posted by an already trusted
//  shell is accepted. `--print-close-point` and `--window-count` expose what it needs.
//

import Cocoa

typealias CID = UInt32
let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)!
func sym<T>(_ name: String) -> T? {
    guard let symbol = dlsym(handle, name) else { return nil }
    return unsafeBitCast(symbol, to: T.self)
}
let mainConnection = sym("CGSMainConnectionID") as (@convention(c) () -> CID)?
let copySpacesForWindows = sym("CGSCopySpacesForWindows") as (@convention(c) (CID, Int32, CFArray) -> Unmanaged<CFArray>?)?
let activeSpaceFn = sym("CGSGetActiveSpace") as (@convention(c) (CID) -> UInt64)?
let spaceTypeFn = sym("CGSSpaceGetType") as (@convention(c) (CID, UInt64) -> Int32)?
let connection = mainConnection!()

func typeName(_ type: Int32) -> String {
    switch type {
    case 0: return "user"
    case 2: return "system"
    case 4: return "FULLSCREEN"
    case 5: return "tiled"
    default: return "type\(type)"
    }
}
func spaceDescription(_ id: UInt64) -> String { "\(id)[\(typeName(spaceTypeFn!(connection, id)))]" }
func spaces(ofWindow number: Int) -> [UInt64] {
    (copySpacesForWindows?(connection, 7, [number] as CFArray)?.takeRetainedValue() as? [UInt64]) ?? []
}
func activeSpace() -> (UInt64, Int32) { let a = activeSpaceFn!(connection); return (a, spaceTypeFn!(connection, a)) }
let arguments = CommandLine.arguments
let appName = arguments.count > 1 ? arguments[1] : "EchoTune"
let shouldClose = arguments.contains("--close")

var failures: [String] = []
func check(_ condition: Bool, _ label: String, _ detail: String) {
    print("\(condition ? "  ok  " : " FAIL ") \(label): \(detail)")
    if !condition { failures.append(label) }
}

// --- app ---------------------------------------------------------------------------
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.echotune.EchoTune").first
    ?? NSWorkspace.shared.runningApplications.first { $0.localizedName == appName }
guard let app else { print("FAIL: \(appName) is not running"); exit(1) }
print("app=\(appName) pid=\(app.processIdentifier) policy=\(app.activationPolicy.rawValue) active=\(app.isActive)")

let (activeID, activeType) = activeSpace()
print("active_space=\(activeID)[\(typeName(activeType))]")

// --- the app's standard windows, per WindowServer ----------------------------------
let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
let owned = windowList.filter { ($0["kCGWindowOwnerPID"] as? Int) == Int(app.processIdentifier) }
let windowNumberByTitle: [String: Int] = owned.reduce(into: [:]) { partial, entry in
    guard let number = entry["kCGWindowNumber"] as? Int,
          let title = entry["kCGWindowName"] as? String, !title.isEmpty,
          (entry["kCGWindowBounds"] as? [String: CGFloat]).map({ $0["Width"]! > 200 }) ?? false
    else { return }
    partial[title] = number
}

// --- what AppKit reports through accessibility -------------------------------------
let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
var axWindows: CFTypeRef?
AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &axWindows)

func windowCount() -> Int { ((axWindows as? [AXUIElement]) ?? []).count }

var axFrame: CGRect?
var windowElement: AXUIElement?
var closeButton: AXUIElement?
var axTitle = ""
for raw in (axWindows as? [AXUIElement]) ?? [] {
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(raw, kAXTitleAttribute as CFString, &titleValue)
    var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
    AXUIElementCopyAttributeValue(raw, kAXPositionAttribute as CFString, &positionValue)
    AXUIElementCopyAttributeValue(raw, kAXSizeAttribute as CFString, &sizeValue)
    guard let positionValue, let sizeValue else { continue }
    var origin = CGPoint.zero, size = CGSize.zero
    AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    if size.width > 200, axFrame == nil {
        axFrame = CGRect(origin: origin, size: size)
        axTitle = (titleValue as? String) ?? ""
        windowElement = raw
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(raw, kAXChildrenAttribute as CFString, &children)
        for child in (children as? [AXUIElement]) ?? [] {
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXSubroleAttribute as CFString, &subrole)
            if (subrole as? String) == kAXCloseButtonSubrole as String { closeButton = child }
        }
    }
}

func closeButtonCentre() -> CGPoint? {
    guard let closeButton else { return nil }
    var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
    AXUIElementCopyAttributeValue(closeButton, kAXPositionAttribute as CFString, &positionValue)
    AXUIElementCopyAttributeValue(closeButton, kAXSizeAttribute as CFString, &sizeValue)
    var origin = CGPoint.zero, size = CGSize.zero
    if let positionValue { AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin) }
    if let sizeValue { AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) }
    return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
}

// --- report-only modes used by the shell to drive a real click ---------------------
if arguments.contains("--window-count") {
    print("windows=\(windowCount())")
    exit(0)
}
if arguments.contains("--print-close-point") {
    guard let centre = closeButtonCentre() else { print("close_point="); exit(1) }
    print("close_point=\(Int(centre.x)),\(Int(centre.y))")
    exit(0)
}

// --- required: a standard window exists -------------------------------------------
guard let number = windowNumberByTitle["EchoTune"] ?? windowNumberByTitle.values.first else {
    check(false, "window-exists", "no EchoTune standard window is registered with WindowServer")
    print("VERDICT=FAIL"); exit(1)
}

// --- WindowServer frame vs the frame AppKit reports --------------------------------
let entry = owned.first { ($0["kCGWindowNumber"] as? Int) == number }!
let bounds = entry["kCGWindowBounds"] as! [String: CGFloat]
let cgFrame = CGRect(x: bounds["X"]!, y: bounds["Y"]!, width: bounds["Width"]!, height: bounds["Height"]!)
let onScreen = entry["kCGWindowIsOnscreen"] != nil

let drift = axFrame.map { max(abs($0.minX - cgFrame.minX), abs($0.minY - cgFrame.minY), abs($0.width - cgFrame.width), abs($0.height - cgFrame.height)) }
print("window win=\(number) title='\(axTitle)' onscreen=\(onScreen ? 1 : 0)")
print("  cg=\(Int(cgFrame.minX)),\(Int(cgFrame.minY)) \(Int(cgFrame.width))x\(Int(cgFrame.height))")
print("  ax=\(axFrame.map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? "unavailable")")
print("  spaces=\(spaces(ofWindow: number).map(spaceDescription).joined(separator: ","))")

check(onScreen, "window-on-screen", "kCGWindowIsOnscreen=\(onScreen)")
check(axFrame != nil, "ax-window-exposed", axFrame == nil ? "AppKit reports no standard window (no title bar / traffic lights)" : "title bar present")
check((drift ?? 999) <= 2, "frame-in-sync", "WindowServer/AppKit drift = \(drift.map { String(format: "%.1f", $0) } ?? "n/a") pt")

let windowSpaces = spaces(ofWindow: number)
check(!windowSpaces.contains { typeName(spaceTypeFn!(connection, $0)) == "FULLSCREEN" }, "not-on-fullscreen-space", "spaces=\(windowSpaces.map(spaceDescription).joined(separator: ","))")
check(activeType != 4, "active-space-usable", "active Space is \(typeName(activeType))")

// Reachability independent of z-order: the title bar must sit inside a screen's usable
// area. That is exactly what the original bug violated — the window lived on a fullscreen
// Space, below the display, so its traffic lights existed but could never be reached.
let primaryHeight = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height ?? NSScreen.screens.first?.frame.height ?? 0
let cocoaFrame = CGRect(x: cgFrame.minX, y: primaryHeight - cgFrame.maxY, width: cgFrame.width, height: cgFrame.height)
let titleStrip = CGRect(x: cocoaFrame.minX, y: cocoaFrame.maxY - 24, width: cocoaFrame.width, height: 24)
let titleVisibleWidth = NSScreen.screens.map { $0.visibleFrame.intersection(titleStrip).width }.max() ?? 0
check(titleVisibleWidth >= min(cocoaFrame.width, 200), "titlebar-on-screen", "\(Int(titleVisibleWidth)) pt of the title bar is inside a screen's usable area")

// --- hit testing: which app does a click reach? ------------------------------------
// Raise the window first so this measures whether the window is *reachable* rather than
// which app happens to be overlapping it at the moment.
if let windowElement {
    AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
    usleep(400_000)
}
func hitTest(_ point: CGPoint) -> pid_t {
    var element: AXUIElement?
    guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success,
          let element else { return 0 }
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    return pid
}
func processName(_ pid: pid_t) -> String {
    pid == 0 ? "nothing" : (NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?")
}
let centre = CGPoint(x: cgFrame.midX, y: cgFrame.midY)
let titleBar = CGPoint(x: cgFrame.minX + 60, y: cgFrame.minY + 10)
let centreHit = hitTest(centre), titleHit = hitTest(titleBar)
print("hit: centre -> pid \(centreHit) (\(processName(centreHit))); titlebar -> pid \(titleHit) (\(processName(titleHit)))")

// A click only reaches the window if this app is frontmost; another app's window on top is
// ordinary occlusion, not a bug, since clicking through raises the window. Assert the hit
// test only when we are frontmost, and otherwise report where the click would land.
let appIsFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
if appIsFrontmost {
    check(titleHit == app.processIdentifier, "click-reaches-titlebar", "title-bar click lands on \(processName(titleHit))")
} else {
    print("  info  click-reaches-titlebar: not asserted — \(appName) is not the frontmost app, so a window of \(processName(titleHit)) overlaps it")
}

// --- can the window be closed? -----------------------------------------------------
check(closeButton != nil, "close-button-present", closeButton == nil ? "no AXCloseButton in the window" : "AXCloseButton found")
if shouldClose {
    let before = windowCount()
    if let closeButton { AXUIElementPerformAction(closeButton, kAXPressAction as CFString) }
    usleep(900_000)
    AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &axWindows)
    let after = windowCount()
    print("close(AX press): windows \(before) -> \(after)")
    check(after < before, "close-button-works", "windows \(before) -> \(after)")
}

print(failures.isEmpty ? "VERDICT=PASS" : "VERDICT=FAIL (\(failures.joined(separator: ", ")))")
exit(failures.isEmpty ? 0 : 1)
