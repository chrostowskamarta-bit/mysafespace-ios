import Foundation
import OSLog

nonisolated struct ReminderTime: Codable, Equatable, Sendable {
    var hour: Int
    var minute: Int

    var date: Date {
        Calendar.clinic.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date) {
        let parts = Calendar.clinic.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
    }
}

/// Research feature flag (brief §12): non-blocking card (default) vs. launch modal.
nonisolated enum MoodCheckInStyle: String, Codable, CaseIterable, Sendable {
    case card, modal

    var label: String {
        switch self {
        case .card: String(localized: "Card on Home (default)")
        case .modal: String(localized: "Pop-up on launch")
        }
    }
}

nonisolated struct AppSettings: Codable, Equatable, Sendable {
    var hasCompletedOnboarding = false
    var safetyNoteAcknowledgedAt: Date?
    /// Off by default. When on, detection sends the clinic a flag — never entry text.
    var safetyAlertConsent = false
    var emergencyContact: EmergencyContact?
    var appLockEnabled = false
    /// 0 = lock immediately when leaving the app.
    var autoLockMinutes = 1
    var dailyCheckInReminder: ReminderTime?
    var medicationReminder: ReminderTime?
    var moodCheckInStyle: MoodCheckInStyle = .card
    var checkInSkippedOn: Date?
    var checkInModalShownOn: Date?
    /// How many times the app has been opened after onboarding. Optional so older settings
    /// files still decode. The "Need help now" label is spelled out on the first 3 launches.
    var launchCount: Int?
}

/// Persists settings (incl. the emergency contact) as JSON with complete file protection.
/// DECISION: not UserDefaults — its plist isn't covered by `NSFileProtectionComplete`.
/// DECISION: if the schema changes and decoding fails, settings fall back to defaults
/// (acceptable for a portfolio build; production would migrate).
nonisolated struct SettingsStore: Sendable {
    let url: URL?

    init(persistent: Bool) {
        guard persistent,
              let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            url = nil
            return
        }
        url = directory.appendingPathComponent("settings.json")
    }

    func load() -> AppSettings {
        guard let url, let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let url else { return }
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            Logger.app.error("Saving settings failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension Logger {
    nonisolated static let app = Logger(subsystem: "com.mysafespace.patient", category: "app")
}

/// Applies `NSFileProtectionComplete` to Application Support so the SwiftData store and
/// settings are unreadable while the device is locked. New files inherit the class.
nonisolated enum DataProtection {
    static func protectApplicationSupport() {
        let fileManager = FileManager.default
        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.complete]
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: attributes)
            try fileManager.setAttributes(attributes, ofItemAtPath: directory.path)
            let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for url in contents {
                try? fileManager.setAttributes(attributes, ofItemAtPath: url.path)
            }
        } catch {
            Logger.app.error("Applying file protection failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
