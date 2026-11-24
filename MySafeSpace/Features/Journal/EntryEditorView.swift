import SwiftUI
import SwiftData

/// The note for one day (the journal lives in the Calendar). Written or recorded:
/// voice is turned into text on the iPhone and the audio is never stored.
/// Mood optional, sharing off by default — the therapist sees a note only if the patient shares it.
///
/// Crisis detection:
/// - while typing (after a 1.5 s pause): a gentle, dismissible inline card — never a
///   full-screen interruption mid-sentence. DECISION: trauma-informed; the writer stays in control.
/// - on save: the entry is saved FIRST (never blocked, never altered), then full-screen
///   support appears if the assessment is medium/high.
struct EntryEditorView: View {
    let entry: JournalEntry?
    /// The day a new note belongs to (defaults to today).
    var day: Date? = nil
    /// Opened from "Record": starts dictation straight away.
    var startsRecording = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services

    @State private var text: String
    @State private var mood: MoodLevel?
    @State private var emotions: Set<Emotion>
    @State private var isShared: Bool
    @State private var showFeelings: Bool
    @State private var gentleSupport = false
    @State private var supportDismissed = false
    @State private var dictation = OnDeviceDictation()
    @FocusState private var textFocused: Bool

    init(entry: JournalEntry?, day: Date? = nil, startsRecording: Bool = false) {
        self.entry = entry
        self.day = day
        self.startsRecording = startsRecording
        _text = State(initialValue: entry?.text ?? "")
        _mood = State(initialValue: entry?.mood)
        _emotions = State(initialValue: Set(entry?.emotions ?? []))
        _isShared = State(initialValue: entry?.isShared ?? false)
        _showFeelings = State(initialValue: !(entry?.emotions.isEmpty ?? true))
    }

    private var recipient: Clinician { services.directory.journalRecipient }
    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mood != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Text("Note for \(noteDayText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                    if gentleSupport && !supportDismissed {
                        GentleSupportCard { supportDismissed = true }
                    }

                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("What's on your mind?")
                                .foregroundStyle(Color.inkSecondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .accessibilityHidden(true)
                        }
                        TextEditor(text: $text)
                            .focused($textFocused)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 200)
                            .foregroundStyle(Color.ink)
                            .privacySensitive()
                            .accessibilityLabel("Note")
                    }
                    .padding(Spacing.s)
                    .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))

                    voiceNote

                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("Mood (optional)")
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                        MoodRow(selection: mood, faceSize: 40) { selected in
                            mood = (mood == selected) ? nil : selected
                        }
                    }
                    .card(padding: Spacing.m)

                    feelings

                    shareSection
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
            }
            .screenBackground()
            .navigationTitle(entry == nil ? String(localized: "New note") : String(localized: "Edit note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { NeedHelpButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .task(id: text) {
                // Typing pause → gentle inline support only.
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                let assessment = services.crisisDetector.assess(text)
                withAnimation(.easeInOut(duration: 0.25)) {
                    gentleSupport = assessment.shouldShowGentleSupport
                }
            }
            .onAppear {
                if startsRecording {
                    Task { await dictation.start() }
                } else if entry == nil {
                    textFocused = true
                }
            }
            .onChange(of: dictation.isRecording) { wasRecording, isRecording in
                if wasRecording && !isRecording { appendTranscript() }
            }
            .onDisappear { dictation.stop() }
        }
    }

    private var noteDay: Date { entry?.createdAt ?? day ?? .now }

    /// "today" / "yesterday" mid-sentence, otherwise "Monday 9 November".
    private var noteDayText: String {
        let calendar = Calendar.clinic
        let heading = DateText.dayHeading(noteDay)
        return calendar.isDateInToday(noteDay) || calendar.isDateInYesterday(noteDay) ? heading.lowercased() : heading
    }

    // MARK: Voice note

    private var voiceNote: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                Task { await dictation.toggle() }
            } label: {
                Label(dictation.isRecording ? LocalizedStringKey("Stop recording") : LocalizedStringKey("Record a voice note"),
                      systemImage: dictation.isRecording ? "stop.circle.fill" : "mic")
            }
            .buttonStyle(.pill(dictation.isRecording ? .primary : .quiet))
            .accessibilityHint("Your voice is turned into text on this iPhone. The recording isn't saved.")

            if dictation.isRecording && !dictation.transcript.isEmpty {
                Text(dictation.transcript)
                    .font(.body)
                    .foregroundStyle(Color.inkSecondary)
                    .privacySensitive()
                    .accessibilityLabel(Text("Live transcript: \(dictation.transcript)"))
            }
            if case .unavailable(let message) = dictation.status {
                InfoNote(systemImage: "exclamationmark.circle", text: LocalizedStringKey(message))
            }
            InfoNote(systemImage: "lock", text: "Your voice is turned into text on this iPhone. The recording is never saved or sent.")
        }
    }

    private func appendTranscript() {
        let spoken = dictation.consumeTranscript()
        guard !spoken.isEmpty else { return }
        let current = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = current.isEmpty ? spoken : current + " " + spoken
    }

    private var feelings: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showFeelings.toggle() }
            } label: {
                HStack {
                    Text("Feelings (optional)").font(.headline)
                    Spacer()
                    Image(systemName: showFeelings ? "chevron.up" : "chevron.down")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.ink)
                .frame(minHeight: minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if showFeelings {
                FlowLayout {
                    ForEach(Emotion.suggested(for: mood ?? .okay)) { emotion in
                        Chip(title: emotion.label, isSelected: emotions.contains(emotion)) {
                            if emotions.contains(emotion) { emotions.remove(emotion) } else { emotions.insert(emotion) }
                        }
                    }
                }
            }
        }
        .card(padding: Spacing.m)
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Toggle(isOn: $isShared) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share with \(recipient.fullName)")
                        .font(.headline)
                    Text(isShared
                         ? "They'll be able to read this note. You can stop sharing anytime."
                         : "Private – only you can see this note.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
                .foregroundStyle(Color.ink)
            }
            .tint(Color.brandPrimary)
        }
        .card(padding: Spacing.m)
    }

    private func save() {
        if dictation.isRecording {
            dictation.stop()
            appendTranscript()
        }
        let target: JournalEntry
        if let entry {
            target = entry
        } else {
            target = JournalEntry(createdAt: Self.timestamp(for: day))
            modelContext.insert(target)
        }
        target.text = text
        target.mood = mood
        target.emotions = Emotion.allCases.filter { emotions.contains($0) }
        target.updatedAt = .now
        if target.isShared != isShared { target.setShared(isShared) }
        try? modelContext.save()

        let assessment = services.crisisDetector.assess(text)
        let entryID = target.id
        dismiss()
        appState.handle(assessment, source: .journal, key: "entry-\(entryID)", safetyAlerts: services.safetyAlerts)
    }
}

extension EntryEditorView {
    /// Today → now. Another day → 20:00 that day, so the note sorts into the right day.
    static func timestamp(for day: Date?, calendar: Calendar = .clinic) -> Date {
        guard let day, !calendar.isDateInToday(day) else { return .now }
        return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day) ?? day
    }
}

/// Shown inline while writing. Quiet, dismissible, never blocks.
struct GentleSupportCard: View {
    let onDismiss: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("That sounds really hard.")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: minTapTarget, height: minTapTarget)
                }
                .foregroundStyle(Color.inkSecondary)
                .accessibilityLabel("Dismiss")
            }
            Text("If you'd like to talk to someone now, support is one tap away. Your entry stays private.")
                .font(.subheadline)
                .foregroundStyle(Color.ink)
            Button("See support options") { appState.presentCrisis() }
                .buttonStyle(.pill(.secondary))
        }
        .padding(Spacing.m)
        .background(Color.surfaceMuted, in: .rect(cornerRadius: Radius.inner, style: .continuous))
        .transition(.opacity)
    }
}

#Preview("New entry") {
    EntryEditorView(entry: nil).previewEnvironment()
}
