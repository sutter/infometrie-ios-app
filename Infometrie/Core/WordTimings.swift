import Foundation

/// GET /rest/v1/sequences/{id}/words (Swagger 0.5.0).
/// Milliseconds are relative to `origin` (= play_from), never to speech_start.
struct SequenceWordTimings: Codable, Sendable {
    let sequence: Int64
    let origin: String
    let sentences: [Sentence]

    struct Sentence: Codable, Sendable {
        let text: String
        let startMs: Int64
        let endMs: Int64
        let words: [Word]
        enum CodingKeys: String, CodingKey {
            case text, words
            case startMs = "start_ms", endMs = "end_ms"
        }
    }

    struct Word: Codable, Sendable {
        let text: String
        let startMs: Int64
        let endMs: Int64
        enum CodingKeys: String, CodingKey {
            case text
            case startMs = "start_ms", endMs = "end_ms"
        }
    }
}
