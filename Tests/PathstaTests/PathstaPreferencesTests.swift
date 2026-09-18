import Foundation
import PathstaCore
import Testing

@Suite("Preferences")
struct PathstaPreferencesTests {
  @Test("Registers enabled defaults")
  func defaultValues() throws {
    try withPreferences { preferences in
      #expect(preferences.allowsDirectoryCreation)
      #expect(preferences.playsErrorSound)
    }
  }

  @Test("Persists each preference independently")
  func persistedValues() throws {
    try withPreferences { preferences in
      preferences.allowsDirectoryCreation = false
      #expect(!preferences.allowsDirectoryCreation)
      #expect(preferences.playsErrorSound)

      preferences.playsErrorSound = false
      #expect(!preferences.allowsDirectoryCreation)
      #expect(!preferences.playsErrorSound)
    }
  }
}

private func withPreferences(_ operation: (PathstaPreferences) throws -> Void) throws {
  let suiteName = "PathstaPreferencesTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }
  try operation(PathstaPreferences(defaults: defaults))
}
