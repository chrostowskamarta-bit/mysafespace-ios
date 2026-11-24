import Foundation

/// A storage-independent view of a journal entry, so insights are pure and testable.
nonisolated struct InsightSample: Sendable {
    let date: Date
    let mood: MoodLevel?
    let emotions: [Emotion]
    let sleep: TagLevel?
}

/// Descriptive, non-judgemental weekly reflections. Never a score, never a streak.
nonisolated struct WeekInsights: Equatable, Sendable {
    enum Trend: Equatable, Sendable { case lighter, similar, heavier }

    var daysWithMood: Int
    var harderDays: Int
    var lighterDays: Int
    var topEmotions: [Emotion]
    var shortSleepDays: Int
    var trend: Trend?

    var sentences: [String] {
        guard daysWithMood > 0 || !topEmotions.isEmpty else {
            return [String(localized: "No check-ins this week – that's completely okay. This space is here whenever you need it.")]
        }
        var result: [String] = []
        switch harderDays {
        case 0: break
        case 1: result.append(String(localized: "This week you had one harder day."))
        default: result.append(String(localized: "This week you had \(harderDays) harder days."))
        }
        switch lighterDays {
        case 0: break
        case 1: result.append(String(localized: "There was also a lighter day."))
        default: result.append(String(localized: "There were also \(lighterDays) lighter days."))
        }
        if shortSleepDays >= 3 {
            result.append(String(localized: "Sleep was often short."))
        } else if shortSleepDays > 0 {
            result.append(String(localized: "Sleep was short on \(shortSleepDays) nights."))
        }
        if let top = topEmotions.first {
            result.append(String(localized: "The feeling you named most often was “\(top.label.lowercased())”."))
        }
        switch trend {
        case .lighter: result.append(String(localized: "Overall, this week seemed a little lighter than the one before."))
        case .heavier: result.append(String(localized: "This week seemed heavier than the one before. It might be worth mentioning at your next visit."))
        case .similar: result.append(String(localized: "This week felt similar to the one before."))
        case nil: break
        }
        return result
    }
}

nonisolated enum JournalInsights {

    /// One mood per day: the rounded average of that day's moods.
    static func dailyMoods(_ samples: [InsightSample], calendar: Calendar = .clinic) -> [Date: MoodLevel] {
        var buckets: [Date: [Int]] = [:]
        for sample in samples {
            guard let mood = sample.mood else { continue }
            buckets[calendar.startOfDay(for: sample.date), default: []].append(mood.rawValue)
        }
        return buckets.mapValues { values in
            let average = Double(values.reduce(0, +)) / Double(values.count)
            return MoodLevel(rawValue: Int(average.rounded())) ?? .okay
        }
    }

    /// The 7 days ending on `end` (inclusive), compared with the 7 days before.
    static func week(_ samples: [InsightSample], endingOn end: Date, calendar: Calendar = .clinic) -> WeekInsights {
        let endDay = calendar.startOfDay(for: end)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: endDay),
              let windowEnd = calendar.date(byAdding: .day, value: 1, to: endDay),
              let previousStart = calendar.date(byAdding: .day, value: -7, to: windowStart) else {
            return WeekInsights(daysWithMood: 0, harderDays: 0, lighterDays: 0, topEmotions: [], shortSleepDays: 0, trend: nil)
        }

        let current = samples.filter { $0.date >= windowStart && $0.date < windowEnd }
        let previous = samples.filter { $0.date >= previousStart && $0.date < windowStart }

        let daily = dailyMoods(current, calendar: calendar)
        let harder = daily.values.filter { $0.rawValue <= 2 }.count
        let lighter = daily.values.filter { $0.rawValue >= 4 }.count

        var counts: [Emotion: Int] = [:]
        for emotion in current.flatMap(\.emotions) { counts[emotion, default: 0] += 1 }
        let top = counts.sorted { lhs, rhs in
            lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key.rawValue < rhs.key.rawValue
        }.prefix(3).map(\.key)

        let shortSleepDays = Set(current.filter { $0.sleep == .low }.map { calendar.startOfDay(for: $0.date) }).count

        var trend: WeekInsights.Trend?
        let previousDaily = dailyMoods(previous, calendar: calendar)
        if !daily.isEmpty, !previousDaily.isEmpty {
            let now = average(daily.values.map(\.rawValue))
            let before = average(previousDaily.values.map(\.rawValue))
            let delta = now - before
            trend = delta > 0.4 ? .lighter : (delta < -0.4 ? .heavier : .similar)
        }

        return WeekInsights(
            daysWithMood: daily.count,
            harderDays: harder,
            lighterDays: lighter,
            topEmotions: Array(top),
            shortSleepDays: shortSleepDays,
            trend: trend
        )
    }

    private static func average(_ values: [Int]) -> Double {
        values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }
}
