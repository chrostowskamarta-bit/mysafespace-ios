import Foundation

/// Fictional fixtures. All dates are relative to `now` so the demo always feels current.
/// MOCK: replaced by API responses in production.
nonisolated enum MockData {

    // MARK: Clinic

    static let nowakID = "katarzyna-nowak"
    static let wisniewskiID = "michal-wisniewski"
    static let receptionID = "reception"
    static let zielinskiID = "tomasz-zielinski"
    static let lewandowskaID = "joanna-lewandowska"
    static let mazurID = "agnieszka-mazur"
    static let wojcikID = "piotr-wojcik"

    static let directory = ClinicDirectory(
        clinicName: "MySafeSpace Mental Health Clinic",
        address: "ul. Przykładowa 12, Warsaw",
        patient: Patient(fullName: "Anna Kowalska", firstName: "Anna", age: 29, city: "Warsaw"),
        clinicians: [
            Clinician(
                id: nowakID,
                fullName: "Dr Katarzyna Nowak",
                shortName: "Dr Nowak",
                role: .psychiatrist,
                initials: "KN",
                officeHours: OfficeHours(),
                replyExpectation: String(localized: "usually replies within 1 working day"),
                photoAssetName: "clinician-nowak",
                rating: 4.8, ratingCount: 152,
                about: String(localized: "Adult psychiatry: depression, anxiety and sleep problems.")
            ),
            Clinician(
                id: wisniewskiID,
                fullName: "Michał Wiśniewski",
                shortName: "Michał",
                role: .psychotherapist,
                initials: "MW",
                officeHours: OfficeHours(weekdays: [2, 3, 4, 5], startHour: 10, endHour: 18),
                replyExpectation: String(localized: "usually replies within 2 working days"),
                photoAssetName: "clinician-wisniewski",
                rating: 4.9, ratingCount: 97,
                about: String(localized: "Cognitive behavioural therapy for anxiety, burnout and low mood.")
            ),
            Clinician(
                id: zielinskiID, fullName: "Dr Tomasz Zieliński", shortName: "Dr Zieliński",
                role: .psychiatrist, initials: "TZ",
                officeHours: OfficeHours(weekdays: [2, 4, 6], startHour: 8, endHour: 14),
                replyExpectation: String(localized: "usually replies within 2 working days"),
                photoAssetName: "clinician-zielinski",
                rating: 4.7, ratingCount: 86,
                about: String(localized: "Mood disorders, ADHD in adults, medication reviews.")
            ),
            Clinician(
                id: lewandowskaID, fullName: "Joanna Lewandowska", shortName: "Joanna",
                role: .psychologist, initials: "JL",
                officeHours: OfficeHours(weekdays: [2, 3, 4, 5, 6], startHour: 12, endHour: 19),
                replyExpectation: String(localized: "usually replies within 2 working days"),
                rating: 4.9, ratingCount: 203,
                about: String(localized: "Psychological consultations, stress and life transitions.")
            ),
            Clinician(
                id: mazurID, fullName: "Dr Agnieszka Mazur", shortName: "Dr Mazur",
                role: .psychiatrist, initials: "AM",
                officeHours: OfficeHours(weekdays: [3, 5], startHour: 9, endHour: 16),
                replyExpectation: String(localized: "usually replies within 2 working days"),
                rating: 4.8, ratingCount: 64,
                about: String(localized: "Anxiety disorders, OCD and perinatal mental health.")
            ),
            Clinician(
                id: wojcikID, fullName: "Piotr Wójcik", shortName: "Piotr",
                role: .psychotherapist, initials: "PW",
                officeHours: OfficeHours(weekdays: [2, 3, 5, 6], startHour: 14, endHour: 20),
                replyExpectation: String(localized: "usually replies within 2 working days"),
                rating: 4.6, ratingCount: 41,
                about: String(localized: "Psychodynamic therapy, relationships and grief.")
            ),
            Clinician(
                id: receptionID,
                fullName: String(localized: "Clinic reception"),
                shortName: String(localized: "Reception"),
                role: .reception,
                initials: "R",
                officeHours: OfficeHours(weekdays: [2, 3, 4, 5, 6], startHour: 8, endHour: 18),
                replyExpectation: String(localized: "usually replies the same working day")
            ),
        ],
        leadClinicianID: nowakID,
        journalRecipientID: wisniewskiID,
        careTeamIDs: [nowakID, wisniewskiID]
    )

    // MARK: Doctors (MOCK availability and ZnanyLekarz opinions — no API connected)

    /// Free hourly slots within the clinician's working hours, skipping a deterministic
    /// pseudo-random set of "booked" hours, the past, and the patient's own visits.
    static func freeSlots(for clinician: Clinician, on day: Date, existing: [Visit], now: Date = .now, calendar: Calendar = .clinic) -> [Date] {
        let hours = clinician.officeHours
        let start = calendar.startOfDay(for: day)
        guard hours.weekdays.contains(calendar.component(.weekday, from: start)) else { return [] }
        let dayNumber = calendar.component(.day, from: start)
        let seed = clinician.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (hours.startHour..<hours.endHour).compactMap { hour -> Date? in
            guard let slot = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start) else { return nil }
            let booked = (dayNumber * 7 + hour * 3 + seed) % 4 == 0
            let clashes = existing.contains { $0.clinicianID == clinician.id && abs($0.start.timeIntervalSince(slot)) < 3600 }
            return (!booked && !clashes && slot > now.addingTimeInterval(3600)) ? slot : nil
        }
    }

    static func reviews(for clinicianID: String) -> [ClinicianReview] {
        let pool: [(Int, String, String)] = [
            (5, String(localized: "Calm, attentive and never rushed. I felt listened to from the first minute."), String(localized: "2 weeks ago")),
            (5, String(localized: "Explained everything clearly, including what to expect from the treatment."), String(localized: "1 month ago")),
            (4, String(localized: "Very professional. Hard to get an appointment, but worth the wait."), String(localized: "1 month ago")),
            (5, String(localized: "I was nervous before the first visit, and it turned out to be much easier than I feared."), String(localized: "2 months ago")),
            (5, String(localized: "Practical advice I could actually use between sessions."), String(localized: "3 months ago")),
            (4, String(localized: "Kind and thorough. The online visit worked without any problems."), String(localized: "4 months ago")),
        ]
        let offset = directory.clinicians.firstIndex { $0.id == clinicianID } ?? 0
        return (0..<3).map { i in
            let item = pool[(offset + i * 2) % pool.count]
            return ClinicianReview(stars: item.0, text: item.1, when: item.2)
        }
    }

    // MARK: Visits

    static func visits(now: Date, calendar: Calendar = .clinic) -> [Visit] {
        var result: [Visit] = []
        let lastThursday = calendar.nextDate(
            after: now, matching: DateComponents(weekday: 5), matchingPolicy: .nextTime, direction: .backward
        ) ?? now
        let anchor = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: lastThursday) ?? lastThursday

        // Weekly therapy: the past 6 Thursdays and the next 4.
        for offset in -5...4 {
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: anchor) else { continue }
            let isOnline = offset.isMultiple(of: 2) == false
            result.append(Visit(
                id: UUID(),
                clinicianID: wisniewskiID,
                start: start,
                durationMinutes: 50,
                kind: isOnline ? .online : .inPerson(room: 2),
                status: start < now ? .completed : .scheduled,
                title: String(localized: "Therapy session")
            ))
        }

        // Psychiatric follow-up in 3 weeks (Tuesday 10:30).
        if let inThreeWeeks = calendar.date(byAdding: .day, value: 21, to: now),
           let tuesday = calendar.nextDate(after: inThreeWeeks, matching: DateComponents(weekday: 3), matchingPolicy: .nextTime),
           let start = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tuesday) {
            result.append(Visit(
                id: UUID(), clinicianID: nowakID, start: start, durationMinutes: 30,
                kind: .inPerson(room: 1), status: .scheduled,
                title: String(localized: "Psychiatric follow-up")
            ))
        }

        // DECISION: a demo online visit starting 8 minutes after launch, so the
        // location check → waiting room → call flow can be shown at any time.
        result.append(Visit(
            id: UUID(), clinicianID: wisniewskiID,
            start: now.addingTimeInterval(8 * 60), durationMinutes: 50,
            kind: .online, status: .scheduled,
            title: String(localized: "Extra session")
        ))

        return result.sorted { $0.start < $1.start }
    }

    // MARK: Prescriptions

    static func prescriptions(now: Date, calendar: Calendar = .clinic) -> [Prescription] {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }
        return [
            Prescription(
                id: UUID(), medication: "Sertraline", dose: "50 mg",
                schedule: String(localized: "1 tablet every morning"),
                prescriberID: nowakID, supplyDays: 30, endDate: day(9), renewal: .none
            ),
            Prescription(
                id: UUID(), medication: "Hydroxyzine", dose: "25 mg",
                schedule: String(localized: "As needed, up to twice a day"),
                prescriberID: nowakID, supplyDays: 30, endDate: day(20), renewal: .requested(on: day(-2))
            ),
        ]
    }

    // MARK: Messages

    static let nowakThreadID = "thread-nowak"
    static let receptionThreadID = "thread-reception"

    static let threads = [
        MessageThread(id: nowakThreadID, clinicianID: nowakID),
        MessageThread(id: receptionThreadID, clinicianID: receptionID),
    ]

    static func messages(now: Date, calendar: Calendar = .clinic) -> [String: [Message]] {
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        return [
            nowakThreadID: [
                Message(threadID: nowakThreadID, sender: .patient,
                        text: "Good morning Dr Nowak. Since going up to 50 mg I've had some trouble falling asleep. Is that expected?",
                        sentAt: at(-8, 10, 12)),
                Message(threadID: nowakThreadID, sender: .clinician(id: nowakID),
                        text: "Good afternoon Anna, thank you for letting me know. Sleep changes are common in the first weeks. Try taking it in the morning rather than the evening. If it continues for more than two weeks, we'll look at it together at your follow-up.",
                        sentAt: at(-8, 15, 40)),
                Message(threadID: nowakThreadID, sender: .patient,
                        text: "Thank you, I've switched to mornings. It's a little better already.",
                        sentAt: at(-7, 8, 5)),
                Message(threadID: nowakThreadID, sender: .clinician(id: nowakID),
                        text: "Glad to hear it. If you can, keep noting your sleep in the journal – it helps us see the pattern.",
                        sentAt: at(-6, 11, 20)),
            ],
            receptionThreadID: [
                Message(threadID: receptionThreadID, sender: .clinician(id: receptionID),
                        text: "Hello Anna, your Thursday sessions with Michał Wiśniewski are confirmed until the end of the year. In-person sessions are in Room 2, first floor.",
                        sentAt: at(-12, 9, 30)),
                Message(threadID: receptionThreadID, sender: .patient,
                        text: "Thank you!",
                        sentAt: at(-12, 12, 2)),
            ],
        ]
    }

    // MARK: Journal seed (no crisis content)

    struct SeedEntry: Sendable {
        let dayOffset: Int
        let hour: Int
        let mood: MoodLevel?
        let emotions: [Emotion]
        let text: String
        let isCheckIn: Bool
        var sleep: TagLevel? = nil
        var anxiety: TagLevel? = nil
        var energy: TagLevel? = nil
        var shared = false
    }

    static let journalSeed: [SeedEntry] = [
        SeedEntry(dayOffset: -41, hour: 21, mood: .low, emotions: [.anxious, .tired], text: "First week of writing things down. Work felt like too much today and I couldn't switch off in the evening.", isCheckIn: false, sleep: .low, anxiety: .high),
        SeedEntry(dayOffset: -39, hour: 8, mood: .okay, emotions: [.tired], text: "", isCheckIn: true, sleep: .medium, energy: .low),
        SeedEntry(dayOffset: -37, hour: 22, mood: .low, emotions: [.anxious, .overwhelmed], text: "Couldn't fall asleep until 2. My mind kept looping about the project deadline.", isCheckIn: false, sleep: .low, anxiety: .high),
        SeedEntry(dayOffset: -35, hour: 19, mood: .good, emotions: [.calm, .connected], text: "Dinner with Kasia. I laughed properly for the first time in a while.", isCheckIn: false, energy: .medium),
        SeedEntry(dayOffset: -33, hour: 9, mood: .okay, emotions: [.content], text: "", isCheckIn: true, sleep: .medium),
        SeedEntry(dayOffset: -31, hour: 20, mood: .veryLow, emotions: [.sad, .lonely], text: "A heavy day. I cancelled plans and stayed in bed most of the afternoon. Writing this is the one thing I did.", isCheckIn: false, sleep: .low, energy: .low),
        SeedEntry(dayOffset: -30, hour: 10, mood: .low, emotions: [.tired, .numb], text: "", isCheckIn: true, energy: .low),
        SeedEntry(dayOffset: -28, hour: 18, mood: .okay, emotions: [.hopeful], text: "Session with Michał helped. We talked about noticing the 'what if' thoughts before they snowball.", isCheckIn: false, anxiety: .medium),
        SeedEntry(dayOffset: -26, hour: 21, mood: .good, emotions: [.proud], text: "Presented the redesign at work. Still replaying the one awkward moment, but it went better than I expected.", isCheckIn: false, anxiety: .medium, energy: .medium),
        SeedEntry(dayOffset: -24, hour: 8, mood: .good, emotions: [.calm], text: "", isCheckIn: true, sleep: .high),
        SeedEntry(dayOffset: -22, hour: 22, mood: .low, emotions: [.irritable, .tired], text: "Snapped at my sister on the phone. I said things I didn't mean and felt bad all evening.", isCheckIn: false, sleep: .low),
        SeedEntry(dayOffset: -20, hour: 19, mood: .okay, emotions: [.ashamed, .hopeful], text: "Called my sister back and apologised. She was kinder about it than I was to myself.", isCheckIn: false),
        SeedEntry(dayOffset: -18, hour: 9, mood: .okay, emotions: [.anxious], text: "", isCheckIn: true, anxiety: .medium, energy: .medium),
        SeedEntry(dayOffset: -16, hour: 20, mood: .great, emotions: [.grateful, .calm], text: "Walked home through Łazienki. The leaves were turning and for a moment my shoulders finally dropped.", isCheckIn: false, sleep: .high, energy: .high),
        SeedEntry(dayOffset: -14, hour: 21, mood: .low, emotions: [.overwhelmed, .anxious], text: "Sunday dread arrived early. Made a list for the week so it lives on paper instead of in my head.", isCheckIn: false, anxiety: .high),
        SeedEntry(dayOffset: -12, hour: 8, mood: .okay, emotions: [.tired], text: "", isCheckIn: true, sleep: .low),
        SeedEntry(dayOffset: -10, hour: 22, mood: .low, emotions: [.anxious, .tired], text: "Short sleep again. I noticed I check my work email the moment I wake up. Want to talk about this on Thursday.", isCheckIn: false, sleep: .low, anxiety: .high, shared: true),
        SeedEntry(dayOffset: -9, hour: 19, mood: .good, emotions: [.content, .connected], text: "Yoga class with Ola. I didn't think about work for a whole hour.", isCheckIn: false, energy: .medium),
        SeedEntry(dayOffset: -7, hour: 9, mood: .okay, emotions: [.calm], text: "", isCheckIn: true, sleep: .medium),
        SeedEntry(dayOffset: -6, hour: 21, mood: .veryLow, emotions: [.sad, .overwhelmed], text: "Everything felt grey today. I know it passes, but it's hard to believe while I'm in it.", isCheckIn: false, sleep: .low, energy: .low),
        SeedEntry(dayOffset: -5, hour: 20, mood: .low, emotions: [.tired, .anxious], text: "Better than yesterday, still slow. Took my lunch break outside, which helped a little.", isCheckIn: false, sleep: .low, anxiety: .medium),
        SeedEntry(dayOffset: -4, hour: 8, mood: .okay, emotions: [.hopeful], text: "", isCheckIn: true, sleep: .medium, energy: .medium),
        SeedEntry(dayOffset: -3, hour: 18, mood: .good, emotions: [.proud, .calm], text: "Said no to an extra project without over-explaining. Small, but it felt like a big step.", isCheckIn: false, anxiety: .low),
        SeedEntry(dayOffset: -2, hour: 22, mood: .low, emotions: [.anxious], text: "Woke up at 4 and couldn't get back to sleep. Tried the breathing exercise, it took the edge off.", isCheckIn: false, sleep: .low, anxiety: .high),
        SeedEntry(dayOffset: -1, hour: 19, mood: .good, emotions: [.grateful, .connected], text: "Lazy Saturday at Mum's. We baked szarlotka and talked about nothing in particular.", isCheckIn: false, sleep: .high, energy: .medium),
    ]
}
