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
}
