import SwiftUI
import SwiftData

enum CalendarRoute: Hashable {
    case visit(Visit.ID)
    case doctors
}

struct NoteRequest: Identifiable {
    let id = UUID()
    var entry: JournalEntry?
    var day: Date
    var record = false
}

/// One place for the patient's days: visits, mood and the note for each day.
/// (Replaces the separate Visits and Journal tabs.) Tap a day to rate its mood and to
/// write or record that day's note. Notes stay private unless the patient shares them.
struct CalendarView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var showMonth = false
    @State private var showPast = false
    @State private var editor: NoteRequest?
    @State private var checkIn: CheckInRequest?
    @State private var summaryVisit: Visit?

    private var calendar: Calendar { .clinic }
    private var visits: [Visit] { services.visits.visits }
    private var samples: [InsightSample] { entries.map(\.insightSample) }
    private var dailyMoods: [Date: MoodLevel] { JournalInsights.dailyMoods(samples) }
    private var week: WeekInsights { JournalInsights.week(samples, endingOn: .now) }

    private var selection: Binding<Date> {
        Binding(get: { appState.calendarDay }, set: { appState.calendarDay = calendar.startOfDay(for: $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    calendarCard
                    daySection
                    if let next = visits.next() {
                        PreVisitPrompt(visit: next) { summaryVisit = next }
                    }
                    weekCard
                    bento
                    upcomingSection
                    pastSection
                }
                .padding(.horizontal, Spacing.screen)
                // Room for the floating "Need help now" button.
                .padding(.bottom, Spacing.xl + minTapTarget)
            }
            .screenBackground()
            .navigationTitle("Calendar")
            .toolbar {
                // Usability test (U1): 2 of 5 patients scrolled to find booking here,
                // so "Book a visit" sits at the top of the Calendar, visible without scrolling.
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: CalendarRoute.doctors) {
                        Label("Book a visit", systemImage: "calendar.badge.plus")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: minTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color.brandPrimary)
                }
            }
            .navigationDestination(for: CalendarRoute.self) { route in
                switch route {
                case .visit(let id): VisitDetailView(visitID: id)
                case .doctors: DoctorsView()
                }
            }
        }
        .sheet(item: $editor) { EntryEditorView(entry: $0.entry, day: $0.day, startsRecording: $0.record) }
        .sheet(item: $checkIn) { CheckInView(entry: $0.entry, initialMood: $0.mood) }
        .sheet(item: $summaryVisit) { PreVisitSummaryView(visit: $0) }
    }

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(spacing: Spacing.s) {
            HStack {
                Text(appState.calendarDay, format: .dateTime.month(.wide).year())
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button(showMonth ? "Show week" : "Show month") {
                    withAnimation(.easeInOut(duration: 0.25)) { showMonth.toggle() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandPrimaryStrong)
                .frame(minHeight: minTapTarget)
            }
            if showMonth {
                MonthHeader(month: selection)
                MonthGrid(month: appState.calendarDay) { day in
                    monthCell(day)
                }
            } else {
                WeekStrip(selection: selection, hasEvent: hasVisit(on:)) { dailyMoods[calendar.startOfDay(for: $0)] }
            }
        }
        .card(padding: Spacing.s)
    }

    private func monthCell(_ day: Date) -> some View {
        let mood = dailyMoods[calendar.startOfDay(for: day)]
        let isSelected = calendar.isDate(day, inSameDayAs: appState.calendarDay)
        let isToday = calendar.isDateInToday(day)
        let marked = hasVisit(on: day)
        return Button {
            appState.calendarDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 2) {
                if let mood {
                    MoodFace(level: mood, size: 26).accessibilityHidden(true)
                } else {
                    Color.clear.frame(width: 26, height: 26)
                }
                Text(day, format: .dateTime.day())
                    .font(.caption2.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.onBrandSecondary : Color.ink)
                    .padding(.horizontal, 4)
                    .background(isToday ? Color.brandSecondary : Color.clear, in: .capsule)
                Circle()
                    .fill(marked ? Color.brandPrimary : Color.clear)
                    .frame(width: 5, height: 5)
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
        .accessibilityLabel(dayLabel(day, mood: mood, hasVisit: marked))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func dayLabel(_ day: Date, mood: MoodLevel?, hasVisit: Bool) -> Text {
        var parts = [DateText.longDay(day)]
        if let mood { parts.append(String(localized: "Mood: \(mood.label)")) }
        if hasVisit { parts.append(String(localized: "Has a visit")) }
        return Text(parts.joined(separator: ", "))
    }

    // MARK: Selected day

    @ViewBuilder
    private var daySection: some View {
        let day = appState.calendarDay
        let dayVisits = visits.filter { calendar.isDate($0.start, inSameDayAs: day) }
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(DateText.dayHeading(day))
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(dayVisits) { visitLink($0) }
            moodCard(for: day)
            noteCard(for: day)
        }
    }

    private func isFuture(_ day: Date) -> Bool {
        calendar.startOfDay(for: day) > calendar.startOfDay(for: .now)
    }

    @ViewBuilder
    private func moodCard(for day: Date) -> some View {
        let entry = checkInEntry(on: day)
        let title: LocalizedStringKey = isFuture(day) ? "Mood" : (calendar.isDateInToday(day) ? "How are you today?" : "How was this day?")
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let entry, !isFuture(day) {
                    Button("Add feelings") { checkIn = CheckInRequest(entry: entry) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandPrimaryStrong)
                        .frame(minHeight: minTapTarget)
                }
            }
            if isFuture(day) {
                Text("You can rate this day when it comes.")
                    .secondaryText()
            } else {
                MoodRow(selection: entry?.mood, faceSize: 40) { setMood($0, on: day) }
                // The slider is a second way to rate, next to the faces.
                Slider(
                    value: Binding(
                        get: { Double(entry?.mood?.rawValue ?? MoodLevel.okay.rawValue) },
                        set: { setMood(MoodLevel(rawValue: Int($0.rounded())) ?? .okay, on: day) }
                    ),
                    in: 1...5,
                    step: 1
                ) {
                    Text("Mood")
                } minimumValueLabel: {
                    Image(systemName: "cloud.rain").accessibilityHidden(true)
                } maximumValueLabel: {
                    Image(systemName: "sun.max").accessibilityHidden(true)
                }
                .tint(Color.brandPrimary.opacity(0.5)) // Marta's Figma: slider track at 50%
                .foregroundStyle(Color.inkSecondary)
                .frame(minHeight: minTapTarget)
                .accessibilityLabel(Text("Mood for \(DateText.dayHeading(day))"))
                .accessibilityValue(Text(entry?.mood?.label ?? String(localized: "Not rated")))
            }
        }
        .card(padding: Spacing.m)
    }

    @ViewBuilder
    private func noteCard(for day: Date) -> some View {
        let dayEntries = entries.filter { calendar.isDate($0.createdAt, inSameDayAs: day) && !$0.text.isEmpty }
        let note = dayEntries.first { !$0.isCheckIn }
        let empty: LocalizedStringKey = isFuture(day) ? "Nothing here yet." : "Nothing written on this day."
        let writeTitle: LocalizedStringKey = note == nil ? "Write" : "Edit note"
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Note")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let note { PrivacyBadge(isShared: note.isShared) }
            }
            if dayEntries.isEmpty {
                Text(empty).secondaryText()
            } else {
                ForEach(dayEntries) { entry in
                    Button { open(entry) } label: { EntryRow(entry: entry) }
                        .buttonStyle(.plain)
                }
            }
            if !isFuture(day) {
                HStack(spacing: Spacing.xs) {
                    Button {
                        editor = NoteRequest(entry: note, day: day)
                    } label: {
                        Label(writeTitle, systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.pill(.quiet))
                    Button {
                        editor = NoteRequest(entry: note, day: day, record: true)
                    } label: {
                        Label("Record", systemImage: "mic")
                    }
                    .buttonStyle(.pill(.quiet))
                    .accessibilityHint("Records a voice note. It's turned into text on this iPhone and the recording isn't saved.")
                }
                Text("Voice is turned into text on your iPhone and the recording isn't saved. Notes are private unless you share them with your therapist.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .card(padding: Spacing.m)
    }

    private func checkInEntry(on day: Date) -> JournalEntry? {
        entries.first { $0.isCheckIn && calendar.isDate($0.createdAt, inSameDayAs: day) }
    }

    private func setMood(_ mood: MoodLevel, on day: Date) {
        guard !isFuture(day) else { return }
        if let existing = checkInEntry(on: day) {
            guard existing.mood != mood else { return }
            existing.mood = mood
            existing.updatedAt = .now
        } else {
            let entry = JournalEntry(createdAt: EntryEditorView.timestamp(for: day), mood: mood, isCheckIn: true)
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }

    private func open(_ entry: JournalEntry) {
        if entry.isCheckIn && entry.text.isEmpty {
            checkIn = CheckInRequest(entry: entry)
        } else {
            editor = NoteRequest(entry: entry, day: entry.createdAt)
        }
    }

    // MARK: Week reflection

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Your week")
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(week.sentences, id: \.self) { sentence in
                Text(sentence)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
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

    // MARK: Visits

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader("Upcoming visits")
            ForEach(visits.upcoming()) { visitLink($0) }
        }
    }

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showPast.toggle() }
            } label: {
                HStack {
                    Text("Past visits").font(.sectionTitle)
                    Spacer()
                    Image(systemName: showPast ? "chevron.up" : "chevron.down")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.ink)
                .frame(minHeight: minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            if showPast {
                ForEach(visits.past()) { visitLink($0) }
            }
        }
    }

    private func visitLink(_ visit: Visit) -> some View {
        NavigationLink(value: CalendarRoute.visit(visit.id)) {
            VisitRow(visit: visit, clinician: services.directory.clinician(visit.clinicianID))
        }
        .buttonStyle(.plain)
    }

    private func hasVisit(on day: Date) -> Bool {
        visits.contains { calendar.isDate($0.start, inSameDayAs: day) && $0.status != .cancellationRequested }
    }
}

#Preview("Calendar") {
    CalendarView().previewEnvironment()
}
