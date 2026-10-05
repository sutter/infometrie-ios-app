#if DEBUG
import Foundation

/// Fictional content that `UITestServer` serves to UI tests. No real person, party or broadcast is represented.
enum FixtureContent {
    static let persons = [
        Person(name: "Camille Martin", party: "TEST-A", role: "Personnalité fictive"),
        Person(name: "Alex Morgan", party: "TEST-B", role: "Personnalité fictive"),
        Person(name: "Sam Laurent", party: "TEST-A", role: "Personnalité fictive")
    ]
    static let parties = [Party(code: "TEST-A", name: "Groupe de test A"), Party(code: "TEST-B", name: "Groupe de test B")]
    /// Dated once per launch, so the feed, the sequences and their media clock agree.
    static let feed = makeFeed(now: Date())
    /// Durations of the bundled `fixture-audio-NN.ts` segments: an 18-second instrumental piece.
    static let segmentDurations = [3.018600, 3.018589, 2.972156, 3.018600, 2.972156, 3.018589, 0.046444]

    private static func makeFeed(now: Date) -> [FeedItem] {
        let titles = ["Les priorités du débat public", "Un nouveau regard sur les territoires", "Le pouvoir d’achat au cœur des échanges", "La transition écologique en discussion", "Les enjeux de la rentrée"]
        let passages = titles.enumerated().map { i, title in
            let person = persons[i % persons.count]
            return FeedItem(id: Int64(i + 1), seq: Int64(100 - i), at: APIDate.string(now.addingTimeInterval(Double(-i * 780 - 120))),
                            kind: i % 3 == 1 ? "citation" : "intervention", media: i % 2 == 0 ? "radio" : "tv",
                            channel: i % 2 == 0 ? "Radio Test" : "TV Test", show: i % 2 == 0 ? "La matinale" : "Le rendez-vous",
                            person: person.name, role: person.role, party: person.party, title: title,
                            citedBy: i % 3 == 1 ? "La rédaction (fictive)" : "", durationSec: 18, hasMedia: true)
        }
        let publications = ["Préparer les territoires de demain", "Le débat continue, au plus près des citoyens"].enumerated().map { index, title in
            let person = persons[index]
            return FeedItem(id: Int64(6 + index), seq: Int64(95 - index), at: APIDate.string(now.addingTimeInterval(Double(-4_200 - index * 780))),
                            kind: "tweet", media: "x", channel: "X", person: person.name, role: person.role,
                            party: person.party, title: title, channelKey: "x")
        }
        return passages + publications
    }

    static func detail(_ item: FeedItem) -> SequenceDetail {
        if item.isTweet {
            return SequenceDetail(item: item, resume: "", verbatim: "Publication fictive pour tester le suivi des prises de parole sur X. Aucun compte ni propos réel n’est représenté ici.")
        }
        return SequenceDetail(item: item,
                       resume: "Exemple fictif pour découvrir la consultation d’une séquence. Aucun propos réel ni passage à l’antenne n’est représenté ici.",
                       verbatim: "Cette séquence de test présente la lecture d’un passage et son texte associé. Dans votre compte InfoMétrie, vous retrouverez ici le verbatim de l’intervention sélectionnée, son contexte et les informations de diffusion. Le son de test est une courte composition instrumentale.",
                       playFrom: item.at, speechStart: item.at, speechDurationSec: 18)
    }

    /// Deterministic, deliberately nonuniform word timings.
    /// The instrumental audio does not claim to validate speech recognition quality.
    static func wordTimings(_ item: FeedItem) -> SequenceWordTimings {
        let text = detail(item).verbatim
        let words = text.split(whereSeparator: \.isWhitespace).enumerated().map { index, word in
            let start = index <= 18 ? 1_200 + index * 600 : 12_000 + (index - 18) * 200
            return SequenceWordTimings.Word(text: String(word), startMs: Int64(start), endMs: Int64(start + 150))
        }
        return SequenceWordTimings(sequence: item.id, origin: item.at, sentences: [
            .init(text: text, startMs: words.first?.startMs ?? 0, endMs: words.last?.endMs ?? 0, words: words)
        ])
    }
}
#endif
