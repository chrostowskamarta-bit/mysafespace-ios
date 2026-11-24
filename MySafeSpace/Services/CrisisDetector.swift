import Foundation

nonisolated enum CrisisCategory: String, Sendable, CaseIterable {
    case selfHarm
    case harmToOthers
}

nonisolated enum CrisisConfidence: Int, Comparable, Sendable {
    case none = 0, low, medium, high
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

nonisolated struct CrisisAssessment: Equatable, Sendable {
    var category: CrisisCategory?
    var confidence: CrisisConfidence
    var matchedPhrases: [String]

    static let none = CrisisAssessment(category: nil, confidence: .none, matchedPhrases: [])

    /// Full-screen crisis support (on save / send).
    var shouldShowFullScreenSupport: Bool { confidence >= .medium }
    /// Gentle inline support card (while typing, or after a negated match).
    var shouldShowGentleSupport: Bool { confidence >= .low }
}

/// Detects language that may signal risk. Runs ON DEVICE ONLY — nothing leaves the phone
/// as a result of detection unless the patient opted in to Safety alerts (flag only, never text).
nonisolated protocol CrisisDetector: Sendable {
    func assess(_ text: String) -> CrisisAssessment
}

/// Keyword/phrase matcher with normalisation, light stemming and basic negation awareness.
/// It deliberately errs on the side of offering support.
nonisolated struct OnDeviceCrisisDetector: CrisisDetector {

    struct Phrase: Sendable {
        let display: String
        let tokens: [String]
        let category: CrisisCategory
        let weight: CrisisConfidence
    }

    // CLINICAL REVIEW REQUIRED: this lexicon is a placeholder written by the product team.
    // It must be validated (and extended, incl. Polish) by psychiatrists before production.
    static let selfHarmLexicon: [(String, CrisisConfidence)] = [
        ("kill myself", .high), ("end my life", .high), ("end it all", .high),
        ("take my own life", .high), ("take my life", .high), ("end myself", .high),
        ("want to die", .high), ("want to be dead", .high), ("wish i was dead", .high),
        ("wish i were dead", .high), ("better off dead", .high), ("rather be dead", .high),
        ("better off without me", .high), ("no reason to live", .high), ("nothing to live for", .high),
        ("dont want to live", .high), ("dont want to be alive", .high),
        ("dont want to be here anymore", .high), ("dont want to exist", .high),
        ("cant go on", .high), ("never wake up", .high),
        ("hurt myself", .high), ("harm myself", .high), ("cut myself", .high), ("self harm", .high),
        ("suicid*", .medium), ("overdos*", .medium),
    ]

    // CLINICAL REVIEW REQUIRED
    static let harmToOthersLexicon: [(String, CrisisConfidence)] = [
        ("kill him", .high), ("kill her", .high), ("kill them", .high),
        ("kill someone", .high), ("kill somebody", .high), ("kill everyone", .high),
        ("hurt someone", .high), ("hurt somebody", .high), ("hurt him", .high),
        ("hurt her", .high), ("hurt them", .high), ("hurt people", .high),
        ("harm someone", .high), ("harm him", .high), ("harm her", .high), ("harm them", .high),
    ]

    /// Words that, shortly before a match, suggest the writer is denying it ("I would never…").
    static let negators: Set<String> = ["not", "never", "no", "dont", "wont", "wouldnt", "didnt", "isnt", "arent"]
    /// Words that cancel a preceding negator ("can't stop", "can't help").
    /// Clause boundaries ("|", "and", "but") also end the backward scan: "I am not okay, I want to die".
    static let negationBreakers: Set<String> = ["stop", "help", "and", "but", clauseBoundary]
    static let clauseBoundary = "|"
    static let negationWindow = 3
    static let maxGap = 1

    private let phrases: [Phrase]

    init() {
        func build(_ lexicon: [(String, CrisisConfidence)], _ category: CrisisCategory) -> [Phrase] {
            lexicon.map { text, weight in
                let tokens = text.split(separator: " ").map { word -> String in
                    let w = String(word)
                    return w.hasSuffix("*") ? w : Self.stem(w)
                }
                return Phrase(display: text, tokens: tokens, category: category, weight: weight)
            }
        }
        phrases = build(Self.selfHarmLexicon, .selfHarm) + build(Self.harmToOthersLexicon, .harmToOthers)
    }

    func assess(_ text: String) -> CrisisAssessment {
        let tokens = Self.tokenize(text)
        guard !tokens.isEmpty else { return .none }

        var best = CrisisAssessment.none
        for phrase in phrases {
            for start in Self.matchStarts(of: phrase.tokens, in: tokens) {
                let confidence: CrisisConfidence = Self.isNegated(tokens, before: start) ? .low : phrase.weight
                if confidence > best.confidence {
                    best = CrisisAssessment(category: phrase.category, confidence: confidence, matchedPhrases: [phrase.display])
                } else if confidence == best.confidence, !best.matchedPhrases.contains(phrase.display) {
                    best.matchedPhrases.append(phrase.display)
                }
            }
        }
        return best
    }

    // MARK: Normalisation

    static func tokenize(_ text: String) -> [String] {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "[’‘'`´]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[.,;:!?\n]", with: " \(clauseBoundary) ", options: .regularExpression)
        return folded
            .split { !($0.isLetter || $0.isNumber || $0 == "|") }
            .map { stem(String($0)) }
    }

    static let irregulars: [String: String] = [
        "dying": "die", "died": "die", "dies": "die", "dead": "dead",
        "cutting": "cut", "lives": "live", "living": "live", "lived": "live",
        "hurts": "hurt", "hurting": "hurt",
    ]

    /// Very light suffix stripping — applied identically to text and lexicon.
    static func stem(_ token: String) -> String {
        if let irregular = irregulars[token] { return irregular }
        for suffix in ["ing", "ed", "s"] where token.hasSuffix(suffix) && token.count >= suffix.count + 3 {
            return String(token.dropLast(suffix.count))
        }
        return token
    }

    // MARK: Matching

    static func tokenMatches(_ pattern: String, _ token: String) -> Bool {
        if pattern.hasSuffix("*") { return token.hasPrefix(String(pattern.dropLast())) }
        return pattern == token
    }

    /// Start indices where the phrase occurs in order, allowing up to `maxGap` filler words
    /// between consecutive phrase words ("want to just die").
    static func matchStarts(of pattern: [String], in tokens: [String]) -> [Int] {
        guard let first = pattern.first else { return [] }
        var starts: [Int] = []
        for index in tokens.indices where tokenMatches(first, tokens[index]) {
            var position = index
            var matched = true
            for word in pattern.dropFirst() {
                let upper = min(tokens.count - 1, position + 1 + maxGap)
                guard position + 1 <= upper,
                      let found = (position + 1...upper).first(where: { tokenMatches(word, tokens[$0]) }) else {
                    matched = false
                    break
                }
                position = found
            }
            if matched { starts.append(index) }
        }
        return starts
    }

    static func isNegated(_ tokens: [String], before start: Int) -> Bool {
        var index = start - 1
        var steps = 0
        while index >= 0 && steps < negationWindow {
            let token = tokens[index]
            if negationBreakers.contains(token) { return false }
            if negators.contains(token) { return true }
            index -= 1
            steps += 1
        }
        return false
    }
}
