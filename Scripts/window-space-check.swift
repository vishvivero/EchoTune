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
//  plus the private Spaces membership (which Space the window is in, and its type).
//
//  Usage: window-space-check <appName> [--close]
//  Exit status 0 = PASS, 1 = FAIL.
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
let copyManagedDisplaySpaces = sym("CGSCopyManagedDisplaySpaces") as (@convention(c) (CID) -> Unmanaged<CFArray>?)?
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

let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.echotune.EchoTune").first
    ?? NSWorkspace.shared.runningApplications.first { $0.localizedName == appName }
guard let app else { print("FAIL: \(appName) is not running"); exit(1) }
print("app=\(appName) pid=\(app.processIdentifier) policy=\(app.activationPolicy.rawValue) active=\(app.isActive)")

let (activeID, activeType) = activeSpace()
print("active_space=\(activeID)[\(typeName(activeType))]")

// --- find the app's standard windows -----------------------------------------------
let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
let owned = windowList.filter { ($0["kCGWindowOwnerPID"] as? Int) == Int(app.processIdentifier) }
let windowNumberByTitle: [String: Int] = owned.reduce(into: [:]) { partial, entry in
    guard let number = entry["kCGWindowNumber"] as? Int,
          let title = entry["kCGWindowName"] as? String, !title.isEmpty,
          (entry["kCGWindowBounds"] as? [String: CGFloat]).map({ $0["Width"]! > 200 }) ?? false
    else { return }
    partial[title] = number
}

guard let number = windowNumberByTitle["EchoTune"] ?? windowNumberByTitle.values.first else {
    check(false, "window-exists", "no EchoTune standard window is registered with WindowServer")
    print("VERDICT=FAIL"); exit(1)
}

// --- WindowServer frame vs the frame AppKit reports -------------------------------
let entry = owned.first { ($0["kCGWindowNumber"] as? Int) == number }!
let bounds = entry["kCGWindowBounds"] as! [String: CGFloat]
let cgFrame = CGRect(x: bounds["X"]!, y: bounds["Y"]!, width: bounds["Width"]!, height: bounds["Height"]!)
let onScreen = entry["kCGWindowIsOnscreen"] != nil

let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
var axWindows: CFTypeRef?
AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &axWindows)
var axFrame: CGRect?
var closeButton: AXUIElement?
var axTitle = ""
for raw in (axWindows as? [AXUIElement]) ?? [] {
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(raw, kAXTitleAttribute as CFString, &titleValue)
    let title = (titleValue as? String) ?? ""
    var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
    AXUIElementCopyAttributeValue(raw, kAXPositionAttribute as CFString, &positionValue)
    AXUIElementCopyAttributeValue(raw, kAXSizeAttribute as CFString, &sizeValue)
    guard let positionValue, let sizeValue else { continue }
    var origin = CGPoint.zero, size = CGSize.zero
    AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    if size.width > 200, axFrame == nil {
        axFrame = CGRect(origin: origin, size: size)
        axTitle = title
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(raw, kAXChildrenAttribute as CFString, &children)
        for child in (children as? [AXUIElement]) ?? [] {
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXSubroleAttribute as CFString, &subrole)
            if (subrole as? String) == kAXCloseButtonSubrole as String { closeButton = child }
        }
    }
}

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

// --- hit testing: which app does a click reach? ----------------------------------
func hitTest(_ point: CGPoint) -> pid_t {
    var element: AXUIElement?
    guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element) == .success,
          let element else { return 0 }
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    return pid
}
let centre = CGPoint(x: cgFrame.midX, y: cgFrame.midY)
let titleBar = CGPoint(x: cgFrame.minX + 60, y: cgFrame.minY + 10)
let centreHit = hitTest(centre), titleHit = hitTest(titleBar)
print("hit: centre -> pid \(centreHit) (\(NSRunningApplication(processIdentifier: centreHit)?.localizedName ?? "?")); titlebar -> pid \(titleHit) (\(NSRunningApplication(processIdentifier: titleHit)?.localizedName ?? "?"))")
check(centreHit == app.processIdentifier, "click-reaches-window", "centre click lands on \(NSRunningApplication(processIdentifier: centreHit)?.localizedName ?? "nothing")")

// --- can the window be closed? --------------------------------------------------
check(closeButton != nil, "close-button-present", closeButton == nil ? "no AXCloseButton in the window" : "AXCloseButton found")
if shouldClose {
    let windowCountBefore = ((axWindows as? [AXUIElement]) ?? []).count
    if let closeButton { AXUIElementPerformAction(closeButton, kAXPressAction as CFString) }
    usleep(900_000)
    var after: CFTypeRef?
    AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &after)
    let windowCountAfter = ((after as? [AXUIElement]) ?? []).count
    print("close: windows \(windowCountBefore) -> \(windowCountAfter)")
    check(windowCountAfter < windowCountBefore, "close-button-works", "windows \(windowCountBefore) -> \(windowCountAfter)")
}

print(failures.isEmpty ? "VERDICT=PASS" : "VERDICT=FAIL (\(failures.joined(separator: ", ")))")
exit(failures.isEmpty ? 0 : 1)
