import SwiftUI
import UIKit

/// Hosts UI that must sit above EVERYTHING, including sheets and full-screen covers:
/// - the crisis screen (top-most — reachable even while the app is locked)
/// - the privacy shield / Face ID lock (covers the app switcher snapshot)
///
/// DECISION: separate `UIWindow`s instead of SwiftUI overlays, because a root overlay is
/// drawn *under* presented sheets — a journal sheet would otherwise show in the app switcher,
/// and the crisis screen couldn't appear over an open editor.
final class OverlayWindowController {
    private weak var scene: UIWindowScene?
    private let environment: AppEnvironment
    private var secureWindow: UIWindow?
    private var crisisWindow: UIWindow?
    private var crisisVisible = false

    private static let secureLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
    private static let crisisLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 2)

    init(scene: UIWindowScene, environment: AppEnvironment) {
        self.scene = scene
        self.environment = environment
        environment.appState.onOverlayChange = { [weak self] in self?.update() }
        update()
    }

    private func update() {
        let state = environment.appState
        setSecureWindow(visible: state.isLocked || state.isObscured)
        setCrisisWindow(visible: state.crisis != nil)
    }

    // MARK: Shield & lock — shown instantly so the snapshot never captures content.

    private func setSecureWindow(visible: Bool) {
        if visible {
            if secureWindow == nil {
                secureWindow = makeWindow(level: Self.secureLevel) { SecureOverlayView() }
            }
            secureWindow?.isHidden = false
        } else {
            secureWindow?.isHidden = true
        }
    }

    // MARK: Crisis — a short fade in and out.

    private func setCrisisWindow(visible: Bool) {
        guard visible != crisisVisible else { return }
        crisisVisible = visible
        if visible {
            if crisisWindow == nil {
                crisisWindow = makeWindow(level: Self.crisisLevel) { CrisisHostView() }
            }
            guard let window = crisisWindow else { return }
            window.alpha = 0
            window.isHidden = false
            window.makeKey()
            UIView.animate(withDuration: 0.25) { window.alpha = 1 }
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        } else {
            guard let window = crisisWindow else { return }
            UIView.animate(withDuration: 0.2, animations: { window.alpha = 0 }, completion: { [weak self] _ in
                guard self?.crisisVisible == false else { return }
                window.isHidden = true
                self?.scene?.windows.first { $0.windowLevel == .normal }?.makeKey()
            })
        }
    }

    private func makeWindow<Content: View>(level: UIWindow.Level, @ViewBuilder content: () -> Content) -> UIWindow? {
        guard let scene else { return nil }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = level
        window.backgroundColor = .clear
        let root = content()
            .environment(environment.appState)
            .environment(environment.services)
            .modelContainer(environment.container)
            .tint(Color.brandPrimary)
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        window.rootViewController = host
        return window
    }
}

/// Re-creates the crisis screen for each presentation so its state starts fresh.
struct CrisisHostView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let crisis = appState.crisis {
            CrisisView(presentation: crisis)
                .id(crisis.id)
        } else {
            Color.clear
        }
    }
}
