import SwiftUI
import SwiftData

/// "Here's your week": choose what to include → preview EXACTLY what will be shared →
/// share or keep private. Every share is stored as a `SharedSummary` and is revocable.
struct PreVisitSummaryView: View {
    let visit: Visit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]

    @State private var includeMood = true
    @State private var includeFeelings = true
    @State private var includedEntryIDs: Set<UUID> = []
    @State private var path: [Step] = []
    @State private var didPrefill = false

    enum Step: Hashable { case preview, done }

    private var calendar: Calendar { .clinic }

    private var recipient: Clinician {
        services.directory.clinician(visit.clinicianID) ?? services.directory.journalRecipient
    }

    private var periodStart: Date {
        calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
    }

    private var weekEntries: [JournalEntry] {
        allEntries.filter { $0.createdAt >= periodStart }
    }

    private var writtenEntries: [JournalEntry] { weekEntries.filter { !$0.text.isEmpty } }
    private var week: WeekInsights { JournalInsights.week(weekEntries.map(\.insightSample), endingOn: .now) }

    var body: some View {
        NavigationStack(path: $path) {
            chooseStep
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .preview: previewStep
                    case .done: doneStep
                    }
                }
        }
        .onAppear(perform: prefill)
    }

    // MARK: Step 1 — choose

    private var chooseStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Here's your week")
                        .font(.screenTitle)
                        .foregroundStyle(Color.ink)
                    Text("Before your visit with \(recipient.fullName) \(DateText.dayAndTime(visit.start).lowercasedFirst). Nothing is shared until you confirm on the next screen.")
                        .secondaryText()
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    ForEach(week.sentences, id: \.self) { Text($0).foregroundStyle(Color.ink) }
                }
                .card()

                VStack(spacing: 0) {
                    Toggle("Mood over the last 7 days", isOn: $includeMood)
                        .padding(.vertical, Spacing.xs)
                    Divider()
                    Toggle("Feelings you named most", isOn: $includeFeelings)
                        .padding(.vertical, Spacing.xs)
                }
                .tint(Color.brandPrimary)
                .foregroundStyle(Color.ink)
                .card(padding: Spacing.m)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Entries to include")
                    Text("Off unless you choose them. Entries you already share are pre-selected.")
                        .secondaryText()
                    if writtenEntries.isEmpty {
                        Text("No written entries this week.")
                            .secondaryText()
                    }
                    ForEach(writtenEntries) { entry in
                        Toggle(isOn: binding(for: entry.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateText.dayHeading(entry.createdAt))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.inkSecondary)
                                Text(entry.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ink)
                                    .lineLimit(3)
                                    .privacySensitive()
                            }
                        }
                        .tint(Color.brandPrimary)
                        .card(padding: Spacing.m)
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.xs) {
                Button("Preview what will be shared") { path.append(.preview) }
                    .buttonStyle(.pill(arrow: true))
                    .disabled(!includeMood && !includeFeelings && includedEntryIDs.isEmpty)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .background(Color.appBackground.opacity(0.96))
        }
        .navigationTitle("Prepare for your visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { NeedHelpButton() }
        }
    }

    // MARK: Step 2 — preview exactly

    private var previewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                InfoNote(systemImage: "eye", text: "This is exactly what \(recipient.fullName) will see. Nothing else from your journal is included.")

                Text(summaryText)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .privacySensitive()
                    .card()
                    .accessibilityLabel(Text("Summary to share"))
                    .accessibilityValue(Text(summaryText))
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.xs) {
                Button("Share with \(recipient.shortName)") { share() }
                    .buttonStyle(.pill())
                Button("Keep private") { dismiss() }
                    .buttonStyle(.pill(.secondary))
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .background(Color.appBackground.opacity(0.96))
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NeedHelpButton() } }
    }

    private var doneStep: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            MoodFace(level: .good, size: 110).accessibilityHidden(true)
            Text("Shared with \(recipient.fullName)")
                .font(.screenTitle)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Text("You can stop sharing at any time in Profile → Privacy centre.")
                .secondaryText()
                .multilineTextAlignment(.center)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.pill())
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity)
        .screenBackground()
        .navigationBarBackButtonHidden()
    }

    // MARK: Content

    /// The single source for both the preview and what gets stored/shared.
    private var summaryText: String {
        var lines: [String] = []
        let start = periodStart.formatted(.dateTime.day().month(.abbreviated))
        let end = Date.now.formatted(.dateTime.day().month(.abbreviated))
        lines.append(String(localized: "Week of \(start) – \(end), shared by \(services.directory.patient.fullName)"))

        if includeMood {
            let daily = JournalInsights.dailyMoods(weekEntries.map(\.insightSample))
            let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: .now)) }
            let moodLine = days.map { day -> String in
                let name = day.formatted(.dateTime.weekday(.abbreviated))
                return "\(name): \(daily[day]?.label ?? "–")"
            }.joined(separator: " · ")
            lines.append("")
            lines.append(String(localized: "Mood: \(moodLine)"))
        }

        if includeFeelings, !week.topEmotions.isEmpty {
            lines.append("")
            lines.append(String(localized: "Feelings named most: \(week.topEmotions.map(\.label).joined(separator: ", "))"))
        }

        let chosen = writtenEntries.filter { includedEntryIDs.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
        if !chosen.isEmpty {
            lines.append("")
            lines.append(String(localized: "Entries:"))
            for entry in chosen {
                lines.append("• \(DateText.dayHeading(entry.createdAt)): \(entry.text)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { includedEntryIDs.contains(id) },
            set: { isOn in
                if isOn { includedEntryIDs.insert(id) } else { includedEntryIDs.remove(id) }
            }
        )
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        includedEntryIDs = Set(writtenEntries.filter(\.isShared).map(\.id))
    }

    private func share() {
        let chosenIDs = Array(includedEntryIDs)
        let summary = SharedSummary(
            recipientName: recipient.fullName,
            periodStart: periodStart,
            periodEnd: .now,
            content: summaryText,
            entryIDs: chosenIDs
        )
        modelContext.insert(summary)
        for entry in writtenEntries where includedEntryIDs.contains(entry.id) && !entry.isShared {
            entry.setShared(true)
        }
        try? modelContext.save()
        // MOCK: production uploads the summary over an E2EE channel and writes an audit entry.
        path.append(.done)
    }
}

#Preview("Pre-visit summary") {
    PreVisitSummaryView(visit: MockData.visits(now: .now).first { $0.start > .now }!)
        .previewEnvironment()
}
