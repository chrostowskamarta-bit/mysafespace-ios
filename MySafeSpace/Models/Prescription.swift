import Foundation

/// The doctor always decides — a request is never an automatic renewal.
nonisolated enum RenewalStatus: Hashable, Sendable {
    case none
    case requested(on: Date)
    /// Psychotropic medicines may need a consultation before renewing.
    case visitNeeded
    /// e-Recepta: a 4-digit access code, used with the patient's PESEL at any pharmacy.
    case approved(code: String, on: Date)

    var isPending: Bool {
        if case .requested = self { return true }
        return false
    }

    var canRequest: Bool {
        switch self {
        case .none, .approved: true
        case .requested, .visitNeeded: false
        }
    }
}

nonisolated struct Prescription: Identifiable, Hashable, Sendable {
    let id: UUID
    let medication: String
    let dose: String
    let schedule: String
    let prescriberID: String
    let supplyDays: Int
    let endDate: Date
    var renewal: RenewalStatus

    func daysRemaining(from now: Date = .now, calendar: Calendar = .clinic) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: endDate)).day ?? 0
        return max(days, 0)
    }

    func remainingFraction(from now: Date = .now) -> Double {
        guard supplyDays > 0 else { return 0 }
        return min(1, Double(daysRemaining(from: now)) / Double(supplyDays))
    }
}
