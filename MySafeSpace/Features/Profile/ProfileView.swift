import SwiftUI

enum ProfileRoute: Hashable {
    case emergencyContact, privacy, notifications, prescriptions, safety, terms, privacyPolicy
}

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var appState = appState
        let patient = services.directory.patient
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Spacing.m) {
                        AvatarView(initials: patient.initials, fill: .brandSecondary, imageName: "patient-anna")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(patient.fullName).font(.title3.weight(.semibold))
                            Text("\(patient.age) · \(patient.city)").secondaryText()
                        }
                        .foregroundStyle(Color.ink)
                    }
                    .padding(.vertical, Spacing.xxs)
                    .accessibilityElement(children: .combine)
                }

                Section("Your care team") {
                    // Only the patient's two lead clinicians. Other clinic doctors are under Book a visit.
                    ForEach(services.directory.careTeam) { clinician in
                        NavigationLink {
                            DoctorDetailView(clinicianID: clinician.id)
                        } label: {
                            HStack(spacing: Spacing.s) {
                                ClinicianPhoto(clinician: clinician, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(clinician.fullName).font(.headline)
                                    Text(clinician.role.label).font(.subheadline).foregroundStyle(Color.inkSecondary)
                                }
                                .foregroundStyle(Color.ink)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Text(services.directory.clinicName)
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }

                Section {
                    row(.emergencyContact, title: "Emergency contact", symbol: "person.crop.circle.badge.checkmark",
                        detail: appState.settings.emergencyContact?.name ?? String(localized: "Not set"))
                    row(.prescriptions, title: "Prescriptions", symbol: "pills")
                    row(.privacy, title: "Privacy centre", symbol: "lock.shield")
                    row(.notifications, title: "Notifications", symbol: "bell")
                }

                Section {
                    Button {
                        appState.presentCrisis()
                    } label: {
                        Label("Need help now", systemImage: "lifepreserver")
                            .foregroundStyle(Color.brandPrimaryStrong)
                    }
                    row(.safety, title: "About the safety features", symbol: "heart.text.square")
                }

                Section("Legal") {
                    row(.terms, title: "Terms of use", symbol: "doc.text")
                    row(.privacyPolicy, title: "Privacy policy", symbol: "hand.raised")
                }

                Section {
                    Picker("Mood check-in style", selection: $appState.settings.moodCheckInStyle) {
                        ForEach(MoodCheckInStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    Button("Show onboarding again") { appState.replayOnboarding() }
                } header: {
                    Text("Research & demo")
                } footer: {
                    Text("Used in usability tests to compare the Home card with a launch pop-up. Version 1.0 (portfolio build, mock data).")
                }
            }
            .listStyle(.insetGrouped)
            .listScreenBackground()
            .navigationTitle("Profile")
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .emergencyContact: EmergencyContactEditor()
                case .privacy: PrivacyCentreView()
                case .notifications: NotificationSettingsView()
                case .prescriptions: PrescriptionsView()
                case .safety: SafetyInfoView()
                case .terms: LegalView(document: .terms)
                case .privacyPolicy: LegalView(document: .privacy)
                }
            }
        }
    }

    private func row(_ route: ProfileRoute, title: LocalizedStringKey, symbol: String, detail: String? = nil) -> some View {
        NavigationLink(value: route) {
            HStack {
                Label(title, systemImage: symbol)
                    .foregroundStyle(Color.ink)
                Spacer()
                if let detail {
                    Text(detail)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Emergency contact

struct EmergencyContactEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Someone you trust. Your care team would only contact them if they were seriously worried about your safety. You can call them from the crisis screen too.")
                    .foregroundStyle(Color.ink)
                EmergencyContactFields(name: $name, phone: $phone)
                if appState.settings.emergencyContact != nil {
                    Button("Remove contact", role: .destructive) {
                        appState.settings.emergencyContact = nil
                        dismiss()
                    }
                    .frame(minHeight: minTapTarget)
                }
            }
            .padding(Spacing.screen)
        }
        .screenBackground()
        .hidesFloatingHelpButton()
        .safeAreaInset(edge: .bottom) {
            Button("Save") {
                appState.settings.emergencyContact = EmergencyContact(name: name, phone: phone)
                dismiss()
            }
            .buttonStyle(.pill())
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phone.filter(\.isNumber).count < 6)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
        }
        .navigationTitle("Emergency contact")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            name = appState.settings.emergencyContact?.name ?? ""
            phone = appState.settings.emergencyContact?.phone ?? ""
        }
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @State private var permissionDenied = false

    var body: some View {
        Form {
            Section {
                NotificationPreview()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                Text("Every reminder looks like this. No medication names, nothing you've written, nothing that reveals what the app is for.")
            }

            reminderSection(
                title: "Daily check-in reminder",
                kind: .dailyCheckIn,
                keyPath: \.dailyCheckInReminder,
                defaultTime: ReminderTime(hour: 20, minute: 0)
            )
            reminderSection(
                title: "Medication reminder",
                kind: .medication,
                keyPath: \.medicationReminder,
                defaultTime: ReminderTime(hour: 8, minute: 0)
            )

            if permissionDenied {
                Section {
                    Text("Notifications are turned off for MySafeSpace. You can allow them in the Settings app.")
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .listScreenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reminderSection(title: LocalizedStringKey, kind: ReminderKind, keyPath: WritableKeyPath<AppSettings, ReminderTime?>, defaultTime: ReminderTime) -> some View {
        let isOn = Binding<Bool>(
            get: { appState.settings[keyPath: keyPath] != nil },
            set: { enabled in
                if enabled {
                    Task {
                        // Permission is pre-explained on this screen before the system prompt.
                        var granted = await services.notifications.isAuthorized()
                        if !granted { granted = await services.notifications.requestAuthorization() }
                        guard granted else { permissionDenied = true; return }
                        appState.settings[keyPath: keyPath] = defaultTime
                        await services.notifications.schedule(kind, at: defaultTime)
                    }
                } else {
                    appState.settings[keyPath: keyPath] = nil
                    services.notifications.cancel(kind)
                }
            }
        )
        let time = Binding<Date>(
            get: { appState.settings[keyPath: keyPath]?.date ?? defaultTime.date },
            set: { newDate in
                let reminder = ReminderTime(date: newDate)
                appState.settings[keyPath: keyPath] = reminder
                Task { await services.notifications.schedule(kind, at: reminder) }
            }
        )
        return Section {
            Toggle(title, isOn: isOn)
                .tint(Color.brandPrimary)
            if isOn.wrappedValue {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
            }
        }
    }
}

// MARK: - Safety info & legal

struct SafetyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                infoBlock("Not monitored 24/7", "MySafeSpace is not monitored in real time (24/7). If your life or someone else's life is in danger, call 112.")
                infoBlock("What crisis detection does", "When you save a journal entry or send a message, the app checks the words on your iPhone for signs that you might be in danger. If it finds them, it shows you support numbers. It never stops you saving or sending, and never changes what you wrote.")
                infoBlock("What it doesn't do", "It doesn't send your words anywhere. It never calls the police or emergency services. It isn't a diagnosis, and it can miss things or misunderstand them.")
                infoBlock("Safety alerts (only if you turn them on)", "If you opt in, the clinic gets a short note – \"may need contact\" with the date and time – never what you wrote. A person at the clinic then decides whether to reach out. You can turn this off anytime in the Privacy centre.")
                infoBlock("Reviewed by clinicians", "The words the app looks for will be reviewed by psychiatrists before this app is used with patients.")
            }
            .padding(Spacing.screen)
        }
        .screenBackground()
        .navigationTitle("Safety features")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoBlock(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(body).font(.body)
        }
        .foregroundStyle(Color.ink)
        .card()
    }
}

struct LegalView: View {
    enum Document { case terms, privacy }
    let document: Document

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Placeholder text for the portfolio build – to be replaced by documents prepared by the clinic's lawyer.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                switch document {
                case .terms:
                    Text("**1. What this app is.** MySafeSpace supports your care at MySafeSpace Mental Health Clinic between visits. It does not replace treatment or emergency services.")
                    Text("**2. Not monitored 24/7.** MySafeSpace is not monitored in real time. If your life or someone else's life is in danger, call 112.")
                    Text("**3. Messages.** Messages are answered during office hours. Response times are shown in each conversation.")
                    Text("**4. Prescriptions.** An extension request is reviewed by your doctor, who decides whether to renew.")
                case .privacy:
                    Text("**Controller.** MySafeSpace Mental Health Clinic, ul. Przykładowa 12, Warsaw (fictional).")
                    Text("**Special-category data (GDPR Art. 9).** Health information is processed only to provide your care, on the basis of Art. 9(2)(h) GDPR and Polish law on medical confidentiality.")
                    Text("**Your journal.** Stored on your device, private by default. Shared only when you choose, and you can withdraw sharing at any time.")
                    Text("**Your rights.** Access, rectification, erasure, restriction, data portability and complaint to the President of the Personal Data Protection Office (UODO).")
                }
            }
            .foregroundStyle(Color.ink)
            .padding(Spacing.screen)
        }
        .screenBackground()
        .navigationTitle(document == .terms ? String(localized: "Terms of use") : String(localized: "Privacy policy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Profile") {
    ProfileView().previewEnvironment()
}

#Preview("Notifications") {
    NavigationStack { NotificationSettingsView() }.previewEnvironment()
}
