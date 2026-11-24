import SwiftUI
import SwiftData
import OSLog

/// Owns the long-lived objects: state, services and the SwiftData container.
final class AppEnvironment {
    static let shared = AppEnvironment(isPreview: false)

    let appState: AppState
    let services: AppServices
    let container: ModelContainer
    private(set) var overlays: OverlayWindowController?

    init(isPreview: Bool) {
        if !isPreview { DataProtection.protectApplicationSupport() }
        services = .mock()
        appState = AppState(settingsStore: SettingsStore(persistent: !isPreview))
        container = Self.makeContainer(inMemory: isPreview)
        JournalSeeder.seedIfNeeded(container.mainContext)
        if isPreview { appState.configureForPreview() }
    }

    func installOverlays(in scene: UIWindowScene) {
        guard overlays == nil else { return }
        overlays = OverlayWindowController(scene: scene, environment: self)
    }

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([JournalEntry.self, SharedSummary.self])
        // PRIVACY: local only — no CloudKit sync of journal data.
        let configuration = ModelConfiguration(
            "MySafeSpace", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            Logger.app.fault("Opening the journal store failed: \(error.localizedDescription, privacy: .public)")
            // DECISION: fall back to an in-memory store instead of crashing; nothing leaves the device.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: fallback)
            } catch {
                fatalError("Could not create even an in-memory store: \(error)")
            }
        }
    }
}

extension View {
    /// Injects a fresh, seeded, in-memory environment for `#Preview`s.
    func previewEnvironment() -> some View {
        let environment = AppEnvironment(isPreview: true)
        return self
            .environment(environment.appState)
            .environment(environment.services)
            .modelContainer(environment.container)
            .tint(Color.brandPrimary)
    }
}
