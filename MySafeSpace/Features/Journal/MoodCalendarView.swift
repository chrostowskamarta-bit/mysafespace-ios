import SwiftUI
import SwiftData

/// Month grid of mood faces + gentle, descriptive weekly reflections. No scores, no streaks.
struct MoodCalendarView: View {
    let entries: [JournalEntry]
    let onOpen: (JournalEntry) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var month = Date.now
    @State private var selectedDay = Calendar.clinic.startOfDay(for: .now)

    private var calendar: Calendar { .clinic }

    private var samples: [InsightSample] { entries.map(\.insightSample) }
    private var dailyMoods: [Date: MoodLevel] { JournalInsights.dailyMoods(samples) }
    private var week: WeekInsights { JournalInsights.week(samples, endingOn: .now) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                weekCard
                bento
                calendarCard
                dayEntries
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: This week

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Your week")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(week.sentences, id: \.self) { sentence in
                Text(sentence)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            weekStrip
        }
        .card()
    }

    /// Last 7 days as faces (or an empty ring) — a gentle trend, not a chart to "beat".
    private var weekStrip: some View {
        let today = calendar.startOfDay(for: .now)
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        return HStack(spacing: Spacing.xxs) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: 4) {
                    if let mood = dailyMoods[day] {
                        MoodFace(level: mood, size: 34)
                    } else {
                        Circle()
                            .strokeBorder(Color.inkSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            .frame(width: 30, height: 30)
                            .padding(2)
                            .accessibilityLabel(Text("No check-in"))
                    }
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.caption2)
                        .foregroundStyle(Color.inkSecondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, Spacing.xs)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var bento: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        return LazyVGrid(columns: columns, spacing: Spacing.s) {
            BentoCard(
                title: "Feelings you named",
                value: week.topEmotions.isEmpty ? String(localized: "None yet") : week.topEmotions.map(\.label).joined(separator: ", "),
                systemImage: "text.bubble",
                fill: .mood2
            )
            BentoCard(
                title: "Sleep",
                value: week.shortSleepDays >= 3
                    ? String(localized: "Often short")
                    : week.shortSleepDays > 0 ? String(localized: "Short on \(week.shortSleepDays) nights") : String(localized: "No short nights noted"),
                systemImage: "moon.zzz",
                fill: .mood5
            )
        }
    }

    // MARK: Month

    private var calendarCard: some View {
        VStack(spacing: Spacing.s) {
            MonthHeader(month: $month)
            MonthGrid(month: month) { day in
                dayCell(day)
            }
        }
        .card(padding: Spacing.s)
    }

    private func dayCell(_ day: Date) -> some View {
        let mood = dailyMoods[calendar.startOfDay(for: day)]
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 2) {
                if let mood {
                    MoodFace(level: mood, size: 30).accessibilityHidden(true)
                } else {
                    Color.clear.frame(width: 30, height: 30)
                }
                Text(day, format: .dateTime.day())
                    .font(.caption2.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.onBrandSecondary : Color.ink)
                    .padding(.horizontal, 4)
                    .background(isToday ? Color.brandSecondary : Color.clear, in: .capsule)
            }
            .frame(maxWidth: .infinity, minHeight: minTapTarget + 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.brandPrimary, lineWidth: 2)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayLabel(day, mood: mood))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func dayLabel(_ day: Date, mood: MoodLevel?) -> Text {
        if let mood {
            return Text("\(DateText.longDay(day)), mood: \(mood.label)")
        }
        return Text(DateText.longDay(day))
    }

    // MARK: Selected day

    @ViewBuilder
    private var dayEntries: some View {
        let items = entries.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDay) }
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(DateText.dayHeading(selectedDay))
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            if items.isEmpty {
                Text("Nothing written on this day.")
                    .secondaryText()
            } else {
                ForEach(items) { entry in
                    Button { onOpen(entry) } label: {
                        EntryRow(entry: entry).card(padding: Spacing.m)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct BentoCard: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    let fill: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.moodInk)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.moodInk)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(fill, in: .rect(cornerRadius: Radius.inner + 4, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct MoodCalendarPreview: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    var body: some View {
        MoodCalendarView(entries: entries) { _ in }
            .screenBackground()
    }
}

#Preview("Mood calendar") {
    MoodCalendarPreview().previewEnvironment()
}
