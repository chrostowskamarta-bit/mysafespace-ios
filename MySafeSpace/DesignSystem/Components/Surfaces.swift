import SwiftUI

struct CardStyle: ViewModifier {
    var fill: Color
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }
}

extension View {
    /// Large-radius card on `surface`.
    func card(fill: Color = .surface, padding: CGFloat = Spacing.m + 4) -> some View {
        modifier(CardStyle(fill: fill, padding: padding))
    }

    /// Soft lavender screen background.
    func screenBackground() -> some View {
        background(Color.appBackground.ignoresSafeArea())
    }

    /// For `List`/`Form`: hide the system background and use the app's.
    func listScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.sectionTitle)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct AvatarView: View {
    let initials: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44
    var fill: Color = .surfaceMuted
    /// Optional photo from the Asset Catalog; falls back to initials.
    var imageName: String? = nil

    init(initials: String, fill: Color = .surfaceMuted, imageName: String? = nil) {
        self.initials = initials
        self.fill = fill
        self.imageName = imageName
    }

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let imageName, UIImage(named: imageName) != nil {
                Image(imageName).resizable().scaledToFill()
            } else {
                Text(initials)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// Private / Shared state. Icon + word, never colour alone.
struct PrivacyBadge: View {
    let isShared: Bool

    var body: some View {
        Group {
            if isShared {
                Label("Shared", systemImage: "person.2.fill")
                    .foregroundStyle(Color.onBrandSecondary)
                    .background(Color.brandSecondary, in: .capsule)
            } else {
                Label("Private", systemImage: "lock.fill")
                    .foregroundStyle(Color.inkSecondary)
                    .background(Color.surfaceMuted, in: .capsule)
            }
        }
        .font(.caption.weight(.semibold))
        .labelStyle(BadgeLabelStyle())
        .accessibilityElement(children: .combine)
    }
}

private struct BadgeLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

/// "Not for emergencies" banner → opens the crisis screen.
struct EmergencyBanner: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.presentCrisis()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "exclamationmark.shield")
                    .accessibilityHidden(true)
                Text("Not for emergencies. If you're in danger, call 112.")
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: minTapTarget)
            .background(Color.surfaceMuted, in: .rect(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens crisis support")
    }
}

/// Small info row used for explanations ("How renewals work", privacy notes).
struct InfoNote: View {
    let systemImage: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.brandPrimaryStrong)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Surfaces") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Upcoming")
            HStack { PrivacyBadge(isShared: false); PrivacyBadge(isShared: true) }
            EmergencyBanner()
            Text("A card").card()
            HStack { AvatarView(initials: "KN"); AvatarView(initials: "MW") }
            InfoNote(systemImage: "lock", text: "Only you can see this.")
        }
        .padding()
    }
    .screenBackground()
    .previewEnvironment()
}
