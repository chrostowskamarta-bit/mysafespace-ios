import SwiftUI

/// All clinic doctors the patient can book with. Ratings and opinions are shown as
/// coming from ZnanyLekarz. MOCK: fixtures only — the ZnanyLekarz API isn't connected yet.
struct DoctorsView: View {
    enum Filter: Hashable, CaseIterable {
        case all, psychiatrists, psychologists

        var title: LocalizedStringKey {
            switch self {
            case .all: "All"
            case .psychiatrists: "Psychiatrists"
            case .psychologists: "Psychologists"
            }
        }

        func includes(_ role: ClinicianRole) -> Bool {
            switch self {
            case .all: role.isBookable
            case .psychiatrists: role == .psychiatrist
            case .psychologists: role == .psychologist || role == .psychotherapist
            }
        }
    }

    @Environment(AppServices.self) private var services
    @State private var filter: Filter = .all

    private var doctors: [Clinician] { services.directory.bookable.filter { filter.includes($0.role) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: minTapTarget)

                Text("Psychiatrists can prescribe medication. Psychologists and psychotherapists offer consultations and therapy. Ratings and opinions come from ZnanyLekarz.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)

                ForEach(doctors) { doctor in
                    NavigationLink {
                        DoctorDetailView(clinicianID: doctor.id)
                    } label: {
                        DoctorRow(clinician: doctor, nextSlot: nextSlot(for: doctor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl + minTapTarget)
        }
        .screenBackground()
        .navigationTitle("Book a visit")
    }

    private func nextSlot(for clinician: Clinician) -> Date? {
        let calendar = Calendar.clinic
        for offset in 0..<21 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }
            if let first = MockData.freeSlots(for: clinician, on: day, existing: services.visits.visits).first {
                return first
            }
        }
        return nil
    }
}

struct DoctorRow: View {
    let clinician: Clinician
    let nextSlot: Date?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            ClinicianPhoto(clinician: clinician, size: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(clinician.fullName)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(clinician.role.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                if let rating = clinician.rating, let count = clinician.ratingCount {
                    ZnanyLekarzRating(rating: rating, count: count)
                }
                if let nextSlot {
                    Text("Next free: \(DateText.dayAndTime(nextSlot))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandPrimaryStrong)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityHidden(true)
        }
        .card(padding: Spacing.m)
        .accessibilityElement(children: .combine)
    }
}

/// A doctor's profile: photo, rating from ZnanyLekarz, calendar of free times and opinions.
struct DoctorDetailView: View {
    let clinicianID: String

    @Environment(AppServices.self) private var services
    @Environment(AppState.self) private var appState
    @State private var selectedDay: Date?
    @State private var online = false
    @State private var pendingSlot: Date?
    @State private var bookedMessage: String?

    private var calendar: Calendar { .clinic }
    private var clinician: Clinician? { services.directory.clinician(clinicianID) }

    var body: some View {
        if let clinician {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header(clinician)
                    calendarCard(clinician)
                    opinions(clinician)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xl + minTapTarget)
            }
            .screenBackground()
            .navigationTitle(clinician.shortName)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Book a visit with \(clinician.shortName)?",
                isPresented: Binding(get: { pendingSlot != nil }, set: { if !$0 { pendingSlot = nil } }),
                titleVisibility: .visible,
                presenting: pendingSlot
            ) { slot in
                Button("Book visit") { book(clinician, at: slot) }
                Button("Not now", role: .cancel) {}
            } message: { slot in
                Text("\(DateText.dayAndTime(slot)) · \(online ? String(localized: "Online") : String(localized: "In person")) · \(duration(clinician)) min")
            }
            .alert("Visit booked", isPresented: Binding(get: { bookedMessage != nil }, set: { if !$0 { bookedMessage = nil } })) {
                Button("Show in Calendar") {
                    if let day = pendingDayForCalendar { appState.openCalendar(on: day) }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(bookedMessage ?? "")
            }
        }
    }

    @State private var pendingDayForCalendar: Date?

    private func duration(_ clinician: Clinician) -> Int { clinician.role.isPsychiatrist ? 30 : 50 }

    // MARK: Header

    private func header(_ clinician: Clinician) -> some View {
        VStack(spacing: Spacing.xs) {
            ClinicianPhoto(clinician: clinician, size: 112)
            Text(clinician.fullName)
                .font(.screenTitle)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(clinician.role.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            if let rating = clinician.rating, let count = clinician.ratingCount {
                ZnanyLekarzRating(rating: rating, count: count)
            }
            if let about = clinician.about {
                Text(about)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Calendar of free times

    private func workingDays(_ clinician: Clinician) -> [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<28).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .filter { clinician.officeHours.weekdays.contains(calendar.component(.weekday, from: $0)) }
            .prefix(7)
            .map { $0 }
    }

    private func calendarCard(_ clinician: Clinician) -> some View {
        let days = workingDays(clinician)
        let existing = services.visits.visits
        let firstFree = days.first(where: { !MockData.freeSlots(for: clinician, on: $0, existing: existing).isEmpty })
        let current: Date? = selectedDay ?? firstFree ?? days.first
        let slots = current.map { MockData.freeSlots(for: clinician, on: $0, existing: existing) } ?? []
        return VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader("Calendar")
            Picker("Visit type", selection: $online) {
                Text("In person").tag(false)
                Text("Online").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(minHeight: minTapTarget)

            HStack(spacing: Spacing.xxs) {
                ForEach(days, id: \.self) { day in
                    let isSelected = current.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                    let free = MockData.freeSlots(for: clinician, on: day, existing: existing).count
                    Button {
                        selectedDay = day
                    } label: {
                        VStack(spacing: 2) {
                            Text(day, format: .dateTime.weekday(.abbreviated)).font(.caption2.weight(.semibold))
                            Text(day, format: .dateTime.day()).font(.callout.weight(.semibold))
                            Text(day, format: .dateTime.month(.abbreviated)).font(.caption2)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .foregroundStyle(isSelected ? Color.onBrandPrimary : Color.ink)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.brandPrimary)
                            }
                        }
                        .opacity(free == 0 && !isSelected ? 0.5 : 1)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(DateText.longDay(day)), \(free == 0 ? String(localized: "fully booked") : String(localized: "\(free) free times"))"))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)

            if slots.isEmpty {
                Text("No free times on this day.").secondaryText()
            } else {
                FlowLayout(spacing: Spacing.xs) {
                    ForEach(slots, id: \.self) { slot in
                        Button {
                            pendingSlot = slot
                        } label: {
                            Text(DateText.time(slot))
                                .font(.headline.monospacedDigit())
                                .padding(.horizontal, Spacing.m)
                                .frame(minHeight: minTapTarget)
                                .foregroundStyle(Color.brandPrimaryStrong)
                                .overlay(Capsule().strokeBorder(Color.brandPrimary, lineWidth: 1.5))
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Book \(DateText.dayAndTime(slot))"))
                    }
                }
            }
            Text(clinician.role.isPsychiatrist
                 ? LocalizedStringKey("Consultation · 30 min · the clinic confirms your booking.")
                 : LocalizedStringKey("Session · 50 min · the clinic confirms your booking."))
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .card(padding: Spacing.m)
    }

    private func book(_ clinician: Clinician, at slot: Date) {
        Task {
            await services.visits.book(clinician: clinician, start: slot, online: online)
            pendingDayForCalendar = slot
            selectedDay = nil
            bookedMessage = String(localized: "\(DateText.dayAndTime(slot)) with \(clinician.fullName). You'll find it in Calendar.")
        }
    }

    // MARK: Opinions (from ZnanyLekarz)

    private func opinions(_ clinician: Clinician) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader("Opinions")
                Text("from ZnanyLekarz")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(MockData.reviews(for: clinician.id)) { review in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack(spacing: Spacing.xs) {
                            StarsView(value: Double(review.stars))
                            Text("\(review.when) · verified patient")
                                .font(.footnote)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Text(review.text)
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("\(review.stars) out of 5. \(review.text). \(review.when)"))
                    Divider().padding(.leading, Spacing.m)
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))

            // No API yet: leaving an opinion opens ZnanyLekarz itself.
            Link(destination: URL(string: "https://www.znanylekarz.pl")!) {
                Text("Leave an opinion on ZnanyLekarz")
            }
            .buttonStyle(.pill(.secondary))
            Text("Opens ZnanyLekarz. Ratings here are shown as they appear there.")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Doctors") {
    NavigationStack { DoctorsView() }.previewEnvironment()
}
