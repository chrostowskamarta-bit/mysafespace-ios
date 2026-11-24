import Foundation

extension Calendar {
    /// The clinic is in Poland: weeks start on Monday regardless of device region.
    nonisolated static var clinic: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
}

nonisolated enum DateText {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "Today, 17:00" · "Tomorrow, 17:00" · "Thu 19 Nov, 17:00"
    static func dayAndTime(_ date: Date, calendar: Calendar = .clinic) -> String {
        let time = time(date)
        if calendar.isDateInToday(date) { return String(localized: "Today, \(time)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow, \(time)") }
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return String(localized: "\(day), \(time)", comment: "Day and time, e.g. Thu 19 Nov, 17:00")
    }

    /// "Today" · "Yesterday" · "Monday 9 November"
    static func dayHeading(_ date: Date, calendar: Calendar = .clinic) -> String {
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
