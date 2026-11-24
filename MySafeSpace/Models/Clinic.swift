import Foundation

nonisolated enum ClinicianRole: String, Codable, Sendable {
    case psychiatrist, psychologist, psychotherapist, reception

    var label: String {
        switch self {
        case .psychiatrist: String(localized: "Psychiatrist")
        case .psychologist: String(localized: "Psychologist")
        case .psychotherapist: String(localized: "Psychologist · Psychotherapist")
        case .reception: String(localized: "Clinic reception")
        }
    }

    /// Photo background: psychiatrists on lemon (secondary), psychologists and
    /// psychotherapists on violet (primary). The role is always written next to it too.
    var isPsychiatrist: Bool { self == .psychiatrist }
    var isBookable: Bool { self != .reception }
}

/// One opinion as shown on ZnanyLekarz. MOCK: no ZnanyLekarz API is connected yet.
nonisolated struct ClinicianReview: Identifiable, Hashable, Sendable {
    let id = UUID()
    let stars: Int
    let text: String
    let when: String
}

/// Bounded availability for messaging. Weekdays use `Calendar` numbering (1 = Sunday).
nonisolated struct OfficeHours: Hashable, Codable, Sendable {
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var startHour = 9
    var endHour = 17

    func isOpen(at date: Date, calendar: Calendar = .clinic) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour else { return false }
        return weekdays.contains(weekday) && hour >= startHour && hour < endHour
    }

    /// The next moment the clinician will be available (or `date` itself if open now).
    func nextOpening(after date: Date, calendar: Calendar = .clinic) -> Date {
        if isOpen(at: date, calendar: calendar) { return date }
        var day = calendar.startOfDay(for: date)
        for _ in 0..<8 {
            if let opening = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
               weekdays.contains(calendar.component(.weekday, from: opening)),
               opening > date {
                return opening
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return date
    }

    /// "Mon–Fri 9:00–17:00"
    var summary: String {
        String(localized: "Mon–Fri \(startHour):00–\(endHour):00")
    }
}

nonisolated struct Clinician: Identifiable, Hashable, Sendable {
    let id: String
    let fullName: String
    /// How the clinician is addressed in short copy, e.g. "Dr Nowak".
    let shortName: String
    let role: ClinicianRole
    let initials: String
    let officeHours: OfficeHours
    /// e.g. "usually replies within 1 working day"
    let replyExpectation: String
    /// Asset name of the clinician's photo. `nil` → initials placeholder on the role colour.
    var photoAssetName: String? = nil
    /// Rating and opinion count as shown on ZnanyLekarz (MOCK values, no API yet).
    var rating: Double? = nil
    var ratingCount: Int? = nil
    var about: String? = nil
}

nonisolated struct Patient: Sendable {
    let fullName: String
    let firstName: String
    let age: Int
    let city: String
    var initials: String {
        fullName.split(separator: " ").compactMap(\.first).map(String.init).joined()
    }
}

nonisolated struct EmergencyContact: Codable, Equatable, Sendable {
    var name: String
    var phone: String

    /// Digits-only `tel:` URL. Never dialled automatically.
    var telURL: URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }
}

/// Fictional clinic directory used by the mock services.
nonisolated struct ClinicDirectory: Sendable {
    let clinicName: String
    let address: String
    let patient: Patient
    let clinicians: [Clinician]
    /// Prescribing psychiatrist and main messaging contact.
    let leadClinicianID: String
    /// DECISION: journal entries are shared with the weekly therapist, whose sessions they
    /// prepare for. Pre-visit summaries go to whoever runs that visit.
    let journalRecipientID: String
    /// The patient's two lead clinicians (psychiatrist + therapist), shown in Profile.
    let careTeamIDs: [String]

    func clinician(_ id: String) -> Clinician? { clinicians.first { $0.id == id } }
    var lead: Clinician { clinician(leadClinicianID)! }
    var journalRecipient: Clinician { clinician(journalRecipientID)! }
    var careTeam: [Clinician] { careTeamIDs.compactMap(clinician) }
    /// Everyone the patient can book a visit with.
    var bookable: [Clinician] { clinicians.filter { $0.role.isBookable } }
}
