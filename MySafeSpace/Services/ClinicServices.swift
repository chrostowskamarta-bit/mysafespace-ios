import Foundation
import Observation

// Protocol-based services with mock implementations. Real implementations (API client,
// E2EE messaging, audit logging) replace the mocks in production without touching views.

// MARK: - Visits

nonisolated enum VisitChangeRequest: Sendable { case cancel, reschedule }

protocol VisitService: AnyObject {
    var visits: [Visit] { get }
    func requestChange(_ request: VisitChangeRequest, for visitID: Visit.ID) async
    /// Books a free slot with any clinic clinician. The clinic confirms it afterwards.
    func book(clinician: Clinician, start: Date, online: Bool) async
}

@Observable
final class MockVisitService: VisitService {
    private(set) var visits: [Visit]

    init(now: Date = .now) {
        visits = MockData.visits(now: now)
    }

    func requestChange(_ request: VisitChangeRequest, for visitID: Visit.ID) async {
        try? await Task.sleep(for: .milliseconds(600)) // MOCK: network latency
        guard let index = visits.firstIndex(where: { $0.id == visitID }) else { return }
        visits[index].status = request == .cancel ? .cancellationRequested : .rescheduleRequested
    }

    func book(clinician: Clinician, start: Date, online: Bool) async {
        try? await Task.sleep(for: .milliseconds(500)) // MOCK: network latency
        let psychiatrist = clinician.role.isPsychiatrist
        visits.append(Visit(
            id: UUID(),
            clinicianID: clinician.id,
            start: start,
            durationMinutes: psychiatrist ? 30 : 50,
            kind: online ? .online : .inPerson(room: 1),
            status: .scheduled,
            title: psychiatrist ? String(localized: "Psychiatric consultation") : String(localized: "Psychological consultation")
        ))
        visits.sort { $0.start < $1.start }
    }
}

// MARK: - Prescriptions

protocol PrescriptionService: AnyObject {
    var prescriptions: [Prescription] { get }
    func requestRenewal(of ids: Set<Prescription.ID>, note: String) async
}

@Observable
final class MockPrescriptionService: PrescriptionService {
    private(set) var prescriptions: [Prescription]

    init(now: Date = .now) {
        prescriptions = MockData.prescriptions(now: now)
    }

    func requestRenewal(of ids: Set<Prescription.ID>, note: String) async {
        try? await Task.sleep(for: .milliseconds(500)) // MOCK: network latency
        for index in prescriptions.indices where ids.contains(prescriptions[index].id) {
            prescriptions[index].renewal = .requested(on: .now)
        }
        // MOCK: the clinician reviews the request a few seconds later.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.simulateReview(of: ids)
        }
    }

    private func simulateReview(of ids: Set<Prescription.ID>) {
        for index in prescriptions.indices where ids.contains(prescriptions[index].id) {
            let code = String(Int.random(in: 1000...9999))
            prescriptions[index].renewal = .approved(code: code, on: .now)
        }
    }
}

// MARK: - Messaging

protocol MessagingService: AnyObject {
    var threads: [MessageThread] { get }
    func messages(in threadID: MessageThread.ID) -> [Message]
    func send(_ text: String, attachmentName: String?, in threadID: MessageThread.ID, officeHours: OfficeHours, clinicianName: String) async
}

/// MOCK: production messaging is end-to-end encrypted (no access for platform admins).
@Observable
final class MockMessagingService: MessagingService {
    let threads: [MessageThread]
    private var storage: [String: [Message]]

    init(now: Date = .now) {
        threads = MockData.threads
        storage = MockData.messages(now: now)
    }

    func messages(in threadID: MessageThread.ID) -> [Message] {
        storage[threadID, default: []].sorted { $0.sentAt < $1.sentAt }
    }

    func send(_ text: String, attachmentName: String?, in threadID: MessageThread.ID, officeHours: OfficeHours, clinicianName: String) async {
        let now = Date.now
        storage[threadID, default: []].append(
            Message(threadID: threadID, sender: .patient, text: text, sentAt: now, attachmentName: attachmentName)
        )
        guard !officeHours.isOpen(at: now) else { return }
        try? await Task.sleep(for: .milliseconds(700))
        let opening = officeHours.nextOpening(after: now)
        let day = Calendar.clinic.isDateInTomorrow(opening)
            ? String(localized: "tomorrow")
            : opening.formatted(.dateTime.weekday(.wide))
        storage[threadID, default: []].append(Message(
            threadID: threadID, sender: .system,
            text: String(localized: "\(clinicianName) is outside office hours and will see this \(day). If you need help sooner, open “Need help now?”."),
            sentAt: .now
        ))
    }
}

// MARK: - Safety alerts (consent-based, off by default)

protocol SafetyAlertService: AnyObject {
    var sentFlags: [Date] { get }
    /// Sends a FLAG ONLY ("may need contact – detected at …"). Never the entry text.
    func sendFlag(detectedAt: Date) async
}

@Observable
final class MockSafetyAlertService: SafetyAlertService {
    private(set) var sentFlags: [Date] = []

    func sendFlag(detectedAt: Date) async {
        // MOCK: production POSTs { patientID, detectedAt } to the clinic's red-flag inbox.
        // The clinician (Phase 2) decides whether to call, contact the ICE person or call 112.
        sentFlags.append(detectedAt)
    }
}
