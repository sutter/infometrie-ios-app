import Foundation
import Testing
@testable import InfometrieCore

struct TranscriptTests {
    private let date = "2026-09-21T10:00:00Z"
    private func detail(_ text: String = "Un passage avec quatre mots.", start: String? = nil, duration: Int = 20) -> SequenceDetail {
        let item = FeedItem(id: 1, at: date, kind: "intervention", media: "radio", channel: "Test", person: "Test", party: "", title: "Test")
        return SequenceDetail(item: item, resume: "", verbatim: text, playFrom: date,
                              speechStart: start ?? date, speechDurationSec: duration)
    }

    @Test func everyWordRoundTripsThroughBothMediaWindows() throws {
        let timeline = TranscriptTimeline(detail: detail(start: "2026-09-21T10:00:03Z"))
        for margin in [0.0, 10.0] {
            let clock = try #require(MediaClock(playFrom: date, margin: margin))
            for word in timeline.words {
                let instant = try #require(timeline.instant(forWord: word.id))
                let position = clock.position(at: instant)
                #expect(position >= margin + 3)
                #expect(timeline.wordIndex(at: clock.instant(at: position)) == word.id)
            }
        }
    }

    @Test func hlsClockUsesActualWindowRatherThanAssumingTenSeconds() throws {
        let passage = try #require(APIDate.parse(date))
        // Observed 7 seconds into a window starting 23 seconds before play_from.
        let clock = try #require(MediaClock(currentDate: passage.addingTimeInterval(-16), position: 7))
        #expect(clock.position(at: passage) == 23)
        #expect(clock.instant(at: 23) == passage)
        let timeline = TranscriptTimeline(detail: detail())
        let target = try #require(timeline.instant(forWord: 3))
        #expect(abs(clock.position(at: target) - 35.01) < 0.0001)
        #expect(timeline.wordIndex(at: clock.instant(at: 35.01)) == 3)
    }

    @Test func unicodeWhitespaceAndParagraphsPreserveWordTargets() throws {
        let text = "Élodie\tparle d’une 👩🏽‍💻.\n\nPuis l’équipe répond : oui !"
        let timeline = TranscriptTimeline(detail: detail(text))
        #expect(timeline.words.map(\.text) == ["Élodie", "parle", "d’une", "👩🏽‍💻.", "Puis", "l’équipe", "répond", ":", "oui", "!"])
        for word in timeline.words {
            #expect((text as NSString).substring(with: word.range) == word.text)
            #expect(timeline.wordIndex(at: timeline.instant(forWord: word.id)) == word.id)
        }
        #expect(timeline.passages.count == 2)
        #expect(timeline.passageID(forWord: 3) == 0)
        #expect(timeline.passageID(forWord: 4) == 4)
        #expect(timeline.passageID(forWord: nil) == nil)
    }

    @Test func missingOrInvalidTimingDoesNotInventSeekTargets() {
        for value in [detail(""), detail(" \n\t "), detail(start: "invalid"), detail(duration: 0), detail(duration: -1)] {
            let timeline = TranscriptTimeline(detail: value)
            #expect(!timeline.canSynchronize)
            #expect(timeline.instant(forWord: 0) == nil)
            #expect(timeline.wordIndex(at: Date()) == nil)
        }
        let timeline = TranscriptTimeline(detail: detail())
        #expect(timeline.instant(forWord: -1) == nil)
        #expect(timeline.instant(forWord: timeline.words.count) == nil)
        #expect(MediaClock(currentDate: nil, position: 0) == nil)
        #expect(MediaClock(currentDate: Date(), position: .nan) == nil)
    }

    @Test func highlightingClearsBeforeSpeechAndAtItsEnd() throws {
        let timeline = TranscriptTimeline(detail: detail())
        let start = try #require(APIDate.parse(date))
        #expect(timeline.wordIndex(at: start.addingTimeInterval(-0.1)) == nil)
        #expect(timeline.wordIndex(at: start) == 0)
        #expect(timeline.wordIndex(at: start.addingTimeInterval(19.999)) == 4)
        #expect(timeline.wordIndex(at: start.addingTimeInterval(20)) == nil)
        #expect(timeline.wordIndex(at: nil) == nil)
    }

    @Test func shorterAccessiblePassagesKeepTheSameWordPositions() throws {
        let value = detail((0..<100).map { "mot\($0)" }.joined(separator: " "))
        let regular = TranscriptTimeline(detail: value)
        let largeText = TranscriptTimeline(detail: value, maximumWordsPerPassage: 4)
        #expect(largeText.passages.count == 25)
        #expect(largeText.passages.allSatisfy { $0.wordIDs.count <= 4 })
        #expect(largeText.passages.flatMap { Array($0.wordIDs) } == Array(0..<100))
        for word in regular.words {
            #expect(largeText.instant(forWord: word.id) == regular.instant(forWord: word.id))
        }
    }

    private func timings(_ values: [(String, Int64, Int64)], sequence: Int64 = 1, origin: String? = nil) -> SequenceWordTimings {
        SequenceWordTimings(sequence: sequence, origin: origin ?? date, sentences: [
            .init(text: values.map(\.0).joined(separator: " "), startMs: values.first?.1 ?? 0,
                  endMs: values.last?.2 ?? 0, words: values.map { .init(text: $0.0, startMs: $0.1, endMs: $0.2) })
        ])
    }

    @Test func preciseWordsUseMillisecondsFromOriginAndPreserveSilences() throws {
        let value = detail("Un passage précis.", start: "2026-09-21T10:00:02Z", duration: 12)
        let timeline = TranscriptTimeline(detail: value, timings: timings([("Un", 2000, 2500), ("passage", 4000, 4700), ("précis", 9000, 9500)]))
        let origin = try #require(APIDate.parse(date))
        #expect(timeline.hasPreciseTimings)
        #expect(abs(try #require(timeline.instant(forWord: 2)).timeIntervalSince(origin) - 9.001) < 0.0001)
        #expect(timeline.wordIndex(at: origin.addingTimeInterval(2)) == 0)
        #expect(timeline.wordIndex(at: origin.addingTimeInterval(2.5)) == nil)
        #expect(timeline.wordIndex(at: origin.addingTimeInterval(3)) == nil)
        #expect(timeline.wordIndex(at: origin.addingTimeInterval(4.5)) == 1)
        #expect(timeline.wordIndex(at: origin.addingTimeInterval(9.5)) == nil)
        for index in timeline.words.indices {
            #expect(timeline.wordIndex(at: timeline.instant(forWord: index)) == index)
        }
    }

    @Test func preciseAlignmentAcceptsFrenchPunctuationAndSplitContractionsWithoutChangingText() {
        let text = "« L’actualité, c’est-à-dire l’économie ! »"
        let words = timings([("l'", 0, 100), ("actualité", 100, 700), ("c'est", 800, 1000), ("à", 1000, 1100), ("dire", 1100, 1400), ("l'économie", 2000, 2800)])
        let timeline = TranscriptTimeline(detail: detail(text), timings: words)
        #expect(timeline.hasPreciseTimings)
        #expect(timeline.text == text)
        #expect(timeline.instant(forWord: 0) == nil) // Opening quotation mark.
        #expect(timeline.wordIndex(at: timeline.instant(forWord: 2)) == 2)
        #expect(timeline.instant(forWord: 4) == nil) // Standalone punctuation.
    }

    @Test func repeatedWordsRemainAssociatedWithTheirOwnOccurrences() throws {
        let timeline = TranscriptTimeline(detail: detail("Oui oui non."), timings: timings([("oui", 0, 500), ("oui", 5000, 5600), ("non", 8000, 8700)]))
        let origin = try #require(APIDate.parse(date))
        #expect(timeline.hasPreciseTimings)
        #expect(timeline.wordIndex(at: origin.addingTimeInterval(5.2)) == 1)
        #expect(abs(try #require(timeline.instant(forWord: 1)).timeIntervalSince(origin) - 5.001) < 0.0001)
    }

    @Test func preciseWordsWorkWithoutEstimatedSpeechMetadataAndCanPrecedePlayFrom() throws {
        let value = detail("Avant après", start: "", duration: 0)
        let timeline = TranscriptTimeline(detail: value, timings: timings([("Avant", -500, -100), ("après", 1200, 2000)]))
        let clock = try #require(MediaClock(playFrom: date, margin: 10))
        #expect(timeline.hasPreciseTimings)
        #expect(timeline.canSynchronize)
        #expect(abs(clock.position(at: try #require(timeline.instant(forWord: 0))) - 9.501) < 0.0001)
    }

    @Test func partialMismatchedAndInvalidTimingsFallBackRatherThanPretendPrecision() {
        let value = detail("Un passage")
        let candidates = [
            timings([]), timings([("Un", 0, 500)]), timings([("Autre", 0, 500), ("passage", 1000, 2000)]),
            timings([("Un", 0, 0), ("passage", 1000, 2000)]),
            timings([("Un", 0, 1500), ("passage", 1000, 2000)]),
            timings([("Un passage", 0, 2000)]),
            timings([("Un", 0, 500), ("passage", 1000, 2000)], sequence: 2),
            timings([("Un", 0, 500), ("passage", 1000, 2000)], origin: "invalid")
        ]
        for candidate in candidates {
            let timeline = TranscriptTimeline(detail: value, timings: candidate)
            #expect(!timeline.hasPreciseTimings)
            #expect(timeline.canSynchronize)
            #expect(timeline.wordIndex(at: timeline.instant(forWord: 1)) == 1)
        }
    }

    @Test func lateHLSTimeCorrectionDoesNotBecomeExtraPlaybackProgress() {
        var intent = PendingWordSeek(index: 18, position: 17.9)
        // A word tap at 17.9s has played for one second when HLS reveals that
        // the actual window starts 13s earlier than the requested margin implied.
        intent.rebaseClock(from: 18.9, to: 31.9)
        #expect(abs(intent.position - 30.9) < 0.0001)
        // Precise STT then locates this word at 35s. Preserve only the 1s played,
        // not the 13s clock correction, and thus seek to 36s rather than 49s.
        #expect(abs(intent.target(precisePosition: 35, currentPosition: 31.9) - 36) < 0.0001)
    }

    @Test func latePreciseTimingsKeepPausedWordAtItsStart() {
        let intent = PendingWordSeek(index: 18, position: 7.9)
        #expect(intent.target(precisePosition: 12, currentPosition: 7.9) == 12)
        #expect(intent.target(precisePosition: 12, currentPosition: 7.899) == 12)
        #expect(abs(intent.target(precisePosition: 12, currentPosition: 9.9) - 14) < 0.0001)
    }
}
