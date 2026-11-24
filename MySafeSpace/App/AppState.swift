import Foundation
import Observation

enum AppTab: Hashable {
    case home, calendar, prescriptions, messages, profile
}

enum CrisisSource: Equatable {
    case journal, message
}

enum CrisisReason: Equatable {
    case manual, quickAction, detected(CrisisSource)
}

struct CrisisPresentation: Identifiable, Equatable {
    let id = UUID()
    var reason: CrisisReason
    var safetyAlertSent = false
}

/// App-wide UI state. Overlay windows (crisis, shield, lock) observe it via `onOverlayChange`.
@Observable
final class AppState {
    var settings: AppSettings {
        didSet { if settings != oldValue { settingsStore.save(settings) } }
    }

    var selectedTab: AppTab = .home
    var messagesPath: [MessageThread.ID] = []
    /// The day selected in the Calendar tab (visits, mood and that day's note).
    var calendarDay: Date = Calendar.clinic.startOfDay(for: .now)

    /// Shows the full "Need help now" label before it folds into the lifebuoy icon.
    var helpLabelVisible: Bool { (settings.launchCount ?? 0) <= Self.helpLabelLaunches && !helpLabelCollapsed }
    var helpLabelCollapsed = false
    static let helpLabelLaunches = 3
    /// Screens with their own bottom bar (message composer, Save button) hide the floating button.
    var floatingHelpHiders = 0
    @ObservationIgnored private var launchRegistered = false

    private(set) var crisis: CrisisPresentation? { didSet { onOverlayChange?() } }
    private(set) var isLocked = false { didSet { onOverlayChange?() } }
    /// True while the scene is inactive/backgrounded: the privacy shield covers the UI.
    private(set) var isObscured = false { didSet { if isObscured != oldValue { onOverlayChange?() } } }

    @ObservationIgnored var onOverlayChange: (() -> Void)?
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var lastDetectionPrompt: [String: Date] = [:]

    /// Don't nag: one detection prompt per entry/thread per window.
    static let detectionCooldown: TimeInterval = 15 * 60

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        let loaded = settingsStore.load()
        settings = loaded
        isLocked = loaded.hasCompletedOnboarding && loaded.appLockEnabled
    }

    // MARK: Crisis

    func presentCrisis(_ reason: CrisisReason = .manual) {
        crisis = CrisisPresentation(reason: reason)
    }

    func dismissCrisis() {
        crisis = nil
    }

    /// Reacts to an on-device assessment. Never blocks saving or sending — callers save first.
    /// - Returns: `true` if full-screen support was shown.
    @discardableResult
    func handle(_ assessment: CrisisAssessment, source: CrisisSource, key: String, safetyAlerts: any SafetyAlertService) -> Bool {
        guard assessment.shouldShowFullScreenSupport else { return false }
        if let last = lastDetectionPrompt[key], Date.now.timeIntervalSince(last) < Self.detectionCooldown {
            return false
        }
        lastDetectionPrompt[key] = .now

        var presentation = CrisisPresentation(reason: .detected(source))
        if settings.safetyAlertConsent {
            presentation.safetyAlertSent = true
            let detectedAt = Date.now
            Task { await safetyAlerts.sendFlag(detectedAt: detectedAt) }
        }
        crisis = presentation
        return true
    }

    @discardableResult
    func handleShortcut(type: String) -> Bool {
        guard type == QuickAction.crisis else { return false }
        presentCrisis(.quickAction)
        return true
    }

    // MARK: Navigation

    func openThread(_ id: MessageThread.ID) {
        selectedTab = .messages
        messagesPath = [id]
    }

    // MARK: Lock & privacy shield

    func sceneWillResignActive() { isObscured = true }
    func sceneDidBecomeActive() { isObscured = false }

    func sceneDidEnterBackground() {
        isObscured = true
        if backgroundedAt == nil { backgroundedAt = .now }
    }

    func sceneWillEnterForeground() {
        defer { backgroundedAt = nil }
        guard settings.hasCompletedOnboarding, settings.appLockEnabled, let since = backgroundedAt else { return }
        if Date.now.timeIntervalSince(since) >= TimeInterval(settings.autoLockMinutes * 60) {
            isLocked = true
        }
    }

    func unlock(using auth: any AuthService) async {
        if await auth.authenticate(reason: String(localized: "Unlock MySafeSpace")) {
            isLocked = false
        }
    }

    /// Counts one launch per process, once the main UI appears.
    func registerLaunch() {
        guard !launchRegistered, settings.hasCompletedOnboarding else { return }
        launchRegistered = true
        settings.launchCount = (settings.launchCount ?? 0) + 1
    }

    func openCalendar(on day: Date) {
        calendarDay = Calendar.clinic.startOfDay(for: day)
        selectedTab = .calendar
    }

    // MARK: Onboarding

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
    }

    func replayOnboarding() {
        settings.hasCompletedOnboarding = false
        selectedTab = .home
    }

    /// Previews and screenshots skip onboarding (settings aren't persisted there).
    func configureForPreview() {
        settings.hasCompletedOnboarding = true
        settings.safetyNoteAcknowledgedAt = .now
        settings.emergencyContact = EmergencyContact(name: "Piotr Kowalski", phone: "+48 600 100 200")
        isLocked = false
    }
}

enum QuickAction {
    static let crisis = "com.mysafespace.patient.crisis"
}
