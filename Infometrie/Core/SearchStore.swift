import Foundation

struct SearchStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ account: String) -> String {
        "saved-searches." + Data(account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8).base64EncodedString()
    }
    func load(account: String) throws -> [SavedSearch] {
        guard let data = defaults.data(forKey: key(account)) else { return [] }
        return try JSONDecoder().decode([SavedSearch].self, from: data)
    }
    func save(_ searches: [SavedSearch], account: String) throws {
        defaults.set(try JSONEncoder().encode(searches), forKey: key(account))
    }
    func clear(account: String) { defaults.removeObject(forKey: key(account)) }
    /// After a failed `load`, before the next `save`.
    func setAside(account: String) { defaults.setAside(key(account)) }
}

extension UserDefaults {
    /// Keeps a value that no longer reads under a key of its own, before anything new replaces it: the list then
    /// starts empty without losing what was stored, which a later version may read again. The first value set aside
    /// stays.
    func setAside(_ key: String) {
        guard let stored = data(forKey: key), data(forKey: "unreadable." + key) == nil else { return }
        set(stored, forKey: "unreadable." + key)
    }
}
