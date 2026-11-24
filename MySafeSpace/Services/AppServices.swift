import Foundation
import Observation
import SwiftData

/// Service container injected through the SwiftUI environment.
@Observable
final class AppServices {
    let directory: ClinicDirectory
    let visits: any VisitService
    let prescriptions: any PrescriptionService
    let messaging: any MessagingService
    let safetyAlerts: any SafetyAlertService
    let crisisDetector: any CrisisDetector
    let location: any LocationService
    let auth: any AuthService
    let notifications: any NotificationService

    init(
        directory: ClinicDirectory,
        visits: any VisitService,
        prescriptions: any PrescriptionService,
        messaging: any MessagingService,
        safetyAlerts: any SafetyAlertService,
        crisisDetector: any CrisisDetector,
        location: any LocationService,
        auth: any AuthService,
        notifications: any NotificationService
    ) {
        self.directory = directory
        self.visits = visits
        self.prescriptions = prescriptions
        self.messaging = messaging
        self.safetyAlerts = safetyAlerts
        self.crisisDetector = crisisDetector
        self.location = location
        self.auth = auth
        self.notifications = notifications
    }

    static func mock(now: Date = .now) -> AppServices {
        AppServices(
            directory: MockData.directory,
            visits: MockVisitService(now: now),
            prescriptions: MockPrescriptionService(now: now),
            messaging: MockMessagingService(now: now),
            safetyAlerts: MockSafetyAlertService(),
            crisisDetector: OnDeviceCrisisDetector(),
            location: DeviceLocationService(),
            auth: DeviceAuthService(),
            notifications: LocalNotificationService()
        )
    }
}

/// Seeds realistic demo entries on first launch.
enum JournalSeeder {
    static func seedIfNeeded(_ context: ModelContext, now: Date = .now, calendar: Calendar = .clinic) {
        let existing = (try? context.fetchCount(FetchDescriptor<JournalEntry>())) ?? 0
        guard existing == 0 else { return }
        let today = calendar.startOfDay(for: now)
        for seed in MockData.journalSeed {
            guard let day = calendar.date(byAdding: .day, value: seed.dayOffset, to: today),
                  let date = calendar.date(bySettingHour: seed.hour, minute: Int.random(in: 0...50), second: 0, of: day) else { continue }
            let entry = JournalEntry(createdAt: date, text: seed.text, mood: seed.mood, emotions: seed.emotions, isCheckIn: seed.isCheckIn)
            entry.setLevel(seed.sleep, for: .sleep)
            entry.setLevel(seed.anxiety, for: .anxiety)
            entry.setLevel(seed.energy, for: .energy)
            if seed.shared { entry.setShared(true) }
            context.insert(entry)
        }
        try? context.save()
    }
}
