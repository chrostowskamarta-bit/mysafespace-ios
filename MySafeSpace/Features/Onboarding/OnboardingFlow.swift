import SwiftUI

/// First launch. No account creation (the mock patient is signed in) and no setup data
/// beyond what's needed. Everything optional is clearly skippable.
struct OnboardingFlow: View {
    enum Step: Int, CaseIterable {
        case welcome, privacy, safety, safetyAlert, emergencyContact, appLock, notifications
    }

    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .welcome
    @State private var safetyAcknowledged = false
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var lockMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                progress
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, Spacing.xs)
            }
            ScrollView {
                content
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.l)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .scrollBounceBehavior(.basedOnSize)
            actions
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
        }
        .screenBackground()
    }

    // MARK: Progress

    private var progress: some View {
        HStack(spacing: Spacing.xs) {
            Button {
                go(to: Step(rawValue: step.rawValue - 1) ?? .welcome)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: minTapTarget, height: minTapTarget)
            }
            .foregroundStyle(Color.ink)
            .accessibilityLabel("Back")
            HStack(spacing: 6) {
                ForEach(Step.allCases.dropFirst(), id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color.brandPrimary : Color.surfaceMuted)
                        .frame(height: 6)
                }
            }
            // Narrower stepper, as in Marta's Figma (onboarding screen 4:2).
            .padding(.trailing, 18)
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(step.rawValue) of \(Step.allCases.count - 1)"))
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .privacy: privacy
        case .safety: safety
        case .safetyAlert: safetyAlert
        case .emergencyContact: emergencyContact
        case .appLock: appLock
        case .notifications: notifications
        }
    }

    private var welcome: some View {
        VStack(spacing: Spacing.l) {
            ZStack {
                MoodFace(level: .low, size: 92).offset(x: -78, y: 30)
                MoodFace(level: .great, size: 128)
                MoodFace(level: .okay, size: 80).offset(x: 84, y: 40)
            }
            .frame(height: 200)
            .padding(.top, Spacing.xl)
            .accessibilityHidden(true)
            Text("MySafeSpace")
                .font(.displayTitle)
                .foregroundStyle(Color.ink)
            Text("A calm, private space between your visits.")
                .font(.title3)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
            Text("From MySafeSpace Mental Health Clinic, Warsaw")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var privacy: some View {
        StepLayout(symbol: "lock.shield", title: "Your journal is yours") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Bullet(symbol: "lock.fill", text: "Everything you write is private by default.")
                Bullet(symbol: "hand.raised", text: "You choose what to share, entry by entry – and you can stop sharing at any time.")
                Bullet(symbol: "eye.slash", text: "Your care team does not read your journal in real time.")
                Bullet(symbol: "iphone", text: "Your journal is stored on this iPhone and protected when it's locked.")
            }
        }
    }

    private var safety: some View {
        StepLayout(symbol: "heart.text.square", title: "An important note") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("MySafeSpace is not monitored in real time (24/7). If your life or someone else's life is in danger, call **112**.")
                    .font(.body)
                    .foregroundStyle(Color.ink)
                VStack(spacing: Spacing.xs) {
                    ForEach(Helpline.all) { line in
                        HelplineRow(helpline: line, compact: true)
                    }
                }
                Toggle(isOn: $safetyAcknowledged) {
                    Text("I understand")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                }
                .tint(Color.brandPrimary)
                .padding(Spacing.m)
                .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
            }
        }
    }

    private var safetyAlert: some View {
        @Bindable var appState = appState
        return StepLayout(symbol: "bell.badge", title: "Safety alerts (optional)") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("If something you write suggests you might be in danger, MySafeSpace will always show you support numbers. That happens on your iPhone only.")
                    .foregroundStyle(Color.ink)
                Text("You can also let the app tell your clinic that you may need contact. They would get a short note with the date and time – **never what you wrote**. A person at the clinic then decides whether to reach out.")
                    .foregroundStyle(Color.ink)
                Toggle(isOn: $appState.settings.safetyAlertConsent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Let my clinic know")
                            .font(.headline)
                        Text("Off by default. You can change this anytime in Profile → Privacy.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .foregroundStyle(Color.ink)
                }
                .tint(Color.brandPrimary)
                .padding(Spacing.m)
                .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
            }
        }
    }

    private var emergencyContact: some View {
        StepLayout(symbol: "person.crop.circle.badge.checkmark", title: "Emergency contact") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Someone you trust, who you'd like your care team to be able to reach in an emergency. Recommended, not required.")
                    .foregroundStyle(Color.ink)
                EmergencyContactFields(name: $contactName, phone: $contactPhone)
            }
        }
    }

    private var appLock: some View {
        StepLayout(symbol: "faceid", title: "Lock the app") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Use \(services.auth.biometryName) so only you can open your journal and messages. When you leave the app, it hides what's on screen.")
                    .foregroundStyle(Color.ink)
                if appState.settings.appLockEnabled {
                    Label("App lock is on", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.brandPrimaryStrong)
                }
                if let lockMessage {
                    Text(lockMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }

    private var notifications: some View {
        StepLayout(symbol: "bell", title: "Discreet reminders") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("If you'd like, MySafeSpace can send gentle reminders – for a check-in or your medication.")
                    .foregroundStyle(Color.ink)
                Text("Reminders never mention medication names or anything you've written. They look like this:")
                    .foregroundStyle(Color.ink)
                NotificationPreview()
                Text("You'll choose times later in Profile → Notifications.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    // MARK: Actions (one primary per step)

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Spacing.xs) {
            switch step {
            case .welcome:
                Button("Get started") { go(to: .privacy) }
                    .buttonStyle(.pill(arrow: true))
            case .privacy:
                Button("Continue") { go(to: .safety) }
                    .buttonStyle(.pill(arrow: true))
            case .safety:
                Button("Continue") {
                    appState.settings.safetyNoteAcknowledgedAt = .now
                    go(to: .safetyAlert)
                }
                .buttonStyle(.pill(arrow: true))
                .disabled(!safetyAcknowledged)
            case .safetyAlert:
                Button("Continue") { go(to: .emergencyContact) }
                    .buttonStyle(.pill(arrow: true))
            case .emergencyContact:
                Button("Save contact") {
                    appState.settings.emergencyContact = EmergencyContact(
                        name: contactName.trimmingCharacters(in: .whitespaces),
                        phone: contactPhone.trimmingCharacters(in: .whitespaces)
                    )
                    go(to: .appLock)
                }
                .buttonStyle(.pill())
                .disabled(contactName.trimmingCharacters(in: .whitespaces).isEmpty || contactPhone.filter(\.isNumber).count < 6)
                skipButton { go(to: .appLock) }
            case .appLock:
                if appState.settings.appLockEnabled {
                    Button("Continue") { go(to: .notifications) }
                        .buttonStyle(.pill(arrow: true))
                } else {
                    Button("Turn on \(services.auth.biometryName)") {
                        Task {
                            if await services.auth.authenticate(reason: String(localized: "Turn on app lock")) {
                                appState.settings.appLockEnabled = true
                                lockMessage = nil
                            } else {
                                lockMessage = String(localized: "That didn't work. You can try again, or turn it on later in Profile → Privacy.")
                            }
                        }
                    }
                    .buttonStyle(.pill())
                    skipButton { go(to: .notifications) }
                }
            case .notifications:
                Button("Allow reminders") {
                    Task {
                        _ = await services.notifications.requestAuthorization()
                        appState.completeOnboarding()
                    }
                }
                .buttonStyle(.pill())
                skipButton(title: "Not now") { appState.completeOnboarding() }
            }
        }
    }

    private func skipButton(title: LocalizedStringKey = "Skip for now", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: minTapTarget)
        }
        .foregroundStyle(Color.brandPrimaryStrong)
    }

    private func go(to newStep: Step) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35)) {
            step = newStep
        }
    }
}

// MARK: - Building blocks

private struct StepLayout<Content: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Image(systemName: symbol)
                .font(.system(.largeTitle, weight: .semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 72, height: 72)
                .background(Color.surface, in: .rect(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Bullet: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(Color.brandPrimaryStrong)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Mock lock-screen banner showing the generic reminder copy.
struct NotificationPreview: View {
    var body: some View {
        HStack(spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.brandPrimary)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "leaf.fill").foregroundStyle(Color.onBrandPrimary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MySafeSpace").font(.subheadline.weight(.semibold))
                Text("A gentle reminder").font(.subheadline)
            }
            .foregroundStyle(Color.ink)
            Spacer()
            Text("now").font(.caption).foregroundStyle(Color.inkSecondary)
        }
        .padding(Spacing.s)
        .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Example notification: MySafeSpace, a gentle reminder"))
    }
}

struct EmergencyContactFields: View {
    @Binding var name: String
    @Binding var phone: String

    var body: some View {
        VStack(spacing: 0) {
            TextField("Name", text: $name)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .padding(Spacing.m)
                .frame(minHeight: minTapTarget)
            Divider().padding(.leading, Spacing.m)
            TextField("Phone number", text: $phone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .padding(Spacing.m)
                .frame(minHeight: minTapTarget)
        }
        .foregroundStyle(Color.ink)
        .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
    }
}

#Preview("Onboarding") {
    OnboardingFlow().previewEnvironment()
}
