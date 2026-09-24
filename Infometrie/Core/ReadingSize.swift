import Foundation

enum ReadingSize: String, CaseIterable {
    case small = "S"
    case medium = "M"
    case large = "L"

    var title: String {
        switch self {
        case .small: "Compact"
        case .medium: "Standard"
        case .large: "Grand"
        }
    }

    static func migrateLegacyPreference(in defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: "readingSize") == nil,
              let comfortable = defaults.object(forKey: "comfortableReading") as? Bool else { return }
        defaults.set((comfortable ? Self.large : .medium).rawValue, forKey: "readingSize")
    }
}
