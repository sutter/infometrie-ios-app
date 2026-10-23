import Foundation

struct SearchFilters: Codable, Hashable, Sendable {
    var persons: Set<String> = []
    var parties: Set<String> = []
    var interventions = true
    var citations = true
    var tweets = true
    var isEmpty: Bool { persons.isEmpty && parties.isEmpty }
    var selectedKinds: [String] {
        [("intervention", interventions), ("citation", citations), ("tweet", tweets)].compactMap { $0.1 ? $0.0 : nil }
    }
    var hasKinds: Bool { !selectedKinds.isEmpty }
    var kindSummary: String {
        [interventions ? "Interventions" : nil, citations ? "Citations" : nil, tweets ? "Publications X" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }
    /// The editor and the quick filters share the same selection; nil denotes a saved combination.
    var kindSelection: Int? {
        if selectedKinds.count == 3 { return 0 }
        if selectedKinds.count == 1 { return interventions ? 1 : citations ? 2 : 3 }
        return nil
    }
    mutating func selectKind(_ index: Int) {
        interventions = index == 0 || index == 1
        citations = index == 0 || index == 2
        tweets = index == 0 || index == 3
    }
    init(persons: Set<String> = [], parties: Set<String> = [], interventions: Bool = true, citations: Bool = true, tweets: Bool = true) {
        self.persons = persons; self.parties = parties
        self.interventions = interventions; self.citations = citations; self.tweets = tweets
    }
    enum CodingKeys: String, CodingKey { case persons, parties, interventions, citations, tweets }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        persons = try c.decodeIfPresent(Set<String>.self, forKey: .persons) ?? []
        parties = try c.decodeIfPresent(Set<String>.self, forKey: .parties) ?? []
        interventions = try c.decodeIfPresent(Bool.self, forKey: .interventions) ?? true
        citations = try c.decodeIfPresent(Bool.self, forKey: .citations) ?? true
        // Saved searches created before API 0.6 must not silently broaden to X.
        tweets = try c.decodeIfPresent(Bool.self, forKey: .tweets) ?? false
    }
    /// Persons, then parties by their name in `known` (a party missing from it keeps its code), each alphabetical.
    func summary(parties known: [Party] = []) -> String {
        let partyNames = parties.map { code in known.first { $0.code == code }?.name ?? code }.sorted()
        let names = persons.sorted() + partyNames
        return names.isEmpty ? "Tout le panel" : names.joined(separator: " · ")
    }
    /// The name a suivi takes from its criteria, until renamed: its audience, then the kinds it keeps when it
    /// leaves one out ("Groupe B · Citations").
    func suggestedName(parties known: [Party] = []) -> String {
        let audience = summary(parties: known)
        return (1...2).contains(selectedKinds.count) ? "\(audience) · \(kindSummary)" : audience
    }
    /// Same persons and parties, whatever the kinds: the journal's kind boxes only narrow what is read.
    func sameAudience(as other: SearchFilters) -> Bool { persons == other.persons && parties == other.parties }
    func accepts(_ item: FeedItem) -> Bool {
        selectedKinds.contains(item.kind)
            && (persons.isEmpty || persons.contains(item.person))
            && (parties.isEmpty || parties.contains(item.party))
    }
}

struct SavedSearch: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var filters: SearchFilters
    var createdAt = Date()
    var lastUsedAt: Date?
    var archivedAt: Date?
    var isArchived: Bool { archivedAt != nil }
    /// The criteria under the name, nil when they only repeat it: a suivi named after its one person, or still
    /// carrying the name its criteria gave it.
    func criteria(parties: [Party] = []) -> String? {
        let summary = filters.summary(parties: parties)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let repeats = [summary, filters.suggestedName(parties: parties)]
            .contains { name.compare($0, options: .caseInsensitive) == .orderedSame }
        return repeats ? nil : summary
    }
}

enum FeedMerge {
    /// Newest broadcast first. `seq` is the polling cursor, not a time: the backend renumbers the journal in no
    /// particular order when it restarts, a passage indexed late gets a higher one, and history items carry 0.
    static func merge(existing: [FeedItem], incoming: [FeedItem], now: Date = Date()) -> [FeedItem] {
        var unique: [Int64: FeedItem] = [:]
        for item in existing + incoming { unique[item.id] = item }
        return oldestFirst(unique.values.filter { ($0.date ?? now) >= now.addingTimeInterval(-86_400) }).reversed()
    }
    /// By the parsed broadcast time, since `at` strings with other offsets ("Z", "+02:00") do not sort as text;
    /// equal times by id, and an unreadable time as the oldest.
    static func oldestFirst(_ items: [FeedItem]) -> [FeedItem] {
        let dated: [(item: FeedItem, date: Date)] = items.map { ($0, $0.date ?? .distantPast) }
        return dated.sorted { $0.date == $1.date ? $0.item.id < $1.item.id : $0.date < $1.date }.map(\.item)
    }
}
