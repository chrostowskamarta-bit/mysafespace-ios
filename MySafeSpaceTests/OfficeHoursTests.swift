import Foundation
import Testing
@testable import MySafeSpace

@Suite("Office hours & visits")
struct OfficeHoursTests {
    let calendar = Calendar.clinic
    let hours = OfficeHours() // Mon–Fri 9–17

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        // November 2026: the 16th is a Monday, the 20th a Friday, the 21st a Saturday.
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func openDuringWeekdayHours() {
        #expect(hours.isOpen(at: date(16, 9)))
        #expect(hours.isOpen(at: date(20, 16, 59)))
    }

    @Test func closedOutsideHoursAndAtWeekends() {
        #expect(!hours.isOpen(at: date(16, 8, 59)))
        #expect(!hours.isOpen(at: date(16, 17)))
        #expect(!hours.isOpen(at: date(21, 12)))
    }

    @Test func nextOpeningAfterFridayEveningIsMonday() {
        #expect(hours.nextOpening(after: date(20, 18)) == date(23, 9))
    }

    @Test func nextOpeningEarlyMorningIsSameDay() {
        #expect(hours.nextOpening(after: date(17, 7)) == date(17, 9))
    }

    @Test func onlineVisitJoinWindow() {
        let visit = Visit(id: UUID(), clinicianID: "x", start: date(19, 17), durationMinutes: 50, kind: .online, status: .scheduled, title: "")
        #expect(!visit.canJoin(at: date(19, 16, 49)))
        #expect(visit.canJoin(at: date(19, 16, 50)))
        #expect(visit.canJoin(at: date(19, 17, 30)))
        #expect(!visit.canJoin(at: date(19, 17, 51)))
    }

    @Test func inPersonVisitsCannotBeJoined() {
        let visit = Visit(id: UUID(), clinicianID: "x", start: date(19, 17), durationMinutes: 50, kind: .inPerson(room: 2), status: .scheduled, title: "")
        #expect(!visit.canJoin(at: date(19, 17)))
    }

    @Test func emergencyContactTelURLIsDigitsOnly() {
        let contact = EmergencyContact(name: "Piotr", phone: "+48 600-100 200")
        #expect(contact.telURL?.absoluteString == "tel:+48600100200")
    }
}
