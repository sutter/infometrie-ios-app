import Foundation

struct SearchFilters: Codable, Equatable, Sendable {
    var persons: Set<String> = []
    var parties: Set<String> = []
    var interventions = true
    var citations = true
    var isEmpty: Bool { persons.isEmpty && parties.isEmpty }
    var hasKinds: Bool { interventions || citations }
    var summary: String {
        let names = persons.sorted() + parties.sorted()
        return names.isEmpty ? "Tout le panel" : names.joined(separator: " · ")
    }
    func accepts(_ item: FeedItem) -> Bool {
        (item.isCitation ? citations : interventions)
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
