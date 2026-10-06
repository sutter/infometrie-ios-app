import Foundation

/// Passages the reader has seen, kept on the device per account until the API can store them.
/// Each id keeps the time it was seen, so entries older than `retention` are dropped on load.
struct SeenStore {
    /// Longer than any feed window, the 30-day period included.
    static let retention: TimeInterval = 31 * 86_400
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(_ account: String) -> String {
        "seen-passages." + Data(account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8).base64EncodedString()
    }

    /// The ids seen within the retention window; unreadable data counts as nothing seen.
    func load(account: String, now: Date = Date()) -> [Int64: Date] {
        guard let data = defaults.data(forKey: key(account)),
              let stored = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
        var seen: [Int64: Date] = [:]
        for (id, date) in stored {
            guard let id = Int64(id), now.timeIntervalSince(date) <= Self.retention else { continue }
            seen[id] = date
        }
        return seen
    }

    func save(_ seen: [Int64: Date], account: String) {
        let stored = Dictionary(uniqueKeysWithValues: seen.map { (String($0.key), $0.value) })
        defaults.set(try? JSONEncoder().encode(stored), forKey: key(account))
    }

    func clear(account: String) { defaults.removeObject(forKey: key(account)) }
}
