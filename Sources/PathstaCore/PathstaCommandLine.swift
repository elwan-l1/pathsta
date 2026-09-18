import Foundation

/// A supported action selected from Pathsta's command-line arguments.
public enum PathstaCommandLineAction: Equatable, Sendable {
  /// Launch the menu-bar application normally.
  case runApplication

  /// Print Finder's current directory.
  case probeFinder

  /// Navigate Finder to the supplied path.
  case navigate(String)

  /// Print command-line usage.
  case help

  /// Reject malformed or unsupported arguments.
  case invalid(String)
}

/// Parses Pathsta's intentionally small command-line interface.
public enum PathstaCommandLine {
  /// Help text shared by the executable and documentation tests.
  public static let usage = """
    Usage:
      Pathsta
      Pathsta --probe
      Pathsta --navigate <path>
      Pathsta --help
    """

  /// Parses arguments after the executable name.
  public static func parse(_ arguments: [String]) -> PathstaCommandLineAction {
    guard let command = arguments.first else {
      return .runApplication
    }
    switch command {
    case "--probe" where arguments.count == 1:
      return .probeFinder
    case "--help" where arguments.count == 1:
      return .help
    case "-h" where arguments.count == 1:
      return .help
    case "--navigate":
      guard arguments.count == 2, !arguments[1].isEmpty else {
        return .invalid("--navigate requires exactly one path.")
      }
      return .navigate(arguments[1])
    default:
      return .invalid("Unsupported command-line arguments.")
    }
  }
}
