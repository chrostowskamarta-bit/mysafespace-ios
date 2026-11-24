import Testing
@testable import MySafeSpace

@Suite("Crisis detector")
struct CrisisDetectorTests {
    let detector = OnDeviceCrisisDetector()

    // MARK: True positives → full-screen support

    @Test(arguments: [
        "I want to kill myself",
        "Sometimes I think everyone would be better off without me.",
        "I don't want to live anymore",
        "I don’t want to be alive",                      // curly apostrophe
        "I've been thinking about suicide a lot",
        "I feel suicidal tonight",
        "I keep wanting to hurt myself",
        "There's no reason to live",
        "I just want to end it all",
        "I wish I were dead",
        "I WANT TO DIE",                                 // case folding
        "i just want to die",                            // one filler word
        "I can't stop thinking about killing myself",   // 'can't stop' is not a negation
        "I'm not okay, I want to die",                  // negation doesn't cross a clause
        "Tired of everything and I want to die",
        "I thought about taking an overdose",
    ])
    func selfHarmIsDetected(_ text: String) {
        let result = detector.assess(text)
        #expect(result.category == .selfHarm, "\(text)")
        #expect(result.shouldShowFullScreenSupport, "\(text)")
    }

    @Test(arguments: [
        "I'm so angry I could hurt someone",
        "Sometimes I want to kill him",
        "I'm scared I'll hurt them",
    ])
    func harmToOthersIsDetected(_ text: String) {
        let result = detector.assess(text)
        #expect(result.category == .harmToOthers, "\(text)")
        #expect(result.shouldShowFullScreenSupport, "\(text)")
    }

    // MARK: Obvious negatives

    @Test(arguments: [
        "Had a lovely walk in the park with Kasia.",
        "My headache is killing me",
        "I killed it at my presentation today",
        "I'm dying to see the new film",
        "Couldn't sleep, worried about the deadline.",
        "Session with Michał helped a lot.",
        "",
        "   ",
    ])
    func everydayLanguageIsNotFlagged(_ text: String) {
        let result = detector.assess(text)
        #expect(result.confidence == .none, "\(text)")
        #expect(!result.shouldShowGentleSupport, "\(text)")
    }

    // MARK: Negation lowers confidence but still offers gentle support

    @Test(arguments: [
        "I would never hurt myself",
        "I'm not suicidal, just exhausted",
        "I have no plans to hurt myself",
    ])
    func negationLowersConfidence(_ text: String) {
        let result = detector.assess(text)
        #expect(result.confidence == .low, "\(text)")
        #expect(!result.shouldShowFullScreenSupport, "\(text)")
        #expect(result.shouldShowGentleSupport, "\(text)")
    }

    @Test func unnegatedMatchWinsOverNegatedOne() {
        let result = detector.assess("I would never hurt myself. But lately I want to die.")
        #expect(result.confidence == .high)
    }

    // MARK: Normalisation

    @Test func diacriticsAndPunctuationAreNormalised() {
        #expect(OnDeviceCrisisDetector.tokenize("Gęś, DON'T!") == ["ges", "|", "dont", "|"])
    }

    @Test func stemmingIsConsistent() {
        #expect(OnDeviceCrisisDetector.stem("killing") == "kill")
        #expect(OnDeviceCrisisDetector.stem("wanted") == "want")
        #expect(OnDeviceCrisisDetector.stem("dying") == "die")
        #expect(OnDeviceCrisisDetector.stem("die") == "die")
    }
}
