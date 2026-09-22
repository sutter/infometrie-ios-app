import Foundation

/// Tracks playback progress after a word tap while precise STT timings load.
struct PendingWordSeek: Sendable {
    let index: Int
    private(set) var position: TimeInterval

    func target(precisePosition: TimeInterval, currentPosition: TimeInterval) -> TimeInterval {
        precisePosition + max(0, currentPosition - position)
    }

    mutating func rebaseClock(from oldPosition: TimeInterval, to newPosition: TimeInterval) {
        // A correction of the HLS window is not time spent playing the passage.
        position += newPosition - oldPosition
    }
}
