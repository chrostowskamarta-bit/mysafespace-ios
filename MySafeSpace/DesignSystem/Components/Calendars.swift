import SwiftUI

/// Horizontal week strip for date picking. Today = lemon highlight with ink text;
/// selected = violet. Days with events show a dot (and say so to VoiceOver).
struct WeekStrip: View {
    @Binding var selection: Date
    var hasEvent: (Date) -> Bool = { _ in false }
    /// Optional mood for each day, drawn as a small face under the date (Calendar tab).
    var mood: (Date) -> MoodLevel? = { _ in nil }

    private var calendar: Calendar { .clinic }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            chevron("chevron.left", label: "Previous week", weeks: -1)
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
            chevron("chevron.right", label: "Next week", weeks: 1)
        }
        // DECISION: the strip caps at accessibility2 — seven columns can't grow further on
        // a phone. The same dates are available in the list below at full size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var days: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: selection) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    private func chevron(_ symbol: String, label: LocalizedStringKey, weeks: Int) -> some View {
        Button {
            if let moved = calendar.date(byAdding: .weekOfYear, value: weeks, to: selection) {
                selection = moved
            }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.ink)
        .accessibilityLabel(Text(label))
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(day)
        let marked = hasEvent(day)
        let dayMood = mood(day)
        return Button {
            selection = day
        } label: {
            VStack(spacing: 4) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.caption2.weight(.semibold))
                Text(day, format: .dateTime.day())
                    .font(.callout.weight(.semibold))
                if let dayMood {
                    MoodFace(level: dayMood, size: 20).accessibilityHidden(true)
                }
                Circle()
                    .fill(marked ? (isSelected ? Color.onBrandPrimary : Color.brandPrimary) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(isSelected ? Color.onBrandPrimary : Color.ink)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.brandPrimary)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.brandSecondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(day, isToday: isToday, marked: marked, mood: dayMood))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dayAccessibilityLabel(_ day: Date, isToday: Bool, marked: Bool, mood: MoodLevel?) -> Text {
        var parts = [DateText.longDay(day)]
        if isToday { parts.append(String(localized: "Today")) }
        if let mood { parts.append(String(localized: "Mood: \(mood.label)")) }
        if marked { parts.append(String(localized: "Has a visit")) }
        return Text(parts.joined(separator: ", "))
    }
}

/// Month grid starting on Monday. The caller decides how each day looks.
struct MonthGrid<Cell: View>: View {
    let month: Date
    @ViewBuilder var cell: (Date) -> Cell

    private var calendar: Calendar { .clinic }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityHidden(true)
            }
            ForEach(Array(slots.enumerated()), id: \.offset) { _, date in
                if let date {
                    cell(date)
                } else {
                    Color.clear.frame(height: 1).accessibilityHidden(true)
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var slots: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dates: [Date?] = days.map { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        return Array(repeating: nil, count: leading) + dates
    }
}

/// Month title with previous/next buttons.
struct MonthHeader: View {
    @Binding var month: Date

    var body: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").frame(width: minTapTarget, height: minTapTarget)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").frame(width: minTapTarget, height: minTapTarget)
            }
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.ink)
    }

    private func shift(_ value: Int) {
        if let moved = Calendar.clinic.date(byAdding: .month, value: value, to: month) {
            month = moved
        }
    }
}

#Preview("Calendars") {
    @Previewable @State var date = Date.now
    @Previewable @State var month = Date.now
    VStack(spacing: 24) {
        WeekStrip(selection: $date) { Calendar.clinic.component(.weekday, from: $0) == 5 }
        MonthHeader(month: $month)
        MonthGrid(month: month) { day in
            Text(day, format: .dateTime.day())
                .frame(maxWidth: .infinity, minHeight: 40)
        }
    }
    .padding()
    .screenBackground()
}
