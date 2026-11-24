import SwiftUI
import SwiftData

enum HomeRoute: Hashable {
    case prescriptions
    case visit(Visit.ID)
    case doctors
}

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var checkIn: CheckInRequest?
    @State private var showTodaysNote = false
    @State private var onlineVisit: Visit?

    private var patient: Patient { services.directory.patient }

    private var todaysCheckIn: JournalEntry? {
        entries.first { $0.isCheckIn && Calendar.clinic.isDateInToday($0.createdAt) }
    }

    private var todaysNote: JournalEntry? {
        entries.first { !$0.isCheckIn && !$0.text.isEmpty && Calendar.clinic.isDateInToday($0.createdAt) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    MoodCheckInCard(todaysCheckIn: todaysCheckIn) { request in
                        checkIn = request
                    }
                    if let next = services.visits.visits.next() {
                        NavigationLink(value: HomeRoute.visit(next.id)) {
                            NextVisitCard(visit: next, clinician: services.directory.clinician(next.clinicianID)) {
                                onlineVisit = next
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    quickActions
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xl + minTapTarget)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .prescriptions: PrescriptionsView()
                case .visit(let id): VisitDetailView(visitID: id)
                case .doctors: DoctorsView()
                }
            }
        }
        .sheet(item: $checkIn) { request in
            CheckInView(entry: request.entry, initialMood: request.mood)
        }
        .sheet(isPresented: $showTodaysNote) {
            EntryEditorView(entry: todaysNote, day: .now)
        }
        .fullScreenCover(item: $onlineVisit) { visit in
            OnlineVisitFlow(visit: visit)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.inkSecondary)
            Text(greeting)
                .font(.displayTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, Spacing.m)
    }

    private var greeting: String {
        let hour = Calendar.clinic.component(.hour, from: .now)
        let name = patient.firstName
        switch hour {
        case 5..<12: return String(localized: "Good morning, \(name)")
        case 12..<18: return String(localized: "Good afternoon, \(name)")
        default: return String(localized: "Good evening, \(name)")
        }
    }

    // MARK: Quick actions (bento)

    private var quickActions: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: Spacing.s),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
        let lead = services.directory.lead
        return VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader("Quick actions")
            LazyVGrid(columns: columns, spacing: Spacing.s) {
                QuickActionTile(title: "Today's note", systemImage: "square.and.pencil", style: .highlight) {
                    showTodaysNote = true
                }
                QuickActionTile(title: "Message \(lead.shortName)", systemImage: "bubble.left.and.text.bubble.right", style: .plain) {
                    appState.openThread(MockData.nowakThreadID)
                }
                QuickActionTile(title: "Prescriptions", systemImage: "pills", style: .plain) {
                    appState.selectedTab = .prescriptions
                }
                NavigationLink(value: HomeRoute.doctors) {
                    QuickActionTileLabel(title: "Book a visit", systemImage: "calendar.badge.plus", style: .plain)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Check-in card

struct CheckInRequest: Identifiable {
    let id = UUID()
    var entry: JournalEntry?
    var mood: MoodLevel?
}

/// Non-blocking, skippable. Collapses once done.
struct MoodCheckInCard: View {
    let todaysCheckIn: JournalEntry?
    let onCheckIn: (CheckInRequest) -> Void

    @Environment(AppState.self) private var appState
    /// The slider is a second way to pick a mood, next to the faces.
    @State private var sliderValue: Double = 3
    @State private var sliderTouched = false

    private var sliderMood: MoodLevel { MoodLevel(rawValue: Int(sliderValue.rounded())) ?? .okay }

    private var skippedToday: Bool {
        appState.settings.checkInSkippedOn.map(Calendar.clinic.isDateInToday) ?? false
    }

    var body: some View {
        if let entry = todaysCheckIn, let mood = entry.mood {
            HStack(spacing: Spacing.s) {
                MoodFace(level: mood, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Checked in today")
                        .font(.headline)
                    Text("Feeling \(mood.label.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
                .foregroundStyle(Color.ink)
                Spacer()
                Button("Edit") { onCheckIn(CheckInRequest(entry: entry)) }
                    .font(.headline)
                    .foregroundStyle(Color.brandPrimaryStrong)
                    .frame(minWidth: minTapTarget, minHeight: minTapTarget)
                    .accessibilityLabel("Edit today's check-in")
            }
            .card(padding: Spacing.m)
        } else if skippedToday {
            Button {
                onCheckIn(CheckInRequest())
            } label: {
                HStack {
                    Image(systemName: "face.smiling").accessibilityHidden(true)
                    Text("Check in whenever you like")
                    Spacer()
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: 52)
                .background(Color.surface, in: .capsule)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text("How are you today?")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("Skip for now") {
                        appState.settings.checkInSkippedOn = .now
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.brandPrimaryStrong)
                    .frame(minHeight: minTapTarget)
                }
                MoodRow(selection: sliderTouched ? sliderMood : nil, faceSize: 46) { mood in
                    onCheckIn(CheckInRequest(mood: mood))
                }
                Slider(value: $sliderValue, in: 1...5, step: 1) {
                    Text("Mood")
                } minimumValueLabel: {
                    Image(systemName: "cloud.rain").accessibilityHidden(true)
                } maximumValueLabel: {
                    Image(systemName: "sun.max").accessibilityHidden(true)
                } onEditingChanged: { editing in
                    if editing {
                        sliderTouched = true
                    } else {
                        onCheckIn(CheckInRequest(mood: sliderMood))
                    }
                }
                .tint(Color.brandPrimary.opacity(0.5)) // Marta's Figma: slider track at 50%
                .foregroundStyle(Color.inkSecondary)
                .frame(minHeight: minTapTarget)
                .accessibilityLabel(Text("Or slide to choose your mood"))
                .accessibilityValue(Text(sliderMood.label))
                .accessibilityAction(named: Text("Check in with this mood")) {
                    onCheckIn(CheckInRequest(mood: sliderMood))
                }
                Text("Tap a face or use the slider. Takes about 10 seconds. Only you can see it.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
            }
            .card()
        }
    }
}

// MARK: - Next visit hero

struct NextVisitCard: View {
    let visit: Visit
    let clinician: Clinician?
    let onJoin: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let canJoin = visit.canJoin(at: context.date)
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Text("Next visit")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.onBrandPrimary.opacity(0.18), in: .capsule)
                    Spacer()
                    Label(visit.kind.label, systemImage: visit.kind.systemImage)
                        .font(.subheadline.weight(.medium))
                }
                Text(DateText.dayAndTime(visit.start))
                    .font(.screenTitle)
                HStack(spacing: Spacing.s) {
                    if let clinician {
                        ClinicianPhoto(clinician: clinician, size: 48, ring: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(clinician.fullName).font(.headline)
                            Text(locationText).font(.subheadline).opacity(0.9)
                        }
                    }
                }
                if canJoin {
                    Button(action: onJoin) {
                        Text("Join online visit")
                    }
                    .buttonStyle(JoinButtonStyle())
                    .accessibilityHint("Starts the location check and waiting room")
                } else if visit.kind.isOnline {
                    Text("You can join from 10 minutes before the start.")
                        .font(.footnote)
                        .opacity(0.9)
                }
            }
            .foregroundStyle(Color.onBrandPrimary)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.brandPrimary, Color.brandPrimaryStrong], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: Radius.card, style: .continuous)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Opens visit details")
    }

    private var locationText: String {
        switch visit.kind {
        case .online: String(localized: "Online")
        case .inPerson(let room): String(localized: "Room \(room) · ul. Przykładowa 12")
        }
    }
}

/// Inverse pill on the violet hero: white (or dark-ink) capsule with violet text.
private struct JoinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label.font(.headline)
            Spacer()
            Image(systemName: "video.fill").accessibilityHidden(true)
        }
        .foregroundStyle(Color.brandPrimaryStrong)
        .padding(.horizontal, Spacing.l)
        .frame(minHeight: 52)
        .background(Color.surface, in: .capsule)
        .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Bento tiles

enum TileStyle { case highlight, plain }

struct QuickActionTile: View {
    let title: LocalizedStringKey
    let systemImage: String
    let style: TileStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionTileLabel(title: title, systemImage: systemImage, style: style)
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionTileLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let style: TileStyle

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(style == .highlight ? Color.onBrandSecondary : Color.brandPrimary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(style == .highlight ? Color.onBrandSecondary : Color.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(style == .highlight ? Color.brandSecondary : Color.surface, in: .rect(cornerRadius: Radius.inner + 4, style: .continuous))
        .contentShape(.rect)
    }
}

#Preview("Home") {
    HomeView().previewEnvironment()
}
