import Foundation
import Testing
@testable import InfometrieCore

struct FeedPeriodTests {
    private func instant(_ text: String) throws -> Date { try #require(APIDate.parse(text)) }

    @Test func periodsCoverTheCompleteParisDaysUpToYesterday() throws {
        // 00:30 in Paris on October 8 is still October 7 in UTC.
        let now = try instant("2026-10-07T22:30:00Z")
        #expect(FeedPeriod.live.days(before: now).isEmpty)
        #expect(FeedPeriod.week.days(before: now) == ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05", "2026-10-06", "2026-10-07"])
        let month = FeedPeriod.month.days(before: now)
        #expect(month.count == 30)
        #expect(month.first == "2026-09-08")
        #expect(month.last == "2026-10-07")
    }

    @Test func steppingBackGoesThroughCalendarWeeksAndMonths() throws {
        // Friday, October 9, 2026.
        let now = try instant("2026-10-09T10:00:00Z")
        #expect(FeedPeriod.week.days(before: now, back: 0).first == "2026-10-02")
        #expect(FeedPeriod.week.days(before: now, back: 1) == ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"])
        #expect(FeedPeriod.week.days(before: now, back: 2).first == "2026-09-21")
        let september = FeedPeriod.month.days(before: now, back: 1)
        #expect(september.first == "2026-09-01" && september.last == "2026-09-30" && september.count == 30)
        #expect(FeedPeriod.month.days(before: now, back: 2).count == 31)
        // A Sunday belongs to the week that started the Monday before.
        #expect(FeedPeriod.week.days(before: try instant("2026-10-04T10:00:00Z"), back: 1).first == "2026-09-21")
        // January steps back into December of the year before.
        #expect(FeedPeriod.month.days(before: try instant("2027-01-15T10:00:00Z"), back: 1).first == "2026-12-01")
    }

    @Test func stepsStopAtTheHistoryTheServerKeeps() throws {
        let now = try instant("2026-10-09T10:00:00Z")
        #expect(FeedPeriod.oldestDay(now: now) == "2026-08-10")
        #expect(FeedPeriod.isWithinHistory(FeedPeriod.month.days(before: now, back: 2), now: now), "August still ends inside the history")
        #expect(!FeedPeriod.isWithinHistory(FeedPeriod.month.days(before: now, back: 3), now: now))
        #expect(FeedPeriod.isWithinHistory(FeedPeriod.week.days(before: now, back: 8), now: now), "The week of August 10")
        #expect(!FeedPeriod.isWithinHistory(FeedPeriod.week.days(before: now, back: 9), now: now))
    }

    @Test func lateEveningInUTCIsAlreadyTheNextParisDay() throws {
        #expect(FeedPeriod.week.days(before: try instant("2026-10-07T21:59:00Z")).last == "2026-10-06")
        #expect(FeedPeriod.week.days(before: try instant("2026-10-07T22:00:00Z")).last == "2026-10-07")
    }

    @Test func daylightSavingChangeKeepsOneEntryPerDay() throws {
        // Paris leaves summer time on Sunday October 25, 2026: that day lasts 25 hours.
        let days = FeedPeriod.week.days(before: try instant("2026-10-27T10:00:00Z"))
        #expect(days == ["2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25", "2026-10-26"])
        let spring = FeedPeriod.week.days(before: try instant("2027-03-30T10:00:00Z"))
        #expect(spring == ["2027-03-23", "2027-03-24", "2027-03-25", "2027-03-26", "2027-03-27", "2027-03-28", "2027-03-29"])
    }

    @Test func parisDayRoundTripsThroughItsMidnight() throws {
        let midnight = try #require(ParisDay.date("2026-10-25"))
        #expect(midnight == (try instant("2026-10-24T22:00:00Z")))
        #expect(ParisDay.string(midnight) == "2026-10-25")
        #expect(ParisDay.date("25/10/2026") == nil)
    }

    @Test func dayTotalsAddOnlyTheShownKinds() {
        let day = DayCount(day: "2026-10-07", interventions: 2, citations: 40, tweets: 5)
        #expect(day.total(for: SearchFilters()) == 47)
        #expect(day.total(for: SearchFilters(interventions: true, citations: false, tweets: false)) == 2)
        #expect(day.total(for: SearchFilters(interventions: false, citations: false, tweets: false)) == 0)
    }
}
