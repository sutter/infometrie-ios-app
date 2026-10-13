import Foundation

/// A passage the reader kept. It holds a copy of the feed entry, so the list shows without the network and a passage
/// gone from the server's history stays recognizable; the text and the media are never stored.
struct Favorite: Codable, Identifiable, Hashable, Sendable {
    var item: FeedItem
    var addedAt: Date
    var id: Int64 { item.id }

    /// The server keeps `FeedPeriod.historyDepth` days: an older passage no longer opens. Decided from the date alone,
    /// with no request; a passage without a readable date counts as available.
    func isUnavailable(now: Date = Date()) -> Bool {
        guard let date = item.date else { return false }
        return ParisDay.string(date) < FeedPeriod.oldestDay(now: now)
    }
}

/// Favorites taken out of the list with their places, so "Annuler" puts them back where they were.
struct RemovedFavorites: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        let index: Int
        let favorite: Favorite
    }
    fileprivate(set) var entries: [Entry] = []
    var count: Int { entries.count }
}

extension Array where Element == Favorite {
    /// Removes the favorites with these ids and returns them with their places.
    mutating func remove(ids: Set<Int64>) -> RemovedFavorites {
        let entries = enumerated().filter { ids.contains($0.element.id) }
            .map { RemovedFavorites.Entry(index: $0.offset, favorite: $0.element) }
        removeAll { ids.contains($0.id) }
        return RemovedFavorites(entries: entries)
    }

    /// Puts removed favorites back at their places, in ascending order so each index holds; one added again
    /// meanwhile is not doubled.
    mutating func restore(_ removed: RemovedFavorites) {
        for entry in removed.entries where !contains(where: { $0.id == entry.favorite.id }) {
            insert(entry.favorite, at: Swift.min(entry.index, count))
        }
    }
}

/// Favorites live on the device, per account, like the seen passages: the API does not store them.
struct FavoriteStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ account: String) -> String {
        "favorite-passages." + Data(account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8).base64EncodedString()
    }
    func load(account: String) throws -> [Favorite] {
        guard let data = defaults.data(forKey: key(account)) else { return [] }
        return try JSONDecoder().decode([Favorite].self, from: data)
    }
    func save(_ favorites: [Favorite], account: String) throws {
        defaults.set(try JSONEncoder().encode(favorites), forKey: key(account))
    }
    func clear(account: String) { defaults.removeObject(forKey: key(account)) }
    /// After a failed `load`, before the next `save`.
    func setAside(account: String) { defaults.setAside(key(account)) }
}
