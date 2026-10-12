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
}
