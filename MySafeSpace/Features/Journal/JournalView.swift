import SwiftUI
import SwiftData

struct JournalView: View {
    enum Mode: Hashable { case entries, calendar }

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var mode: Mode = .entries
    @State private var editing: EditorRequest?
    @State private var checkIn: CheckInRequest?
    @State private var pendingShare: JournalEntry?
    @State private var pendingDelete: JournalEntry?
    @State private var summaryVisit: Visit?

    private var recipient: Clinician { services.directory.journalRecipient }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $mode) {
                    Text("Entries").tag(Mode.entries)
                    Text("Mood calendar").tag(Mode.calendar)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xs)

                switch mode {
                case .entries: entriesList
                case .calendar: MoodCalendarView(entries: entries) { open($0) }
                }
            }
            .screenBackground()
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        checkIn = CheckInRequest()
                    } label: {
                        Label("Check in", systemImage: "face.smiling")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = EditorRequest(entry: nil)
                    } label: {
                        Label("New entry", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(item: $editing) { EntryEditorView(entry: $0.entry) }
        .sheet(item: $checkIn) { CheckInView(entry: $0.entry, initialMood: $0.mood) }
        .sheet(item: $summaryVisit) { PreVisitSummaryView(visit: $0) }
        .confirmationDialog(
            "Share this entry with \(recipient.fullName)?",
            isPresented: Binding(get: { pendingShare != nil }, set: { if !$0 { pendingShare = nil } }),
            titleVisibility: .visible,
            presenting: pendingShare
        ) { entry in
            Button("Share entry") { entry.setShared(true) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("They'll be able to read this entry before your next session. You can stop sharing at any time.")
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { entry in
            Button("Delete entry", role: .destructive) { delete(entry) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    // MARK: Entries

    @ViewBuilder
    private var entriesList: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label("Your journal is empty", systemImage: "book.closed")
            } description: {
                Text("Write a few words whenever you like. Only you can see them unless you choose to share.")
            } actions: {
                Button("Write your first entry") { editing = EditorRequest(entry: nil) }
                    .buttonStyle(.pill())
            }
        } else {
            List {
                if let next = services.visits.visits.next() {
                    Section {
                        PreVisitPrompt(visit: next) { summaryVisit = next }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                ForEach(groupedByDay) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            Button {
                                open(entry)
                            } label: {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.surface)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if entry.isShared {
                                    Button { entry.setShared(false) } label: {
                                        Label("Stop sharing", systemImage: "lock.fill")
                                    }
                                    .tint(Color.inkSecondary)
                                } else {
                                    Button { pendingShare = entry } label: {
                                        Label("Share", systemImage: "person.2.fill")
                                    }
                                    .tint(Color.brandPrimary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { pendingDelete = entry } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .accessibilityAction(named: entry.isShared ? Text("Stop sharing") : Text("Share")) {
                                if entry.isShared { entry.setShared(false) } else { pendingShare = entry }
                            }
                            .accessibilityAction(named: Text("Delete")) { pendingDelete = entry }
                        }
                    } header: {
                        Text(DateText.dayHeading(group.day))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkSecondary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listScreenBackground()
        }
    }

    private var groupedByDay: [DayGroup] {
        let calendar = Calendar.clinic
        let groups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { day in
            DayGroup(day: day, entries: groups[day]?.sorted { $0.createdAt > $1.createdAt } ?? [])
        }
    }

    private func open(_ entry: JournalEntry) {
        if entry.isCheckIn && entry.text.isEmpty {
            checkIn = CheckInRequest(entry: entry)
        } else {
            editing = EditorRequest(entry: entry)
        }
    }

    private func delete(_ entry: JournalEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

struct DayGroup: Identifiable {
    let day: Date
    let entries: [JournalEntry]
    var id: Date { day }
}

struct EditorRequest: Identifiable {
    let id = UUID()
    var entry: JournalEntry?
}

// MARK: - Row

struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            if let mood = entry.mood {
                MoodFace(level: mood, size: 40)
            } else {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceMuted, in: .circle)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.isCheckIn ? String(localized: "Check-in") : String(localized: "Note"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                    Text(DateText.time(entry.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    PrivacyBadge(isShared: entry.isShared)
                }
                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.body)
                        .foregroundStyle(Color.ink)
                        .lineLimit(3)
                        .privacySensitive()
                }
                if !entry.emotions.isEmpty {
                    Text(entry.emotions.map(\.label).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pre-visit prompt

struct PreVisitPrompt: View {
    let visit: Visit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(Color.onBrandSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Here's your week")
                        .font(.headline)
                    Text("Before your visit \(DateText.dayAndTime(visit.start).lowercasedFirst) – review what you'd like to share, if anything.")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.onBrandSecondary)
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.onBrandSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.m)
            .background(Color.brandSecondary, in: .rect(cornerRadius: Radius.inner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

extension String {
    /// "Today, 17:00" → "today, 17:00" for use mid-sentence.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}

#Preview("Journal") {
    JournalView().previewEnvironment()
}
