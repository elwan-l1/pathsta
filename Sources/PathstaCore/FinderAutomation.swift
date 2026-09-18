import Foundation

/// A location reported by Finder's front window.
public enum FinderLocation: Equatable, Sendable {
  /// A local filesystem directory.
  case directory(URL)

  /// A Finder view, such as Recents, that has no filesystem path.
  case virtual(String)
}

/// The state needed to render Pathsta over Finder's front window.
public struct FinderWindowState: Equatable, Sendable {
  /// The location displayed by Finder.
  public let location: FinderLocation

  /// Finder's sidebar width, clamped to zero or greater.
  public let sidebarWidth: CGFloat

  /// Creates a parsed Finder window state.
  public init(location: FinderLocation, sidebarWidth: CGFloat) {
    self.location = location
    self.sidebarWidth = sidebarWidth
  }
}

/// Errors produced while reading or changing Finder state.
public enum FinderBridgeError: LocalizedError, Equatable, Sendable {
  /// Finder has no open window.
  case noWindow

  /// Finder is displaying a view that has no local filesystem path.
  case virtualLocation(String)

  /// macOS denied or failed the Finder automation request.
  case automationDenied(String)

  /// Finder returned a malformed response.
  case invalidReply

  /// Finder rejected a navigation request.
  case navigationFailed(String)

  /// A user-facing description of the failure.
  public var errorDescription: String? {
    switch self {
    case .noWindow:
      "Open a Finder window to attach the path bar."
    case .virtualLocation(let name):
      "Finder › \(name) has no filesystem path."
    case .automationDenied(let detail):
      "Finder automation permission is required. \(detail)"
    case .invalidReply:
      "Finder returned an invalid folder path."
    case .navigationFailed(let detail):
      "Could not open that folder. \(detail)"
    }
  }
}

/// Parses the stable values returned by Pathsta's Finder AppleScript.
public enum FinderReplyParser {
  /// The marker prepended to Finder locations that have no filesystem path.
  public static let virtualLocationPrefix = "__PATHSTA_VIRTUAL__"

  /// Converts Finder's path and sidebar values into validated application state.
  public static func parse(
    path: String?,
    sidebarWidth: Int32?
  ) -> Result<FinderWindowState, FinderBridgeError> {
    guard let path else {
      return .failure(.invalidReply)
    }
    guard !path.isEmpty else {
      return .failure(.noWindow)
    }

    let width = max(0, CGFloat(sidebarWidth ?? 0))
    if path.hasPrefix(virtualLocationPrefix) {
      return .success(
        FinderWindowState(
          location: .virtual(String(path.dropFirst(virtualLocationPrefix.count))),
          sidebarWidth: width
        )
      )
    }
    return .success(
      FinderWindowState(
        location: .directory(
          URL(filePath: path, directoryHint: .isDirectory).standardizedFileURL
        ),
        sidebarWidth: width
      )
    )
  }
}

/// Produces safe AppleScript string literals from untrusted path text.
public enum AppleScriptLiteral {
  /// Quotes a value while escaping AppleScript control characters and delimiters.
  public static func quote(_ value: String) -> String {
    let escapedValue =
      value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\n", with: "\\n")
    return "\"\(escapedValue)\""
  }
}
