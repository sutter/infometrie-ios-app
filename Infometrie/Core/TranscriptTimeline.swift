import Foundation

/// A single reversible mapping between media seconds and the broadcast clock.
/// HLS PROGRAM-DATE-TIME takes precedence over the APK's requested margin.
struct MediaClock: Equatable, Sendable {
    let origin: Date

    init?(playFrom: String, margin: TimeInterval) {
        guard let start = APIDate.parse(playFrom), margin.isFinite else { return nil }
        origin = start.addingTimeInterval(-margin)
    }

    init?(currentDate: Date?, position: TimeInterval) {
        guard let currentDate, position.isFinite else { return nil }
        origin = currentDate.addingTimeInterval(-position)
    }

    func instant(at position: TimeInterval) -> Date { origin.addingTimeInterval(position) }
    func position(at instant: Date) -> TimeInterval { instant.timeIntervalSince(origin) }
}

/// Uses Swagger word timings when they match the verbatim. Otherwise both directions
/// share the APK's estimated timeline, explicitly identified as such in the UI.
struct TranscriptTimeline: Sendable {
    struct Word: Identifiable, Sendable {
        let id: Int
        let range: NSRange
        let text: String
    }
    struct Passage: Identifiable, Sendable {
        let id: Int
        let range: NSRange
        let wordIDs: Range<Int>
    }

    let text: String
    let words: [Word]
    let passages: [Passage]
    let start: Date?
    let duration: TimeInterval
    private let preciseWords: [TimedWord]?
    private let preciseWordsByID: [Int: TimedWord]
    var hasPreciseTimings: Bool { preciseWords != nil }
    var canSynchronize: Bool { hasPreciseTimings || (start != nil && duration > 0 && !words.isEmpty) }

    init(detail: SequenceDetail, timings: SequenceWordTimings? = nil, maximumWordsPerPassage: Int = 24) {
        text = detail.verbatim
        start = APIDate.parse(detail.speechStart)
        duration = Double(detail.speechDurationSec)
        let source = detail.verbatim as NSString
        let matches = (try? NSRegularExpression(pattern: #"\S+"#))?
            .matches(in: detail.verbatim, range: NSRange(location: 0, length: source.length)) ?? []
        let parsedWords = matches.enumerated().map { Word(id: $0.offset, range: $0.element.range, text: source.substring(with: $0.element.range)) }
        words = parsedWords
        let aligned = timings.flatMap { Self.align(words: parsedWords, timings: $0, sequenceID: detail.id) }
        preciseWords = aligned
        preciseWordsByID = Dictionary(uniqueKeysWithValues: (aligned ?? []).map { ($0.wordID, $0) })

        // Small passages make automatic following legible without moving at every word.
        // The original whitespace and Unicode are preserved inside each passage.
        var result: [Passage] = []
        var first = 0
        for index in words.indices {
            let nextStart = index + 1 < words.count ? words[index + 1].range.location : source.length
            let gap = source.substring(with: NSRange(location: NSMaxRange(words[index].range), length: nextStart - NSMaxRange(words[index].range)))
            let sentenceEnd = words[index].text.last.map { ".!?…".contains($0) } ?? false
            if index - first >= max(1, maximumWordsPerPassage) - 1 || gap.contains("\n") || (sentenceEnd && index - first >= 7) || index == words.count - 1 {
                result.append(Passage(id: first, range: NSRange(location: words[first].range.location, length: NSMaxRange(words[index].range) - words[first].range.location), wordIDs: first..<(index + 1)))
                first = index + 1
            }
        }
        passages = result
    }

    func wordIndex(at instant: Date?) -> Int? {
        if let preciseWords {
            guard let instant else { return nil }
            // Upper bound by start time, leaving silence between words unhighlighted.
            var lower = 0, upper = preciseWords.count
            while lower < upper {
                let middle = (lower + upper) / 2
                if preciseWords[middle].start <= instant { lower = middle + 1 }
                else { upper = middle }
            }
            guard lower > 0, instant < preciseWords[lower - 1].end else { return nil }
            return preciseWords[lower - 1].wordID
        }
        guard canSynchronize, let start, let instant else { return nil }
        let elapsed = instant.timeIntervalSince(start)
        guard elapsed >= 0, elapsed < duration else { return nil }
        return min(words.count - 1, Int(elapsed / duration * Double(words.count)))
    }

    func instant(forWord index: Int) -> Date? {
        if hasPreciseTimings {
            guard let word = preciseWordsByID[index] else { return nil }
            return word.start.addingTimeInterval(min(0.001, word.end.timeIntervalSince(word.start) / 2))
        }
        guard canSynchronize, words.indices.contains(index), let start else { return nil }
        let wordDuration = duration / Double(words.count)
        // Land just inside the word to tolerate AVPlayer/audio timestamp rounding.
        return start.addingTimeInterval(Double(index) * wordDuration + min(0.01, wordDuration / 2))
    }

    func passageID(forWord index: Int?) -> Int? {
        guard let index else { return nil }
        return passages.first { $0.wordIDs.contains(index) }?.id
    }

    private struct TimedWord: Sendable {
        let wordID: Int
        let start: Date
        let end: Date
    }

    private static func normalized(_ text: String) -> String {
        // Keep the displayed verbatim intact while accepting casing, punctuation,
        // French apostrophes, composed accents and STT tokens such as "l'" + "actualité".
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func align(words: [Word], timings: SequenceWordTimings, sequenceID: Int64) -> [TimedWord]? {
        guard timings.sequence == sequenceID, let origin = APIDate.parse(timings.origin) else { return nil }
        let tokens = timings.sentences.flatMap(\.words).map { ($0, normalized($0.text)) }.filter { !$0.1.isEmpty }
        guard !tokens.isEmpty else { return nil }
        for index in tokens.indices {
            let word = tokens[index].0
            guard word.endMs > word.startMs else { return nil }
            if index > 0, word.startMs < tokens[index - 1].0.endMs { return nil }
        }
        var result: [TimedWord] = []
        var cursor = 0
        for word in words {
            let expected = normalized(word.text)
            // Standalone punctuation has no invented time or seek action.
            guard !expected.isEmpty else { continue }
            let first = cursor
            var actual = ""
            while cursor < tokens.count && actual.count < expected.count {
                actual += tokens[cursor].1
                cursor += 1
                guard expected.hasPrefix(actual) else { return nil }
            }
            guard actual == expected, first < cursor else { return nil }
            result.append(TimedWord(wordID: word.id,
                                    start: origin.addingTimeInterval(Double(tokens[first].0.startMs) / 1_000),
                                    end: origin.addingTimeInterval(Double(tokens[cursor - 1].0.endMs) / 1_000)))
        }
        // Partial or unrelated STT output must never be advertised as precise alignment.
        guard cursor == tokens.count, !result.isEmpty else { return nil }
        return result
    }
}
