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
    /// Passages of the last 30 complete Paris days, served by `/history` and counted by `/days`.
    /// The last 7 days hold 8 passages each, more than one 50-item page.
    static let history = makeHistory(now: Date())
    static var all: [FeedItem] { feed + history }
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

    private static func makeHistory(now: Date) -> [FeedItem] {
        let titles = ["Retour sur les débats de la semaine", "Les services publics en question", "Un échange sur l’emploi des jeunes", "La santé au programme", "Les transports du quotidien"]
        let days = ParisDay.days(count: 30, before: now)
        var items: [FeedItem] = []
        for (index, day) in days.enumerated() {
            guard let midnight = ParisDay.date(day) else { continue }
            // Ids grow with time, like the server's, so `before_id` pages from the newest.
            let count = index >= days.count - 7 ? 8 : index % 4
            for slot in 0..<count {
                let person = persons[(index + slot) % persons.count]
                let kind = ["intervention", "citation", "intervention", "tweet"][(index + slot) % 4]
                let id = Int64(1_000 + index * 10 + slot)
                items.append(FeedItem(id: id, at: APIDate.string(midnight.addingTimeInterval(Double(8 * 3_600 + slot * 1_500))),
                                      kind: kind, media: kind == "tweet" ? "x" : "radio", channel: kind == "tweet" ? "X" : "Radio Test",
                                      show: kind == "tweet" ? "" : "La matinale", person: person.name, role: person.role,
                                      party: person.party, title: titles[(index + slot) % titles.count],
                                      citedBy: kind == "citation" ? "La rédaction (fictive)" : "", durationSec: kind == "tweet" ? 0 : 18,
                                      hasMedia: kind != "tweet", channelKey: kind == "tweet" ? "x" : ""))
            }
        }
        return items
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
