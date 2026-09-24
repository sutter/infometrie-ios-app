import Foundation
import Testing
@testable import InfometrieCore

struct ReadingSizeTests {
    @Test(arguments: [true, false])
    func legacyChoiceIsPreservedAndOnlyMigratedOnce(comfortable: Bool) throws {
        let name = "reading-size-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(comfortable, forKey: "comfortableReading")
        ReadingSize.migrateLegacyPreference(in: defaults)
        #expect(defaults.string(forKey: "readingSize") == (comfortable ? "L" : "M"))

        defaults.set("S", forKey: "readingSize")
        ReadingSize.migrateLegacyPreference(in: defaults)
        #expect(defaults.string(forKey: "readingSize") == "S")
    }

    @Test func freshInstallationKeepsTheDefaultChoice() throws {
        let name = "reading-size-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        ReadingSize.migrateLegacyPreference(in: defaults)
        #expect(defaults.object(forKey: "readingSize") == nil)
        #expect(defaults.object(forKey: "comfortableReading") == nil)
    }
}
