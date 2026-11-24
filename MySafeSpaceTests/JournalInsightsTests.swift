import Foundation
import Testing
@testable import MySafeSpace

@Suite("Journal insights")
struct JournalInsightsTests {
    let calendar = Calendar.clinic
    let end: Date

    init() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 15
        components.hour = 12
        end = Calendar.clinic.date(from: components)!
    }

    private func sample(daysAgo: Int, mood: MoodLevel?, emotions: [Emotion] = [], sleep: TagLevel? = nil) -> InsightSample {
        InsightSample(date: calendar.date(byAdding: .day, value: -daysAgo, to: end)!, mood: mood, emotions: emotions, sleep: sleep)
    }

    @Test func countsHarderAndLighterDays() {
        let samples = [
            sample(daysAgo: 0, mood: .low),
            sample(daysAgo: 1, mood: .veryLow),
            sample(daysAgo: 2, mood: .good),
            sample(daysAgo: 3, mood: .okay),
            sample(daysAgo: 4, mood: .low),
            sample(daysAgo: 10, mood: .great), // outside the window
        ]
        let week = JournalInsights.week(samples, endingOn: end)
        #expect(week.harderDays == 3)
        #expect(week.lighterDays == 1)
        #expect(week.daysWithMood == 5)
    }

    @Test func averagesMultipleEntriesPerDay() {
        let samples = [sample(daysAgo: 0, mood: .veryLow), sample(daysAgo: 0, mood: .great)]
        let daily = JournalInsights.dailyMoods(samples)
        #expect(daily[calendar.startOfDay(for: end)] == .okay)
    }

    @Test func topEmotionsAreOrderedByFrequency() {
        let samples = [
            sample(daysAgo: 0, mood: nil, emotions: [.anxious, .tired]),
            sample(daysAgo: 1, mood: nil, emotions: [.anxious]),
            sample(daysAgo: 2, mood: nil, emotions: [.calm, .anxious, .tired]),
        ]
        #expect(JournalInsights.week(samples, endingOn: end).topEmotions == [.anxious, .tired, .calm])
    }

    @Test func shortSleepCountsDistinctDays() {
        let samples = [
            sample(daysAgo: 0, mood: nil, sleep: .low),
            sample(daysAgo: 0, mood: nil, sleep: .low),
            sample(daysAgo: 1, mood: nil, sleep: .low),
            sample(daysAgo: 2, mood: nil, sleep: .high),
        ]
        #expect(JournalInsights.week(samples, endingOn: end).shortSleepDays == 2)
    }

    @Test func trendComparesWithThePreviousWeek() {
        let samples = [
            sample(daysAgo: 1, mood: .good), sample(daysAgo: 2, mood: .great),
            sample(daysAgo: 8, mood: .low), sample(daysAgo: 9, mood: .veryLow),
        ]
        #expect(JournalInsights.week(samples, endingOn: end).trend == .lighter)
    }

    @Test func emptyWeekIsReassuringNotPunitive() {
        let sentences = JournalInsights.week([], endingOn: end).sentences
        #expect(sentences.count == 1)
        #expect(!sentences[0].localizedCaseInsensitiveContains("missed"))
        #expect(!sentences[0].localizedCaseInsensitiveContains("failed"))
    }

    @Test func sentencesNeverContainScores() {
        let samples = (0..<7).map { sample(daysAgo: $0, mood: .low, emotions: [.sad], sleep: .low) }
        let text = JournalInsights.week(samples, endingOn: end).sentences.joined(separator: " ")
        #expect(!text.contains("%"))
        #expect(!text.localizedCaseInsensitiveContains("score"))
        #expect(!text.localizedCaseInsensitiveContains("streak"))
    }
}
