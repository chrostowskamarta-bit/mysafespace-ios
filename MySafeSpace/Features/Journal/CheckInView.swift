import SwiftUI
import SwiftData

/// ≤ 10-second check-in. The face slider is the only required step; feelings, tags and a
/// note sit behind "Add more". One primary action: Save.
struct CheckInView: View {
    let entry: JournalEntry?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services

    @State private var mood: MoodLevel
    @State private var emotions: Set<Emotion>
    @State private var tags: [CheckInTag: TagLevel]
    @State private var medsTaken: Bool?
    @State private var note: String
    @State private var showMore: Bool

    init(entry: JournalEntry?, initialMood: MoodLevel?) {
        self.entry = entry
        _mood = State(initialValue: entry?.mood ?? initialMood ?? .okay)
        _emotions = State(initialValue: Set(entry?.emotions ?? []))
        var initialTags: [CheckInTag: TagLevel] = [:]
        if let entry {
            for tag in CheckInTag.allCases { initialTags[tag] = entry.level(for: tag) }
        }
        _tags = State(initialValue: initialTags)
        _medsTaken = State(initialValue: entry?.medsTaken)
        _note = State(initialValue: entry?.text ?? "")
        _showMore = State(initialValue: entry != nil && !(entry?.emotions.isEmpty ?? true))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    Text("How are you today?")
                        .font(.sectionTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    MoodPicker(level: $mood)
                        .padding(.horizontal, Spacing.s)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showMore.toggle() }
                    } label: {
                        HStack {
                            Text(showMore ? "Fewer details" : "Add more (optional)")
                            Image(systemName: showMore ? "chevron.up" : "chevron.down")
                                .accessibilityHidden(true)
                        }
                        .font(.headline)
                        .foregroundStyle(Color.brandPrimaryStrong)
                        .frame(minHeight: minTapTarget)
                    }

                    if showMore { details }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                Button("Save check-in", action: save)
                    .buttonStyle(.pill())
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.appBackground.opacity(0.96))
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { NeedHelpButton() }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Which words fit?")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                FlowLayout {
                    ForEach(Emotion.suggested(for: mood)) { emotion in
                        Chip(title: emotion.label, isSelected: emotions.contains(emotion)) {
                            if emotions.contains(emotion) { emotions.remove(emotion) } else { emotions.insert(emotion) }
                        }
                    }
                }
            }
            .card(padding: Spacing.m)

            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(CheckInTag.allCases) { tag in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Label(tag.title, systemImage: tag.systemImage)
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                        FlowLayout {
                            ForEach(TagLevel.allCases) { level in
                                Chip(title: tag.label(for: level), isSelected: tags[tag] == level) {
                                    tags[tag] = tags[tag] == level ? nil : level
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Medication", systemImage: "pills")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    FlowLayout {
                        Chip(title: String(localized: "Taken"), isSelected: medsTaken == true) {
                            medsTaken = medsTaken == true ? nil : true
                        }
                        Chip(title: String(localized: "Not yet"), isSelected: medsTaken == false) {
                            medsTaken = medsTaken == false ? nil : false
                        }
                    }
                }
            }
            .card(padding: Spacing.m)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("A note (optional)")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                TextField("Anything you want to remember", text: $note, axis: .vertical)
                    .lineLimit(2...6)
                    .foregroundStyle(Color.ink)
                    .privacySensitive()
            }
            .card(padding: Spacing.m)
        }
        .transition(.opacity)
    }

    private func save() {
        let target: JournalEntry
        if let entry {
            target = entry
        } else {
            target = JournalEntry(isCheckIn: true)
            modelContext.insert(target)
        }
        target.mood = mood
        target.emotions = Emotion.allCases.filter { emotions.contains($0) }
        for tag in CheckInTag.allCases { target.setLevel(tags[tag], for: tag) }
        target.medsTaken = medsTaken
        target.text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.updatedAt = .now
        try? modelContext.save()

        let assessment = services.crisisDetector.assess(target.text)
        let entryID = target.id
        dismiss()
        appState.handle(assessment, source: .journal, key: "entry-\(entryID)", safetyAlerts: services.safetyAlerts)
    }
}

#Preview("Check-in") {
    CheckInView(entry: nil, initialMood: .low).previewEnvironment()
}
