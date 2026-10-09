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
    /// The days `back` steps into the past, oldest first. Step 0 is the latest 7 or 30 days, up to yesterday;
    /// further back come whole calendar weeks (Monday to Sunday) or months, which people can name.
    func days(before now: Date = Date(), back: Int = 0) -> [String] {
        guard back > 0, !isLive else { return ParisDay.days(count: rawValue, before: now) }
        let calendar = ParisDay.calendar
        let today = calendar.startOfDay(for: now)
        let start: Date?, count: Int
        if self == .week {
            // Gregorian weekdays start on Sunday (1): Monday is 2.
            let sinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
            start = calendar.date(byAdding: .day, value: -sinceMonday - 7 * back, to: today)
            count = 7
        } else {
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
            start = month.flatMap { calendar.date(byAdding: .month, value: -back, to: $0) }
            count = start.flatMap { calendar.range(of: .day, in: .month, for: $0)?.count } ?? 0
        }
        guard let start else { return [] }
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start).map(ParisDay.string) }
    }
    /// A step back is shown while some of its days are still in the history the server keeps.
    static func isWithinHistory(_ days: [String], now: Date = Date()) -> Bool {
        guard let last = days.last else { return false }
        return last >= oldestDay(now: now)
    }
    /// The oldest Paris day the history serves.
    static func oldestDay(now: Date = Date()) -> String {
        ParisDay.days(count: historyDepth, before: now).first ?? ParisDay.string(now)
    }
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
