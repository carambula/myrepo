import Foundation
import Testing
@testable import PodLink

struct PodcastDateParserTests {
    @Test
    func parsesMinCloudFractionalISO8601() {
        let date = PodcastDateParser.parse("2025-04-01T10:00:00.000Z")
        #expect(date != nil)
        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date!)
        #expect(parts.year == 2025)
        #expect(parts.month == 4)
        #expect(parts.day == 1)
        #expect(parts.hour == 10)
    }

    @Test
    func defaultISO8601FormatterRejectsFractionalSeconds() {
        let raw = "2025-04-01T10:00:00.000Z"
        #expect(ISO8601DateFormatter().date(from: raw) == nil)
        #expect(PodcastDateParser.parse(raw) != nil)
    }

    @Test
    func parsesInternetDateTimeWithoutFraction() {
        let date = PodcastDateParser.parse("2024-01-15T08:30:00Z")
        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date!)
        #expect(parts.year == 2024)
        #expect(parts.month == 1)
        #expect(parts.day == 15)
    }

    @Test
    func parsesRFC822GMT() {
        let date = PodcastDateParser.parse("Tue, 01 Apr 2025 10:00:00 GMT")
        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date!)
        #expect(parts.year == 2025)
        #expect(parts.month == 4)
        #expect(parts.day == 1)
    }

    @Test
    func parsesRFC822NumericOffset() {
        let date = PodcastDateParser.parse("Mon, 01 Jan 2024 10:00:00 +0000")
        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date!)
        #expect(parts.year == 2024)
        #expect(parts.month == 1)
        #expect(parts.day == 1)
    }

    @Test
    func parsesDateOnly() {
        let date = PodcastDateParser.parse("2023-12-25")
        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date!)
        #expect(parts.year == 2023)
        #expect(parts.month == 12)
        #expect(parts.day == 25)
    }

    @Test
    func emptyAndInvalidReturnNil() {
        #expect(PodcastDateParser.parse(nil) == nil)
        #expect(PodcastDateParser.parse("") == nil)
        #expect(PodcastDateParser.parse("   ") == nil)
        #expect(PodcastDateParser.parse("not-a-date") == nil)
    }

    @Test
    func parsedDateIsNotTodayWhenSourceIsOlder() {
        let date = PodcastDateParser.parse("2022-06-15T12:00:00.000Z")!
        #expect(!Calendar.current.isDateInToday(date))
    }
}
