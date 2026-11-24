import SwiftUI
import EventKit
import EventKitUI

struct VisitDetailView: View {
    let visitID: Visit.ID

    @Environment(AppServices.self) private var services
    @State private var showSummary = false
    @State private var showCalendar = false
    @State private var onlineVisit: Visit?
    @State private var pendingChange: VisitChangeRequest?
    @State private var isSending = false

    private var visit: Visit? { services.visits.visits.first { $0.id == visitID } }

    var body: some View {
        Group {
            if let visit {
                content(visit)
            } else {
                ContentUnavailableView("Visit not found", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .screenBackground()
        .navigationTitle("Visit")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ visit: Visit) -> some View {
        let clinician = services.directory.clinician(visit.clinicianID)
        let isUpcoming = visit.end >= .now && visit.status != .completed
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(visit.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                    Text(DateText.dayAndTime(visit.start))
                        .font(.screenTitle)
                        .foregroundStyle(Color.ink)
                    Text("\(visit.durationMinutes) minutes")
                        .secondaryText()
                    if let note = visit.status.note {
                        InfoNote(systemImage: "clock.arrow.circlepath", text: LocalizedStringKey(note))
                    }
                }

                if let clinician {
                    HStack(spacing: Spacing.s) {
                        ClinicianPhoto(clinician: clinician, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(clinician.fullName).font(.headline)
                            Text(clinician.role.label).font(.subheadline).foregroundStyle(Color.inkSecondary)
                        }
                        .foregroundStyle(Color.ink)
                    }
                    .card(padding: Spacing.m)
                    .accessibilityElement(children: .combine)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label(visit.kind.label, systemImage: visit.kind.systemImage)
                        .font(.headline)
                    switch visit.kind {
                    case .online:
                        Text("You'll join from this app. Before the call we'll ask where you are right now, so help can reach you in an emergency.")
                            .font(.subheadline)
                    case .inPerson(let room):
                        Text("Room \(room), first floor")
                            .font(.subheadline)
                        Text(services.directory.address)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .foregroundStyle(Color.ink)
                .card(padding: Spacing.m)

                if isUpcoming { actions(visit) }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
        }
        .sheet(isPresented: $showSummary) { PreVisitSummaryView(visit: visit) }
        .sheet(isPresented: $showCalendar) {
            AddToCalendarSheet(
                start: visit.start,
                end: visit.end,
                location: visit.kind.isOnline ? String(localized: "Online") : services.directory.address
            ) { showCalendar = false }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $onlineVisit) { OnlineVisitFlow(visit: $0) }
        .confirmationDialog(
            pendingChange == .cancel ? "Ask the clinic to cancel this visit?" : "Ask the clinic for a new time?",
            isPresented: Binding(get: { pendingChange != nil }, set: { if !$0 { pendingChange = nil } }),
            titleVisibility: .visible,
            presenting: pendingChange
        ) { change in
            Button(change == .cancel ? "Request cancellation" : "Request new time") {
                Task {
                    isSending = true
                    await services.visits.requestChange(change, for: visit.id)
                    isSending = false
                }
            }
            Button("Keep this visit", role: .cancel) {}
        } message: { _ in
            Text("This sends a request. The clinic will confirm with you.")
        }
    }

    @ViewBuilder
    private func actions(_ visit: Visit) -> some View {
        VStack(spacing: Spacing.s) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                if visit.kind.isOnline {
                    let canJoin = visit.canJoin(at: context.date)
                    VStack(spacing: Spacing.xs) {
                        Button {
                            onlineVisit = visit
                        } label: {
                            Label("Join online visit", systemImage: "video.fill")
                        }
                        .buttonStyle(.pill())
                        .disabled(!canJoin)
                        if !canJoin {
                            Text("You can join from 10 minutes before the start.")
                                .font(.footnote)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                }
            }

            Button {
                showSummary = true
            } label: {
                Label("Prepare for this visit", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.pill(visit.kind.isOnline ? .secondary : .primary))

            Button {
                showCalendar = true
            } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.pill(.quiet))

            if visit.status == .scheduled {
                HStack(spacing: Spacing.s) {
                    Button("Reschedule") { pendingChange = .reschedule }
                    Button("Cancel visit") { pendingChange = .cancel }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandPrimaryStrong)
                .frame(minHeight: minTapTarget)
                .disabled(isSending)
            }
        }
    }
}

/// System "add event" sheet. On iOS 17+ it runs out of process and needs no calendar
/// permission. PRIVACY: the default title is a neutral "Appointment" — calendars are
/// often visible to family or colleagues. The patient can edit it before saving.
struct AddToCalendarSheet: UIViewControllerRepresentable {
    let start: Date
    let end: Date
    let location: String
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = String(localized: "Appointment")
        event.startDate = start
        event.endDate = end
        event.location = location
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}

private struct VisitDetailPreview: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        NavigationStack {
            if let visit = services.visits.visits.next() {
                VisitDetailView(visitID: visit.id)
            }
        }
    }
}

#Preview("Visit detail") {
    VisitDetailPreview().previewEnvironment()
}
