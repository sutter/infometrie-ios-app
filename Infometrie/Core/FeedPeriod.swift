import Foundation

/// The journal's time span: the live last 24 hours, or the last complete days in Paris.
/// 7 j and 30 j stop at yesterday, like `/rest/v1/days`, so the list and the chart cover the same days.
enum FeedPeriod: Int, CaseIterable, Sendable {
    case live = 0, week = 7, month = 30

    var isLive: Bool { self == .live }
    /// Paris days of history the server serves: on 2026-10-09 `/days` and `/history` held passages from
    /// 2026-08-09 on, about 60 days back, and nothing before (rolling retention or the archive's start: not documented).
    static let historyDepth = 60
    /// The complete Paris days of the period, oldest first, yesterday last. Live has none.
    /// `back` steps whole periods into the past: 1 is the 7 or 30 days before the latest ones.
    func days(before now: Date = Date(), back: Int = 0) -> [String] {
        let end = ParisDay.calendar.date(byAdding: .day, value: -back * rawValue, to: now) ?? now
        return ParisDay.days(count: rawValue, before: end)
    }
    /// Live's chart: the last 7 complete Paris days for context, then today, still going.
    static func liveDays(now: Date = Date()) -> [String] { ParisDay.days(count: 7, before: now) + [ParisDay.string(now)] }
}

/// Days as the API counts them: `YYYY-MM-DD` in the Europe/Paris time zone.
enum ParisDay {
    static let timeZone = TimeZone(identifier: "Europe/Paris")!
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func string(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Midnight in Paris of a `YYYY-MM-DD` day.
    static func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The `count` complete days before the Paris day of `now`, oldest first.
    static func days(count: Int, before now: Date) -> [String] {
        guard count > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        return (1...count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map(string)
        }
    }
}
