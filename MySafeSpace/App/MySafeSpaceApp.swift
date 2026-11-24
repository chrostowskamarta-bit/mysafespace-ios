import SwiftUI
import SwiftData
import UIKit

@main
struct MySafeSpaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.appState)
                .environment(environment.services)
                .modelContainer(environment.container)
                .tint(Color.brandPrimary)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// Handles the Home Screen quick action, installs the overlay windows and forwards
/// lifecycle events for the privacy shield and auto-lock.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    private var environment: AppEnvironment { .shared }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        environment.installOverlays(in: windowScene)
        if let item = connectionOptions.shortcutItem {
            environment.appState.handleShortcut(type: item.type)
        }
    }

    // VERIFY: signature matches the iOS 26 SDK (Xcode warns "nearly matches" otherwise).
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(environment.appState.handleShortcut(type: shortcutItem.type))
    }

    func sceneWillResignActive(_ scene: UIScene) { environment.appState.sceneWillResignActive() }
    func sceneDidBecomeActive(_ scene: UIScene) { environment.appState.sceneDidBecomeActive() }
    func sceneDidEnterBackground(_ scene: UIScene) { environment.appState.sceneDidEnterBackground() }
    func sceneWillEnterForeground(_ scene: UIScene) { environment.appState.sceneWillEnterForeground() }
}
