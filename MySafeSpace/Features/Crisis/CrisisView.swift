import SwiftUI
import UIKit

/// Polish crisis lines. VERIFY BEFORE RELEASE: numbers and opening hours must be re-checked
/// against official sources (e.g. gov.pl, 116123.pl, centrumwsparcia.pl, 116111.pl).
struct Helpline: Identifiable {
    let id: String
    let display: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var url: URL? { URL(string: "tel:\(id)") }

    static let emergency = Helpline(id: "112", display: "112", title: "Emergency number", detail: "Police, ambulance, fire service")

    static let all: [Helpline] = [
        Helpline(id: "116123", display: "116 123", title: "Crisis Support Line for adults", detail: "Free · emotional support"),
        Helpline(id: "800702222", display: "800 70 2222", title: "Support Centre for Adults in Mental Crisis", detail: "Free · 24/7"),
        Helpline(id: "116111", display: "116 111", title: "Helpline for Children and Young People", detail: "Free · 24/7"),
    ]
}

struct HelplineRow: View {
    let helpline: Helpline
    var compact = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = helpline.url { openURL(url) }
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: "phone.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceMuted, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(helpline.display)
                        .font(compact ? .headline : .title3.weight(.semibold))
                        .monospacedDigit()
                    Text(helpline.title)
                        .font(.subheadline)
                    if !compact {
                        Text(helpline.detail)
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(Spacing.s)
            .frame(minHeight: 64)
            .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Call \(helpline.display)"))
        .accessibilityHint(Text(helpline.title))
    }
}

/// Full-screen crisis support. Calm and plain: neutral background, violet and ink only,
/// no lemon green, no characters. Never auto-dials. Close is always available.
struct CrisisView: View {
    let presentation: CrisisPresentation

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var callTapped = 0
    @State private var showBreathing = false

    private var isDetected: Bool {
        if case .detected = presentation.reason { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.crisisBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    if isDetected {
                        Text("It sounds like you might be going through something really painful. Would you like to talk to someone now?")
                            .font(.body)
                            .foregroundStyle(Color.ink)
                    }

                    Text("You don't have to go through this alone.")
                        .font(.screenTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)

                    if presentation.safetyAlertSent {
                        InfoNote(systemImage: "bell", text: "Your clinic has been notified that you may need support. They are not reading your journal.")
                            .padding(Spacing.s)
                            .background(Color.surface, in: .rect(cornerRadius: Radius.small, style: .continuous))
                    }

                    callEmergency

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Free support lines")
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Helpline.all) { HelplineRow(helpline: $0) }
                    }

                    personalOptions

                    breathing
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, 72)
                .padding(.bottom, Spacing.xl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }

            Button {
                appState.dismissCrisis()
            } label: {
                Label("Close", systemImage: "xmark")
                    .font(.headline)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: minTapTarget)
                    .background(Color.surface, in: .capsule)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ink)
            .padding(.trailing, Spacing.m)
            .padding(.top, Spacing.xs)
        }
        .accessibilityAction(.escape) { appState.dismissCrisis() }
    }

    private var callEmergency: some View {
        Button {
            callTapped += 1
            if let url = Helpline.emergency.url { openURL(url) }
        } label: {
            HStack {
                Image(systemName: "phone.fill").accessibilityHidden(true)
                Text("Call 112")
            }
            .font(.title3.weight(.semibold))
        }
        .buttonStyle(.pill())
        // The only haptic on this screen.
        .sensoryFeedback(.impact(weight: .medium), trigger: callTapped)
        .accessibilityHint("Emergency services: police, ambulance, fire")
    }

    @ViewBuilder
    private var personalOptions: some View {
        let contact = appState.settings.emergencyContact
        let onboarded = appState.settings.hasCompletedOnboarding
        if contact != nil || onboarded {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("People who know you")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                if let contact, let url = contact.telURL {
                    optionRow(symbol: "person.fill", title: "Call \(contact.name)", subtitle: "Your emergency contact") {
                        openURL(url)
                    }
                }
                if onboarded {
                    optionRow(symbol: "bubble.left.fill", title: "Message my clinic", subtitle: "Replies are not immediate") {
                        appState.dismissCrisis()
                        appState.openThread(MockData.nowakThreadID)
                    }
                }
            }
        }
    }

    private func optionRow(symbol: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceMuted, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.footnote).foregroundStyle(Color.inkSecondary)
                }
                .foregroundStyle(Color.ink)
                Spacer(minLength: 0)
            }
            .padding(Spacing.s)
            .frame(minHeight: 64)
            .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var breathing: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showBreathing.toggle() }
            } label: {
                HStack {
                    Text("Breathe together for a minute")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showBreathing ? "chevron.up" : "chevron.down")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.ink)
                .frame(minHeight: minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(showBreathing ? Text("Expanded") : Text("Collapsed"))
            if showBreathing {
                BreathingExercise()
            }
        }
    }
}

/// 4-7-8 breathing. Under Reduce Motion the circle doesn't scale; only text and opacity change.
struct BreathingExercise: View {
    enum Phase: CaseIterable {
        case inhale, hold, exhale

        var seconds: Double {
            switch self {
            case .inhale: 4
            case .hold: 7
            case .exhale: 8
            }
        }

        var announcement: String {
            switch self {
            case .inhale: String(localized: "Breathe in")
            case .hold: String(localized: "Hold")
            case .exhale: String(localized: "Breathe out")
            }
        }

        var instruction: LocalizedStringKey {
            switch self {
            case .inhale: "Breathe in through your nose… 4"
            case .hold: "Hold gently… 7"
            case .exhale: "Breathe out slowly… 8"
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .exhale
    @State private var running = false

    var body: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.12))
                Circle()
                    .fill(Color.brandPrimary.opacity(reduceMotion ? (phase == .exhale ? 0.25 : 0.55) : 0.35))
                    .scaleEffect(reduceMotion ? 0.8 : (phase == .exhale ? 0.45 : 1))
            }
            .frame(width: 180, height: 180)
            .accessibilityHidden(true)

            Text(running ? phase.instruction : "Tap start when you're ready")
                .font(.headline)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            Button(running ? "Stop" : "Start") {
                running.toggle()
            }
            .buttonStyle(.pill(.secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.m)
        .background(Color.surface, in: .rect(cornerRadius: Radius.inner, style: .continuous))
        .task(id: running) {
            guard running else {
                withAnimation(.easeInOut(duration: 0.4)) { phase = .exhale }
                return
            }
            while !Task.isCancelled {
                for next in Phase.allCases {
                    withAnimation(.easeInOut(duration: reduceMotion ? 0.4 : next.seconds)) { phase = next }
                    UIAccessibility.post(notification: .announcement, argument: next.announcement)
                    try? await Task.sleep(for: .seconds(next.seconds))
                    if Task.isCancelled { return }
                }
            }
        }
    }
}

#Preview("Crisis – manual") {
    CrisisView(presentation: CrisisPresentation(reason: .manual)).previewEnvironment()
}

#Preview("Crisis – detected, alert sent") {
    CrisisView(presentation: CrisisPresentation(reason: .detected(.journal), safetyAlertSent: true)).previewEnvironment()
}
