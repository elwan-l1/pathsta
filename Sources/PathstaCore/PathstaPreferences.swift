import Foundation

/// Typed access to Pathsta's persisted user preferences.
public final class PathstaPreferences {
  private enum Key {
    static let allowsDirectoryCreation = "allowsDirectoryCreation"
    static let launchAtLogin = "launchAtLogin"
    static let playsErrorSound = "playsErrorSound"
  }

  private let defaults: UserDefaults

  /// Creates a preference store and registers Pathsta's default values.
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      Key.allowsDirectoryCreation: true,
      Key.launchAtLogin: true,
      Key.playsErrorSound: true,
    ])
  }

  /// Whether Shift-Return may create a missing leaf directory.
  public var allowsDirectoryCreation: Bool {
    get { defaults.bool(forKey: Key.allowsDirectoryCreation) }
    set { defaults.set(newValue, forKey: Key.allowsDirectoryCreation) }
  }

  /// Whether Pathsta should ask macOS to launch it when the user logs in.
  public var launchAtLogin: Bool {
    get { defaults.bool(forKey: Key.launchAtLogin) }
    set { defaults.set(newValue, forKey: Key.launchAtLogin) }
  }

  /// Whether rejected navigation should play the system alert sound.
  public var playsErrorSound: Bool {
    get { defaults.bool(forKey: Key.playsErrorSound) }
    set { defaults.set(newValue, forKey: Key.playsErrorSound) }
  }
}
