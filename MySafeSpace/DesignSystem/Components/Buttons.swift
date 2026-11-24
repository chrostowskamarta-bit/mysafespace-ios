import SwiftUI

/// Capsule CTA. `.primary` can carry the circular arrow from the reference shots.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }

    var kind: Kind = .primary
    var showsArrow = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.s) {
            configuration.label
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if showsArrow {
                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.onBrandPrimary, in: .circle)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, showsArrow ? Spacing.xl : Spacing.l)
        .padding(.trailing, showsArrow ? 6 : Spacing.l)
        .padding(.vertical, showsArrow ? 6 : 14)
        .frame(minHeight: 52)
        .foregroundStyle(foreground)
        .background(background, in: .capsule)
        .overlay {
            if kind == .secondary {
                Capsule().strokeBorder(Color.brandPrimary, lineWidth: 1.5)
            }
        }
        .contentShape(.capsule)
        .opacity(isEnabled ? 1 : 0.45)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: .onBrandPrimary
        case .secondary: .brandPrimaryStrong
        case .quiet: .ink
        }
    }

    private var background: Color {
        switch kind {
        case .primary: .brandPrimary
        case .secondary: .clear
        case .quiet: .surfaceMuted
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind = .primary, arrow: Bool = false) -> PillButtonStyle {
        PillButtonStyle(kind: kind, showsArrow: arrow)
    }
}

/// Toolbar entry to crisis support, used in every sheet and full-screen cover.
struct NeedHelpButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.presentCrisis()
        } label: {
            Label("Need help now", systemImage: "lifepreserver")
        }
        .accessibilityHint("Opens crisis support numbers")
    }
}

/// Floating "Need help now" button above the tab bar.
/// On the first 3 launches it spells out the label, then folds into a lifebuoy icon the size
/// of the other icon buttons (48 pt). VoiceOver always reads "Need help now".
struct FloatingHelpButton: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let expanded = appState.helpLabelVisible
        Button {
            appState.presentCrisis()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "lifepreserver")
                    .font(.title3.weight(.semibold))
                    .frame(width: 24, height: 24)
                if expanded {
                    Text("Need help now")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .foregroundStyle(Color.onBrandPrimary)
            .padding(.horizontal, expanded ? Spacing.m : 12)
            .frame(minWidth: minTapTarget, minHeight: minTapTarget)
            .background(Color.brandPrimary, in: .capsule)
            .shadow(color: Color.brandPrimary.opacity(0.35), radius: 10, y: 4)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Need help now"))
        .accessibilityHint("Opens crisis support numbers")
        .task(id: expanded) {
            guard expanded else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45)) {
                appState.helpLabelCollapsed = true
            }
        }
    }
}

extension View {
    /// Hides the floating "Need help now" button while this screen is visible, for screens
    /// whose own bottom bar would sit under it. Crisis help stays reachable from the top area.
    func hidesFloatingHelpButton() -> some View { modifier(HidesFloatingHelp()) }
}

private struct HidesFloatingHelp: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .onAppear { appState.floatingHelpHiders += 1 }
            .onDisappear { appState.floatingHelpHiders = max(0, appState.floatingHelpHiders - 1) }
    }
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        Button("Get started") {}.buttonStyle(.pill(arrow: true))
        Button("Share with Michał") {}.buttonStyle(.pill())
        Button("Keep private") {}.buttonStyle(.pill(.secondary))
        Button("Skip for now") {}.buttonStyle(.pill(.quiet))
        Button("Disabled") {}.buttonStyle(.pill()).disabled(true)
        FloatingHelpButton()
    }
    .padding()
    .background(Color.appBackground)
    .previewEnvironment()
}
