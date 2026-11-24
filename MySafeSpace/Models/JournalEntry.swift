import Foundation
import SwiftData

/// A journal entry or a quick mood check-in (`isCheckIn == true`).
///
/// PRIVACY: private by default (`isShared == false`). Never indexed in Spotlight, never
/// shown in widgets or notifications. The store lives in Application Support with
/// complete file protection (see `DataProtection`).
@Model
final class JournalEntry {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var text: String = ""
    var moodRaw: Int?
    var emotionsRaw: [String] = []
    var sleepRaw: Int?
    var anxietyRaw: Int?
    var energyRaw: Int?
    var medsTaken: Bool?
    var isCheckIn: Bool = false
    var isShared: Bool = false
    var sharedAt: Date?

    init(
        createdAt: Date = .now,
        text: String = "",
        mood: MoodLevel? = nil,
        emotions: [Emotion] = [],
        isCheckIn: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.text = text
        self.moodRaw = mood?.rawValue
        self.emotionsRaw = emotions.map(\.rawValue)
        self.isCheckIn = isCheckIn
    }

    var mood: MoodLevel? {
        get { moodRaw.flatMap(MoodLevel.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }

    var emotions: [Emotion] {
        get { emotionsRaw.compactMap(Emotion.init(rawValue:)) }
        set { emotionsRaw = newValue.map(\.rawValue) }
    }

    func level(for tag: CheckInTag) -> TagLevel? {
        let raw: Int? = switch tag {
        case .sleep: sleepRaw
        case .anxiety: anxietyRaw
        case .energy: energyRaw
        }
        return raw.flatMap(TagLevel.init(rawValue:))
    }

    func setLevel(_ level: TagLevel?, for tag: CheckInTag) {
        switch tag {
        case .sleep: sleepRaw = level?.rawValue
        case .anxiety: anxietyRaw = level?.rawValue
        case .energy: energyRaw = level?.rawValue
        }
    }

    func setShared(_ shared: Bool) {
        isShared = shared
        sharedAt = shared ? .now : nil
    }

    var insightSample: InsightSample {
        InsightSample(date: createdAt, mood: mood, emotions: emotions, sleep: level(for: .sleep))
    }
}

/// A pre-visit summary the patient explicitly chose to share. Deleting it revokes the share.
@Model
final class SharedSummary {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var recipientName: String = ""
    var periodStart: Date = Date.now
    var periodEnd: Date = Date.now
    /// The exact text that was previewed and shared.
    var content: String = ""
    var entryIDs: [UUID] = []

    init(recipientName: String, periodStart: Date, periodEnd: Date, content: String, entryIDs: [UUID]) {
        self.id = UUID()
        self.createdAt = .now
        self.recipientName = recipientName
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.content = content
        self.entryIDs = entryIDs
    }
}
