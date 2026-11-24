import Foundation
import CoreLocation
import LocalAuthentication
import MapKit
import UserNotifications

// MARK: - Location (online-visit check only)

nonisolated enum LocationError: Error, Sendable {
    case denied, unavailable, timedOut
}

protocol LocationService: AnyObject {
    /// One-off, when-in-use lookup of the patient's CURRENT address for an online visit.
    func currentAddress() async throws -> String
}

final class DeviceLocationService: LocationService {
    private let manager = CLLocationManager()

    func currentAddress() async throws -> String {
        manager.requestWhenInUseAuthorization()
        let coordinate = try await Self.firstFix(timeout: .seconds(10))
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // VERIFY: MapKit reverse geocoding (iOS 26 replacement for CLGeocoder).
        if let request = MKReverseGeocodingRequest(location: location),
           let item = try? await request.mapItems.first,
           let address = item.address?.fullAddress, !address.isEmpty {
            return address
        }
        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private nonisolated static func firstFix(timeout: Duration) async throws -> (latitude: Double, longitude: Double) {
        try await withThrowingTaskGroup(of: (latitude: Double, longitude: Double).self) { group in
            group.addTask {
                let session = CLServiceSession(authorization: .whenInUse)
                defer { session.invalidate() }
                for try await update in CLLocationUpdate.liveUpdates() {
                    if update.authorizationDenied || update.authorizationDeniedGlobally { throw LocationError.denied }
                    if let location = update.location {
                        return (location.coordinate.latitude, location.coordinate.longitude)
                    }
                }
                throw LocationError.unavailable
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw LocationError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw LocationError.unavailable }
            return result
        }
    }
}

// MARK: - App lock (Face ID / Touch ID with passcode fallback)

protocol AuthService: AnyObject {
    var biometryName: String { get }
    func authenticate(reason: String) async -> Bool
}

final class DeviceAuthService: AuthService {
    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return String(localized: "your passcode")
        }
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Use passcode")
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

// MARK: - Discreet local notifications

nonisolated enum ReminderKind: String, Sendable {
    case dailyCheckIn = "reminder.checkin"
    case medication = "reminder.medication"
}

protocol NotificationService: AnyObject {
    func isAuthorized() async -> Bool
    func requestAuthorization() async -> Bool
    func schedule(_ kind: ReminderKind, at time: ReminderTime) async
    func cancel(_ kind: ReminderKind)
}

/// PRIVACY: every notification uses the same generic copy. No drug names, no journal text,
/// nothing that reveals the app's purpose on a lock screen.
final class LocalNotificationService: NotificationService {
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(_ kind: ReminderKind, at time: ReminderTime) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "MySafeSpace")
        content.body = String(localized: "A gentle reminder")
        content.interruptionLevel = kind == .medication ? .active : .passive
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancel(_ kind: ReminderKind) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [kind.rawValue])
    }
}
