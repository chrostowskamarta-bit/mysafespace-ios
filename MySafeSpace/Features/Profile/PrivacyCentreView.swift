import SwiftUI
import SwiftData

/// One place to see and control everything: app lock, what's shared (revoke each),
/// safety-alert consent, export and deletion.
struct PrivacyCentreView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<JournalEntry> { $0.isShared }, sort: \JournalEntry.createdAt, order: .reverse)
    private var sharedEntries: [JournalEntry]
    @Query(sort: \SharedSummary.createdAt, order: .reverse) private var summaries: [SharedSummary]
    @Query private var allEntries: [JournalEntry]

    @State private var showExport = false
    @State private var showDelete = false
    @State private var deleteConfirmation = ""
    @State private var lockError: String?

    var body: some View {
        @Bindable var appState = appState
        Form {
            Section {
                Toggle(isOn: lockBinding) {
                    Label("Lock with \(services.auth.biometryName)", systemImage: "faceid")
                }
                if appState.settings.appLockEnabled {
                    Picker("Lock after leaving the app", selection: $appState.settings.autoLockMinutes) {
                        Text("Immediately").tag(0)
                        Text("After 1 minute").tag(1)
                        Text("After 5 minutes").tag(5)
                        Text("After 15 minutes").tag(15)
                    }
                }
                if let lockError {
                    Text(lockError).font(.footnote).foregroundStyle(Color.inkSecondary)
                }
            } header: {
                Text("App lock")
            } footer: {
                Text("When you leave MySafeSpace, the screen is always hidden in the app switcher.")
            }

            Section {
                if sharedEntries.isEmpty && summaries.isEmpty {
                    Text("Nothing is shared. Your journal is completely private.")
                        .foregroundStyle(Color.inkSecondary)
                }
                ForEach(summaries) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly summary for \(summary.recipientName)")
                            .font(.headline)
                        Text("Shared \(summary.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                        Button("Stop sharing", role: .destructive) { revoke(summary) }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: minTapTarget)
                    }
                    .foregroundStyle(Color.ink)
                }
                ForEach(sharedEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DateText.dayHeading(entry.createdAt))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.inkSecondary)
                        Text(entry.text.isEmpty ? String(localized: "Check-in") : entry.text)
                            .lineLimit(2)
                            .privacySensitive()
                        Button("Stop sharing", role: .destructive) { entry.setShared(false) }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: minTapTarget)
                    }
                    .foregroundStyle(Color.ink)
                    .swipeActions {
                        Button("Stop sharing") { entry.setShared(false) }.tint(Color.inkSecondary)
                    }
                }
            } header: {
                Text("Shared with your care team")
            } footer: {
                Text("Stopping sharing removes access from now on.")
            }

            Section {
                Toggle(isOn: $appState.settings.safetyAlertConsent) {
                    Text("Let my clinic know if I may need support")
                }
                NavigationLink("How safety alerts work") { SafetyInfoView() }
            } header: {
                Text("Safety alerts")
            } footer: {
                Text("Off by default. If on, the clinic gets a note with the date and time only – never what you wrote. The app never contacts the police or emergency services.")
            }

            Section {
                Button("Export my data") { showExport = true }
                Button("Delete my journal", role: .destructive) { showDelete = true }
            } header: {
                Text("Your data")
            } footer: {
                Text("Deleting removes all entries and check-ins from this iPhone and withdraws everything you've shared.")
            }
        }
        .tint(Color.brandPrimary)
        .listScreenBackground()
        .navigationTitle("Privacy centre")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExport) { ExportPreviewView() }
        .alert("Delete your whole journal?", isPresented: $showDelete) {
            TextField("Type DELETE", text: $deleteConfirmation)
                .textInputAutocapitalization(.characters)
            Button("Delete everything", role: .destructive) {
                if deleteConfirmation.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE" { deleteJournal() }
                deleteConfirmation = ""
            }
            Button("Cancel", role: .cancel) { deleteConfirmation = "" }
        } message: {
            Text("This can't be undone. Type DELETE to confirm.")
        }
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.appLockEnabled },
            set: { enabled in
                Task {
                    // Changing the lock always requires authentication.
                    let reason = enabled ? String(localized: "Turn on app lock") : String(localized: "Turn off app lock")
                    if await services.auth.authenticate(reason: reason) {
                        appState.settings.appLockEnabled = enabled
                        lockError = nil
                    } else {
                        lockError = String(localized: "Couldn't verify it's you. Nothing was changed.")
                    }
                }
            }
        )
    }

    private func revoke(_ summary: SharedSummary) {
        let ids = Set(summary.entryIDs)
        for entry in sharedEntries where ids.contains(entry.id) { entry.setShared(false) }
        modelContext.delete(summary)
        try? modelContext.save()
        // MOCK: production revokes server-side access and writes an audit entry.
    }

    private func deleteJournal() {
        for entry in allEntries { modelContext.delete(entry) }
        for summary in summaries { modelContext.delete(summary) }
        try? modelContext.save()
    }
}

/// MOCK: shows what an export would contain. Production generates a file the patient can save.
struct ExportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query(sort: \JournalEntry.createdAt) private var entries: [JournalEntry]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    InfoNote(systemImage: "doc.text", text: "Preview of your export (JSON). In the full app you'd save this file or a PDF to a place you choose.")
                    Text(exportJSON)
                        .font(.footnote.monospaced())
                        .foregroundStyle(Color.ink)
                        .textSelection(.enabled)
                        .privacySensitive()
                        .card(padding: Spacing.m)
                }
                .padding(Spacing.screen)
            }
            .screenBackground()
            .navigationTitle("Export my data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var exportJSON: String {
        let formatter = ISO8601DateFormatter()
        let items: [[String: Any]] = entries.map { entry in
            var item: [String: Any] = [
                "date": formatter.string(from: entry.createdAt),
                "type": entry.isCheckIn ? "check-in" : "entry",
                "shared": entry.isShared,
            ]
            if let mood = entry.mood { item["mood"] = mood.rawValue }
            if !entry.text.isEmpty { item["text"] = entry.text }
            if !entry.emotions.isEmpty { item["feelings"] = entry.emotions.map(\.rawValue) }
            return item
        }
        let root: [String: Any] = [
            "exportedAt": formatter.string(from: .now),
            "safetyAlertConsent": appState.settings.safetyAlertConsent,
            "entries": items,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}

#Preview("Privacy centre") {
    NavigationStack { PrivacyCentreView() }.previewEnvironment()
}
