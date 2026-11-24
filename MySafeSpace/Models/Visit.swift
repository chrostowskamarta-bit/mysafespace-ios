import Foundation

nonisolated enum VisitKind: Hashable, Sendable {
    case inPerson(room: Int)
    case online

    var isOnline: Bool { self == .online }

    var label: String {
        switch self {
        case .inPerson: String(localized: "In person")
        case .online: String(localized: "Online")
        }
    }

    var systemImage: String {
        switch self {
        case .inPerson: "building.2"
        case .online: "video"
        }
    }
}

nonisolated enum VisitStatus: Hashable, Sendable {
    case scheduled, completed, cancellationRequested, rescheduleRequested

    var note: String? {
        switch self {
        case .cancellationRequested: String(localized: "Cancellation requested – the clinic will confirm")
        case .rescheduleRequested: String(localized: "New time requested – the clinic will be in touch")
        default: nil
        }
    }
}

nonisolated struct Visit: Identifiable, Hashable, Sendable {
    let id: UUID
    let clinicianID: String
    let start: Date
    let durationMinutes: Int
    let kind: VisitKind
    var status: VisitStatus
    var title: String

    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }

    /// Online visits can be joined from 10 minutes before the start until the end.
    func canJoin(at now: Date) -> Bool {
        kind.isOnline && status == .scheduled
            && now >= start.addingTimeInterval(-10 * 60) && now <= end
    }
}

extension Array where Element == Visit {
    nonisolated func upcoming(from now: Date = .now) -> [Visit] {
        filter { $0.end >= now && $0.status != .completed }.sorted { $0.start < $1.start }
    }

    nonisolated func past(from now: Date = .now) -> [Visit] {
        filter { $0.end < now || $0.status == .completed }.sorted { $0.start > $1.start }
    }

    nonisolated func next(from now: Date = .now) -> Visit? { upcoming(from: now).first }
}
