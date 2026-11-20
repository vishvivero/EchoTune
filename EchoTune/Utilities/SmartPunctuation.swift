//
//  SmartPunctuation.swift
//  EchoTune
//
//  Cursor-aware spacing, capitalization, and trailing-punctuation adjustment
//  at insertion time. Mutates only the text being inserted; saved history
//  transcripts remain intact.
//

import ApplicationServices
import Foundation

enum SmartPunctuation {
    struct CursorContext: Equatable, Sendable {
        let before: String
        let after: String
    }

    /// Reads up to 160 characters before and after the current cursor/selection in the focused AX field.
    static func readFocusedContext() -> CursorContext? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        let axElement = unsafeBitCast(focused, to: AXUIElement.self)

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String else {
            return nil
        }

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeVal = rangeRef,
              CFGetTypeID(rangeVal) == AXValueGetTypeID() else {
            return nil
        }
        let axRange = unsafeBitCast(rangeVal, to: AXValue.self)
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axRange, .cfRange, &cfRange) else { return nil }

        let nsRange = NSRange(location: max(0, cfRange.location), length: max(0, cfRange.length))
        guard nsRange.location + nsRange.length <= fullText.utf16.count,
              let swiftRange = Range(nsRange, in: fullText) else {
            return nil
        }

        let before = String(fullText[..<swiftRange.lowerBound].suffix(160))
        let after = String(fullText[swiftRange.upperBound...].prefix(160))
        return CursorContext(before: before, after: after)
    }

    static func adjust(_ text: String, context: CursorContext) -> String {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        guard !trimmed.isEmpty else { return text }

        // Leave structured tokens, code, URLs, emails, and multiline blocks untouched
        if trimmed.contains("\n") || trimmed.contains("`") || trimmed.contains("{")
            || trimmed.contains("@") || trimmed.contains("://") {
            return text
        }

        var result = trimmed
        let beforeTrimmedRight = context.before.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression)

        // 1. Mid-sentence lowercase adjustment (e.g. cursor after "I think that " -> lowercase first word)
        if let prevChar = beforeTrimmedRight.last,
           !".!?\n".contains(prevChar),
           (prevChar.isLetter || prevChar.isNumber || ",;:-—(".contains(prevChar)) {
            result = lowercaseLeadingWordIfAppropriate(result)
        }

        // 2. Avoid duplicate or mid-sentence trailing period when text continues right after cursor
        let afterSameLine = context.after.prefix { $0 != "\n" && $0 != "\r" }
        let afterTrimmedLeft = afterSameLine.drop { $0 == " " || $0 == "\t" }
        if let nextChar = afterTrimmedLeft.first, result.hasSuffix(".") && !result.hasSuffix("..") {
            if ".,;:!?".contains(nextChar) || (nextChar.isLetter && nextChar.isLowercase) {
                result.removeLast()
            }
        }

        // 3. Leading space if cursor sits directly after a word/punctuation without whitespace
        if let leftChar = context.before.last,
           !leftChar.isWhitespace,
           !"([{\"'“‘/".contains(leftChar) {
            result = " " + result
        }

        // 4. Trailing space if cursor sits directly before another word/number
        if let rightChar = context.after.first,
           (rightChar.isLetter || rightChar.isNumber) {
            result += " "
        }

        return result
    }

    private static func lowercaseLeadingWordIfAppropriate(_ text: String) -> String {
        let firstWord = String(text.prefix { $0.isLetter || $0 == "'" })
        guard !firstWord.isEmpty else { return text }

        // Keep "I", "I'm", "I've", "I'll", "I'd" and ALL-CAPS acronyms ("API", "UK") uppercase
        if firstWord == "I" || firstWord.hasPrefix("I'") || firstWord.hasPrefix("I’") {
            return text
        }
        let lettersOnly = firstWord.filter(\.isLetter)
        if lettersOnly.count >= 2 && lettersOnly.allSatisfy(\.isUppercase) {
            return text
        }

        guard let firstIdx = text.firstIndex(where: \.isLetter), firstIdx == text.startIndex else {
            return text
        }
        var copy = text
        copy.replaceSubrange(firstIdx...firstIdx, with: String(copy[firstIdx]).lowercased())
        return copy
    }
}
