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
    var summary: String {
        let names = persons.sorted() + parties.sorted()
        return names.isEmpty ? "Tout le panel" : names.joined(separator: " · ")
    }
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
}

enum FeedMerge {
    static func merge(existing: [FeedItem], incoming: [FeedItem], now: Date = Date()) -> [FeedItem] {
        var unique: [Int64: FeedItem] = [:]
        for item in existing + incoming { unique[item.id] = item }
        return unique.values.filter { ($0.date ?? now) >= now.addingTimeInterval(-86_400) }
            .sorted { $0.seq == $1.seq ? $0.at > $1.at : $0.seq > $1.seq }
    }
}
