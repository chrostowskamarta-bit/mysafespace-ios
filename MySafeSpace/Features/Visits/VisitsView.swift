import SwiftUI

struct VisitsView: View {
    @Environment(AppServices.self) private var services
    @State private var selectedDate = Date.now
    @State private var showMonth = false
    @State private var showPast = false

    private var calendar: Calendar { .clinic }
    private var visits: [Visit] { services.visits.visits }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    calendarCard
                    selectedDaySection
                    upcomingSection
                    pastSection
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xl)
            }
            .screenBackground()
            .navigationTitle("Visits")
            .navigationDestination(for: Visit.ID.self) { id in
                VisitDetailView(visitID: id)
            }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: Spacing.s) {
            HStack {
                Text(selectedDate, format: .dateTime.month(.wide).year())
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
                MonthHeader(month: $selectedDate)
                MonthGrid(month: selectedDate) { day in
                    monthCell(day)
                }
            } else {
                WeekStrip(selection: $selectedDate) { hasVisit(on: $0) }
            }
        }
        .card(padding: Spacing.s)
    }

    private func monthCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let marked = hasVisit(on: day)
        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.day())
                    .font(.callout.weight(isSelected || isToday ? .semibold : .regular))
                Circle()
                    .fill(marked ? (isSelected ? Color.onBrandPrimary : Color.brandPrimary) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .foregroundStyle(isSelected ? Color.onBrandPrimary : (isToday ? Color.onBrandSecondary : Color.ink))
            .frame(maxWidth: .infinity, minHeight: minTapTarget)
            .background {
                if isSelected {
                    Circle().fill(Color.brandPrimary)
                } else if isToday {
                    Circle().fill(Color.brandSecondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(DateText.longDay(day) + (marked ? ", " + String(localized: "Has a visit") : "")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        let dayVisits = visits.filter { calendar.isDate($0.start, inSameDayAs: selectedDate) }
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(DateText.dayHeading(selectedDate))
                .font(.sectionTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            if dayVisits.isEmpty {
                Text("No visits on this day.")
                    .secondaryText()
            } else {
                ForEach(dayVisits) { visitLink($0) }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader("Upcoming")
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
        NavigationLink(value: visit.id) {
            VisitRow(visit: visit, clinician: services.directory.clinician(visit.clinicianID))
        }
        .buttonStyle(.plain)
    }

    private func hasVisit(on day: Date) -> Bool {
        visits.contains { calendar.isDate($0.start, inSameDayAs: day) }
    }
}

struct VisitRow: View {
    let visit: Visit
    let clinician: Clinician?

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(spacing: 0) {
                Text(visit.start, format: .dateTime.day())
                    .font(.title3.weight(.bold))
                Text(visit.start, format: .dateTime.month(.abbreviated))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.ink)
            .frame(width: 52, height: 56)
            .background(Color.surfaceMuted, in: .rect(cornerRadius: Radius.small, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(visit.title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(DateText.dayAndTime(visit.start))
                    .font(.subheadline)
                    .foregroundStyle(Color.ink)
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: visit.kind.systemImage).accessibilityHidden(true)
                    Text(locationLine)
                }
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
                if let note = visit.status.note {
                    Text(note)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.brandPrimaryStrong)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityHidden(true)
        }
        .card(padding: Spacing.s)
        .accessibilityElement(children: .combine)
    }

    private var locationLine: String {
        let who = clinician?.fullName ?? ""
        switch visit.kind {
        case .online: return String(localized: "\(who) · Online")
        case .inPerson(let room): return String(localized: "\(who) · Room \(room)")
        }
    }
}

#Preview("Visits") {
    VisitsView().previewEnvironment()
}
