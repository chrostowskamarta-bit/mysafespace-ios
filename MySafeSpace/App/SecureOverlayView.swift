import SwiftUI

/// Content of the secure overlay window: the Face ID lock or the privacy shield.
struct SecureOverlayView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isLocked {
            LockView()
        } else {
            PrivacyShieldView()
        }
    }
}

/// Covers the UI whenever the app isn't active, so no journal content appears in the
/// app switcher. DECISION: an opaque cover rather than a blur — blur can still leak
/// shapes of text, and it works the same with Reduce Transparency.
struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: Spacing.m) {
                MoodFace(level: .good, size: 96)
                    .accessibilityHidden(true)
                Text("MySafeSpace")
                    .font(.screenTitle)
                    .foregroundStyle(Color.ink)
            }
        }
    }
}

struct LockView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @State private var hasAttempted = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                Spacer()
                MoodFace(level: .okay, size: 96)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.xs) {
                    Text("MySafeSpace is locked")
                        .font(.screenTitle)
                        .foregroundStyle(Color.ink)
                    Text("Your journal and messages stay private.")
                        .secondaryText()
                }
                .multilineTextAlignment(.center)
                Spacer()
                Button {
                    Task { await appState.unlock(using: services.auth) }
                } label: {
                    Label("Unlock with \(services.auth.biometryName)", systemImage: "faceid")
                }
                .buttonStyle(.pill())
                Button {
                    appState.presentCrisis()
                } label: {
                    Label("Need help now?", systemImage: "lifepreserver")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: minTapTarget)
                }
                .foregroundStyle(Color.ink)
                .accessibilityHint("Opens crisis support numbers. No unlock needed.")
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.m)
        }
        // Prompt once, after the scene is active (Face ID can't run while inactive).
        .task(id: appState.isObscured) {
            guard !appState.isObscured, !hasAttempted else { return }
            hasAttempted = true
            await appState.unlock(using: services.auth)
        }
    }
}

#Preview("Shield") {
    PrivacyShieldView().previewEnvironment()
}

#Preview("Lock") {
    LockView().previewEnvironment()
}
