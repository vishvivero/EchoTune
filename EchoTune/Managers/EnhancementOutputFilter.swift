import Foundation

/// Normalizes model wrappers at the single enhancement return boundary.
/// Provider prompts remain responsible for model behavior; this only removes
/// transport/reasoning wrappers that are never useful in inserted text.
enum EnhancementOutputFilter {
    static func clean(_ raw: String, stripMarkdownFences: Bool = true) -> String {
        guard stripMarkdownFences else { return raw }

        var value = removeReasoningBlocks(from: raw)
        value = removeMarkdownFenceLines(from: value)
        value = removeLeadingLabel(from: value)
        value = collapseBlankLines(value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        value = removeOuterQuotes(from: value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapseBlankLines(value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeReasoningBlocks(from value: String) -> String {
        // Reasoning models commonly emit <think>...</think>,
        // <thinking>...</thinking>, or <reasoning>...</reasoning>. Match only
        // paired tags whose name identifies reasoning; ordinary XML-like text
        // is left untouched.
        let pattern = #"(?is)<\s*(reasoning|thinking|think|reason)\b[^>]*>.*?</\s*\1\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "")
    }

    private static func removeMarkdownFenceLines(from value: String) -> String {
        // Remove opening markers (including an optional language marker) and
        // closing markers while retaining all fenced content. The prefix match
        // also handles "Output: ```markdown" on one line.
        var result = value
        let opening = #"(?m)(^|\n)([^\n]*?)```[A-Za-z0-9_+.-]*[ \t]*(?:\r?\n|$)"#
        if let regex = try? NSRegularExpression(pattern: opening) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1$2")
        }
        let closing = #"(?m)^[ \t]*```[ \t]*$"#
        if let regex = try? NSRegularExpression(pattern: closing) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        // Handles one-line fences and any marker left after an unterminated
        // or inline fence. Single-backtick inline code is never touched.
        return result.replacingOccurrences(of: "```", with: "")
    }

    private static func removeLeadingLabel(from value: String) -> String {
        let pattern = #"(?is)^\s*(?:polished|output|result)\s*:\s*|^\s*here\s+is\s+(?:the\s+)?polished\s+text\s*:\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "")
    }

    private static func collapseBlankLines(_ value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\n{3,}"#) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "\n\n")
    }

    private static func removeOuterQuotes(from value: String) -> String {
        guard value.count >= 2 else { return value }
        let pairs: [(Character, Character)] = [("\"", "\""), ("'", "'"), ("“", "”"), ("‘", "’")]
        guard let first = value.first, let last = value.last,
              pairs.contains(where: { $0.0 == first && $0.1 == last }) else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }
}
