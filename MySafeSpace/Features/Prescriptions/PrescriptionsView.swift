import SwiftUI

struct PrescriptionsView: View {
    @Environment(AppServices.self) private var services
    @State private var showRequest = false

    private var prescriptions: [Prescription] { services.prescriptions.prescriptions }
    private var canRequestAny: Bool { prescriptions.contains { $0.renewal.canRequest } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                ForEach(prescriptions) { prescription in
                    PrescriptionCard(
                        prescription: prescription,
                        prescriber: services.directory.clinician(prescription.prescriberID)
                    )
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("How renewals work")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    InfoNote(systemImage: "person.fill.checkmark", text: "Your doctor reviews every request – it's a request, not an automatic renewal.")
                    InfoNote(systemImage: "calendar", text: "For some medicines, your doctor may want to see you before renewing.")
                    InfoNote(systemImage: "number", text: "When approved, you'll get an e-prescription code by SMS or e-mail and in your IKP patient account. Show it with your PESEL at any pharmacy.")
                }
                .card()

                // In the content (not pinned to the bottom) so the floating help button never covers it.
                Button("Request extension") { showRequest = true }
                    .buttonStyle(.pill(arrow: true))
                    .disabled(!canRequestAny)

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    HStack {
                        Label("Medication reminders", systemImage: "bell")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .card(padding: Spacing.m)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.xl + minTapTarget)
        }
        .screenBackground()
        .navigationTitle("Prescriptions")
        .sheet(isPresented: $showRequest) { RequestExtensionSheet() }
    }
}

struct PrescriptionCard: View {
    let prescription: Prescription
    let prescriber: Clinician?

    var body: some View {
        let days = prescription.daysRemaining()
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(prescription.medication) \(prescription.dose)")
                    .font(.cardTitle)
                Spacer()
                Image(systemName: "pills.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ink)
            Text(prescription.schedule)
                .secondaryText()

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ProgressView(value: prescription.remainingFraction())
                    .tint(days <= 10 ? Color.brandPrimaryStrong : Color.brandPrimary)
                    .accessibilityHidden(true)
                Text(days == 1 ? String(localized: "1 day left") : String(localized: "\(days) days left"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
            }

            if let prescriber {
                Text("Prescribed by \(prescriber.fullName)")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
            }

            RenewalStatusView(status: prescription.renewal, prescriberName: prescriber?.shortName ?? "")
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct RenewalStatusView: View {
    let status: RenewalStatus
    let prescriberName: String

    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .requested(let date):
            statusRow(symbol: "hourglass", title: "Extension requested", detail: "Sent \(date.formatted(date: .abbreviated, time: .omitted)). \(prescriberName) will review it.")
        case .visitNeeded:
            statusRow(symbol: "calendar.badge.clock", title: "\(prescriberName) would like to see you before renewing", detail: "Reception will contact you to book a visit.")
        case .approved(let code, _):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("Approved", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Color.onBrandSecondary)
                HStack(alignment: .firstTextBaseline) {
                    Text("e-Prescription code")
                        .font(.subheadline)
                    Spacer()
                    Text(code)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .privacySensitive()
                        .accessibilityLabel(Text(code.map(String.init).joined(separator: " ")))
                }
                .foregroundStyle(Color.onBrandSecondary)
                Text("Also sent by SMS/e-mail and to your IKP account.")
                    .font(.footnote)
                    .foregroundStyle(Color.onBrandSecondary)
            }
            .padding(Spacing.s)
            .background(Color.brandSecondary, in: .rect(cornerRadius: Radius.small, style: .continuous))
        }
    }

    private func statusRow(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(Color.brandPrimaryStrong)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(Color.inkSecondary)
            }
            .foregroundStyle(Color.ink)
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceMuted, in: .rect(cornerRadius: Radius.small, style: .continuous))
    }
}

struct RequestExtensionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var services
    @State private var selection: Set<Prescription.ID> = []
    @State private var note = ""
    @State private var isSending = false
    @State private var sent = false

    private var lead: Clinician { services.directory.lead }

    var body: some View {
        NavigationStack {
            Group {
                if sent { confirmation } else { form }
            }
            .screenBackground()
            .navigationTitle("Request extension")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { NeedHelpButton() }
            }
        }
        .onAppear {
            selection = Set(services.prescriptions.prescriptions.filter { $0.renewal.canRequest && $0.daysRemaining() <= 14 }.map(\.id))
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Which prescriptions would you like \(lead.shortName) to review?")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                ForEach(services.prescriptions.prescriptions) { prescription in
                    Toggle(isOn: binding(prescription.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(prescription.medication) \(prescription.dose)").font(.headline)
                            if prescription.renewal.isPending {
                                Text("Already requested").font(.footnote).foregroundStyle(Color.inkSecondary)
                            } else {
                                Text("\(prescription.daysRemaining()) days left").font(.footnote).foregroundStyle(Color.inkSecondary)
                            }
                        }
                        .foregroundStyle(Color.ink)
                    }
                    .tint(Color.brandPrimary)
                    .disabled(!prescription.renewal.canRequest)
                    .card(padding: Spacing.m)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Note for \(lead.shortName) (optional)")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    TextField("e.g. side effects, questions", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(Spacing.m)
                        .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
                        .foregroundStyle(Color.ink)
                }
                InfoNote(systemImage: "info.circle", text: "\(lead.shortName) decides whether to renew. Some medicines need a visit first.")
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    isSending = true
                    await services.prescriptions.requestRenewal(of: selection, note: note)
                    isSending = false
                    withAnimation { sent = true }
                }
            } label: {
                if isSending { ProgressView().tint(Color.onBrandPrimary) } else { Text("Send request") }
            }
            .buttonStyle(.pill())
            .disabled(selection.isEmpty || isSending)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .background(Color.appBackground.opacity(0.96))
        }
    }

    private var confirmation: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)
            Text("Request sent")
                .font(.screenTitle)
                .foregroundStyle(Color.ink)
            Text("\(lead.fullName) will review it. When approved, you'll receive your e-prescription code by SMS or e-mail and in your IKP patient account.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ink)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.pill())
        }
        .padding(Spacing.l)
    }

    private func binding(_ id: Prescription.ID) -> Binding<Bool> {
        Binding(
            get: { selection.contains(id) },
            set: { if $0 { selection.insert(id) } else { selection.remove(id) } }
        )
    }
}

#Preview("Prescriptions") {
    NavigationStack { PrescriptionsView() }.previewEnvironment()
}

#Preview("Request extension") {
    RequestExtensionSheet().previewEnvironment()
}
