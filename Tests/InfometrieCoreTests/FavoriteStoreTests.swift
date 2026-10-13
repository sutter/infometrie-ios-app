import Foundation
import Testing
@testable import InfometrieCore

/// Favorites are stored on the device per account, and know when the server's history no longer holds them.
@Suite(.serialized)
struct FavoriteStoreTests {
    private func store() throws -> (FavoriteStore, UserDefaults, String) {
        let suite = "infometrie.tests.favorites.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (FavoriteStore(defaults: defaults), defaults, suite)
    }

    private func favorite(_ id: Int64, at: String = "2026-10-09T14:52:00+02:00", addedAt: Date = Date()) -> Favorite {
        Favorite(item: FeedItem(id: id, at: at, kind: "citation", media: "radio", channel: "Radio Test",
                                person: "Camille Martin", role: "Députée", party: "TEST-A", title: "Un passage gardé",
                                citedBy: "Émilie Dez", durationSec: 47, hasMedia: true, channelKey: "radio-test"),
                 addedAt: addedAt)
    }

    @Test func favoritesRoundTripInTheirOrderWithTheirAccount() throws {
        let (store, defaults, suite) = try store()
        defer { defaults.removePersistentDomain(forName: suite) }
        let saved = [favorite(42, addedAt: Date(timeIntervalSince1970: 2_000)), favorite(7, addedAt: Date(timeIntervalSince1970: 1_000))]
        try store.save(saved, account: " A@example.invalid ")
        let loaded = try store.load(account: "a@example.invalid")
        #expect(loaded == saved)
        #expect(loaded.first?.item.citedBy == "Émilie Dez")
        #expect(try store.load(account: "b@example.invalid").isEmpty)
        store.clear(account: "a@example.invalid")
        #expect(try store.load(account: "a@example.invalid").isEmpty)
    }

    @Test func unreadableFavoritesThrow() throws {
        let (store, defaults, suite) = try store()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "favorite-passages." + Data("a@example.invalid".utf8).base64EncodedString()
        defaults.set(Data("not json".utf8), forKey: key)
        #expect(throws: (any Error).self) { try store.load(account: "a@example.invalid") }
    }

    @Test func removedFavoritesGoBackInPlace() {
        var list = [favorite(1), favorite(2), favorite(3), favorite(4)]
        let removed = list.remove(ids: [2, 4, 9])
        #expect(list.map(\.id) == [1, 3])
        #expect(removed.count == 2)
        // One of them added again meanwhile is not doubled.
        list.insert(favorite(4), at: 0)
        list.restore(removed)
        #expect(list.map(\.id).sorted() == [1, 2, 3, 4])
        var whole = [favorite(1), favorite(2), favorite(3)]
        let all = whole.remove(ids: [1, 2, 3])
        #expect(whole.isEmpty)
        whole.restore(all)
        #expect(whole.map(\.id) == [1, 2, 3])
    }

    @Test func aFavoriteBeyondTheServerHistoryIsUnavailable() throws {
        let now = try #require(APIDate.parse("2026-10-12T10:00:00+02:00"))
        let oldest = FeedPeriod.oldestDay(now: now)
        #expect(oldest == "2026-08-13")
        #expect(!favorite(1, at: "2026-08-13T00:30:00+02:00").isUnavailable(now: now))
        #expect(favorite(2, at: "2026-08-12T23:30:00+02:00").isUnavailable(now: now))
        #expect(!favorite(3, at: "2026-10-11T18:00:00+02:00").isUnavailable(now: now))
        #expect(!favorite(4, at: "pas une date").isUnavailable(now: now))
    }
}
