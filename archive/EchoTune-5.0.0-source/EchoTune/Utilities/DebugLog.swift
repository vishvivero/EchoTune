//
//  DebugLog.swift
//  EchoTune
//
//  Production-safe logging utility
//

import Foundation

/// Debug-only print — compiles to nothing in Release builds
@inline(__always)
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { String(describing: $0) }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}
