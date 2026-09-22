import Foundation
import Security

struct SessionStore {
    let service: String
    init(service: String = "fr.yacast.infometrie.ios") { self.service = service }
    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    func read<T: Decodable>(_ type: T.Type, account: String) -> T? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    func save<T: Encodable>(_ value: T, account: String) throws {
        let data = try JSONEncoder().encode(value)
        let q = query(account)
        let changes = [kSecValueData as String: data]
        var status = SecItemUpdate(q as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var item = q
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StoreError.keychain(status) }
    }
    func clearSession() { SecItemDelete(query("session") as CFDictionary) }
    func deviceID() throws -> String {
        if let value = read(String.self, account: "device-id") { return value }
        let value = UUID().uuidString
        try save(value, account: "device-id")
        return value
    }
    enum StoreError: Error, LocalizedError {
        case keychain(OSStatus)
        var errorDescription: String? { "Impossible d’enregistrer la session dans le trousseau sécurisé. Réessayez." }
    }
}
