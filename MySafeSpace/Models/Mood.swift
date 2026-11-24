import Foundation

/// Five-step mood scale. Labels are descriptive and never judgemental.
nonisolated enum MoodLevel: Int, CaseIterable, Identifiable, Codable, Sendable {
    case veryLow = 1, low, okay, good, great

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .veryLow: String(localized: "Bad", comment: "Mood level 1")
        case .low: String(localized: "Low", comment: "Mood level 2")
        case .okay: String(localized: "Okay", comment: "Mood level 3")
        case .good: String(localized: "Good", comment: "Mood level 4")
        case .great: String(localized: "Great", comment: "Mood level 5")
        }
    }

    /// 0 (hardest) … 1 (brightest); drives the morphing character.
    var progress: Double { Double(rawValue - 1) / 4 }

    init(progress: Double) {
        let step = Int((min(max(progress, 0), 1) * 4).rounded())
        self = MoodLevel(rawValue: step + 1) ?? .okay
    }
}

/// Specific feelings (the "general mood → specific feeling" step).
nonisolated enum Emotion: String, CaseIterable, Identifiable, Codable, Sendable {
    case calm, grateful, hopeful, content, proud, connected
    case tired, anxious, sad, lonely, angry, irritable, numb, overwhelmed, ashamed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: String(localized: "Calm")
        case .grateful: String(localized: "Grateful")
        case .hopeful: String(localized: "Hopeful")
        case .content: String(localized: "Content")
        case .proud: String(localized: "Proud")
        case .connected: String(localized: "Connected")
        case .tired: String(localized: "Tired")
        case .anxious: String(localized: "Anxious")
        case .sad: String(localized: "Sad")
        case .lonely: String(localized: "Lonely")
        case .angry: String(localized: "Angry")
        case .irritable: String(localized: "Irritable")
        case .numb: String(localized: "Numb")
        case .overwhelmed: String(localized: "Overwhelmed")
        case .ashamed: String(localized: "Ashamed")
        }
    }

    var isPleasant: Bool {
        switch self {
        case .calm, .grateful, .hopeful, .content, .proud, .connected: true
        default: false
        }
    }

    /// Feelings ordered so the most likely ones for this mood come first.
    /// Every feeling stays available — people can feel hopeful on a hard day.
    static func suggested(for mood: MoodLevel) -> [Emotion] {
        let pleasant = allCases.filter(\.isPleasant)
        let unpleasant = allCases.filter { !$0.isPleasant }
        return mood.rawValue >= 4 ? pleasant + unpleasant : unpleasant + pleasant
    }
}

/// Optional check-in tags.
nonisolated enum CheckInTag: String, CaseIterable, Identifiable, Sendable {
    case sleep, anxiety, energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: String(localized: "Sleep")
        case .anxiety: String(localized: "Anxiety")
        case .energy: String(localized: "Energy")
        }
    }

    var systemImage: String {
        switch self {
        case .sleep: "moon.zzz"
        case .anxiety: "waveform.path"
        case .energy: "bolt.heart"
        }
    }

    func label(for level: TagLevel) -> String {
        switch (self, level) {
        case (.sleep, .low): String(localized: "Short or poor", comment: "Sleep quality")
        case (.sleep, .medium): String(localized: "Okay", comment: "Sleep quality")
        case (.sleep, .high): String(localized: "Rested", comment: "Sleep quality")
        case (.anxiety, .low): String(localized: "Low", comment: "Anxiety level")
        case (.anxiety, .medium): String(localized: "Some", comment: "Anxiety level")
        case (.anxiety, .high): String(localized: "High", comment: "Anxiety level")
        case (.energy, .low): String(localized: "Low", comment: "Energy level")
        case (.energy, .medium): String(localized: "Medium", comment: "Energy level")
        case (.energy, .high): String(localized: "High", comment: "Energy level")
        }
    }
}

nonisolated enum TagLevel: Int, CaseIterable, Identifiable, Codable, Sendable {
    case low = 1, medium, high
    var id: Int { rawValue }
}
