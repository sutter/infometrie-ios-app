import Foundation
import Testing
@testable import InfometrieCore

/// Seen passages are stored on the device per account and forgotten after the retention window.
@Suite(.serialized)
struct SeenStoreTests {
    private func store() throws -> (SeenStore, UserDefaults, String) {
        let suite = "infometrie.tests.seen.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (SeenStore(defaults: defaults), defaults, suite)
    }

    @Test func seenPassagesStayWithTheirAccount() throws {
        let (store, defaults, suite) = try store()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        store.save([42: now, 7: now], account: " A@example.invalid ")
        #expect(store.load(account: "a@example.invalid", now: now).keys.sorted() == [7, 42])
        #expect(store.load(account: "b@example.invalid", now: now).isEmpty)
        store.clear(account: "a@example.invalid")
        #expect(store.load(account: "a@example.invalid", now: now).isEmpty)
    }

    @Test func passagesSeenBeyondTheRetentionAreForgotten() throws {
        let (store, defaults, suite) = try store()
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let recent = now.addingTimeInterval(-86_400)
        let old = now.addingTimeInterval(-SeenStore.retention - 60)
        store.save([1: recent, 2: old], account: "a@example.invalid")
        #expect(store.load(account: "a@example.invalid", now: now) == [1: recent])
    }

    @Test func unreadableDataCountsAsNothingSeen() throws {
        let (store, defaults, suite) = try store()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "seen-passages." + Data("a@example.invalid".utf8).base64EncodedString()
        defaults.set(Data("not json".utf8), forKey: key)
        #expect(store.load(account: "a@example.invalid").isEmpty)
    }
}
