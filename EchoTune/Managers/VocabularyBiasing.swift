//
//  VocabularyBiasing.swift
//  EchoTune
//
//  Builds decode-time vocabulary prompts from the user's dictionary and
//  learned corrections. Post-hoc dictionary processing remains the safety net.
//

import Foundation
import os.log

struct VocabularyBiasing {
    /// Whisper's prompt context budget. Keep this below the model's 224-token
    /// limit so the decoder retains room for its own prefill tokens.
    static let maxPromptTokens = 224

    struct Entry: Equatable {
        let term: String
        let aliases: [String]
    }

    private static let logger = OSLog(subsystem: "com.echotune", category: "VocabularyBiasing")
    private static var didLogPromptTrim = false

    /// Collect canonical written forms from the dictionary and corrections
    /// that have crossed CorrectionLearner's existing three-strike threshold.
    static func terms(
        dictionary: DictionaryManager,
        learner: CorrectionLearner,
        appTerms: [String] = ["EchoTune"]
    ) -> [String] {
        entries(dictionary: dictionary, learner: learner, appTerms: appTerms).map(\.term)
    }

    /// Collect canonical terms and learned spoken aliases for engines that
    /// support context-vocabulary rescoring.
    static func entries(
        dictionary: DictionaryManager,
        learner: CorrectionLearner,
        appTerms: [String] = ["EchoTune"]
    ) -> [Entry] {
        var raw: [Entry] = []
        raw.append(contentsOf: dictionary.wordReplacements
            .filter(\.isEnabled)
            .map { Entry(term: $0.writtenForm, aliases: [$0.spokenForm]) })
        raw.append(contentsOf: dictionary.correctSpellings
            .filter(\.isEnabled)
            .map { Entry(term: $0.word, aliases: $0.variations) })
        raw.append(contentsOf: learner.suggestions.map {
            Entry(term: $0.written, aliases: [$0.spoken])
        })
        raw.append(contentsOf: appTerms.map { Entry(term: $0, aliases: []) })

        var seen = Set<String>()
        return raw.compactMap { entry in
            let term = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else { return nil }
            let key = term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(key).inserted else { return nil }
            let aliases = entry.aliases
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return Entry(term: term, aliases: aliases)
        }
    }

    /// Keep terms plausible for the current language while never returning an
    /// empty vocabulary solely because the heuristic did not understand a
    /// user-provided spelling.
    static func filterByLanguage(_ terms: [String], language: String?) -> [String] {
        guard let language = language?.lowercased(), !language.isEmpty else { return terms }
        let script = language.components(separatedBy: "-").first ?? language
        let filtered = terms.filter { term in
            let scalars = term.unicodeScalars.filter {
                CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
            }
            guard !scalars.isEmpty else { return true }
            if ["zh", "ja", "ko"].contains(script) {
                return scalars.contains { isCJK($0) } || !scalars.contains { isCyrillic($0) || isArabic($0) }
            }
            if ["ru", "uk", "bg", "sr", "mk"].contains(script) {
                return scalars.contains(where: isCyrillic)
            }
            if ["ar", "fa", "ur"].contains(script) {
                return scalars.contains(where: isArabic)
            }
            // Latin-language dictionaries should not be polluted by terms
            // written exclusively in another script. Mixed-script product
            // names remain eligible because they contain Latin characters.
            return scalars.contains(where: isLatin) && !scalars.allSatisfy { isCyrillic($0) || isArabic($0) || isCJK($0) }
        }
        return filtered.isEmpty ? terms : filtered
    }

    /// Encodes terms in stable order and stops before crossing the prompt
    /// budget. A leading space matches WhisperKit's normal word-tokenization
    /// convention. Empty input returns an empty array so callers pass nil.
    static func promptTokens(
        for terms: [String],
        language: String?,
        encode: (String) -> [Int]
    ) -> [Int] {
        _ = language
        guard !terms.isEmpty else { return [] }
        var output: [Int] = []
        var dropped = 0
        for term in terms {
            let encoded = encode(" " + term)
            guard !encoded.isEmpty else { continue }
            guard output.count + encoded.count <= maxPromptTokens else {
                dropped += 1
                continue
            }
            output.append(contentsOf: encoded)
        }
        if dropped > 0, !didLogPromptTrim {
            didLogPromptTrim = true
            os_log("Vocabulary prompt capped at %d tokens; dropped %d terms", log: logger, type: .info, maxPromptTokens, dropped)
        }
        return output
    }

    private static func isLatin(_ scalar: Unicode.Scalar) -> Bool {
        (0x0041...0x024F).contains(Int(scalar.value))
    }

    private static func isCyrillic(_ scalar: Unicode.Scalar) -> Bool {
        (0x0400...0x052F).contains(Int(scalar.value))
    }

    private static func isArabic(_ scalar: Unicode.Scalar) -> Bool {
        (0x0600...0x06FF).contains(Int(scalar.value))
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        (0x3040...0x30FF).contains(Int(scalar.value))
            || (0x3400...0x9FFF).contains(Int(scalar.value))
    }
}
