import AppKit

enum FinderLocation: Equatable {
  case directory(URL)
  case virtual(String)
}

struct FinderWindowState: Equatable {
  let location: FinderLocation
  let sidebarWidth: CGFloat
}

enum FinderBridgeError: LocalizedError, Equatable {
  case noWindow
  case virtualLocation(String)
  case automationDenied(String)
  case invalidReply
  case navigationFailed(String)

  var errorDescription: String? {
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

/// Reads and changes Finder state through Finder's public AppleScript dictionary.
@MainActor
final class FinderBridge {
  // Polling reuses this compiled script to avoid repeatedly paying AppleScript compilation cost.
  private let windowStateScript = NSAppleScript(
    source: """
      tell application "Finder"
        if not (exists front Finder window) then return {"", 0}
        set currentWindow to front Finder window
        set currentSidebarWidth to sidebar width of currentWindow
        try
          set currentLocation to POSIX path of (target of currentWindow as alias)
        on error
          set currentLocation to "__PATHSTA_VIRTUAL__" & name of currentWindow
        end try
        return {currentLocation, currentSidebarWidth}
      end tell
      """)

  func windowState() -> Result<FinderWindowState, FinderBridgeError> {
    guard let windowStateScript else {
      return .failure(.invalidReply)
    }

    var errorDetails: NSDictionary?
    let reply = windowStateScript.executeAndReturnError(&errorDetails)
    if errorDetails != nil {
      return .failure(.automationDenied(Self.describe(errorDetails)))
    }
    guard reply.numberOfItems >= 2, let path = reply.atIndex(1)?.stringValue else {
      return .failure(.invalidReply)
    }
    guard !path.isEmpty else {
      return .failure(.noWindow)
    }

    let sidebarWidth = max(0, CGFloat(reply.atIndex(2)?.int32Value ?? 0))
    let virtualPrefix = "__PATHSTA_VIRTUAL__"
    if path.hasPrefix(virtualPrefix) {
      return .success(
        FinderWindowState(
          location: .virtual(String(path.dropFirst(virtualPrefix.count))),
          sidebarWidth: sidebarWidth
        )
      )
    }
    return .success(
      FinderWindowState(
        location: .directory(
          URL(filePath: path, directoryHint: .isDirectory).standardizedFileURL
        ),
        sidebarWidth: sidebarWidth
      )
    )
  }

  func currentDirectory() -> Result<URL, FinderBridgeError> {
    switch windowState() {
    case .success(let state):
      switch state.location {
      case .directory(let directory):
        .success(directory)
      case .virtual(let name):
        .failure(.virtualLocation(name))
      }
    case .failure(let error):
      .failure(error)
    }
  }

  func navigate(to directory: URL) -> Result<Void, FinderBridgeError> {
    let pathLiteral = Self.appleScriptLiteral(directory.path)
    let source = """
      tell application "Finder"
        set destinationFolder to (POSIX file \(pathLiteral)) as alias
        if exists front Finder window then
          set target of front Finder window to destinationFolder
        else
          open destinationFolder
        end if
      end tell
      """
    guard let script = NSAppleScript(source: source) else {
      return .failure(.navigationFailed("The navigation command could not be compiled."))
    }

    var errorDetails: NSDictionary?
    _ = script.executeAndReturnError(&errorDetails)
    guard errorDetails == nil else {
      return .failure(.navigationFailed(Self.describe(errorDetails)))
    }
    return .success(())
  }

  private static func appleScriptLiteral(_ value: String) -> String {
    let escapedValue =
      value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\n", with: "\\n")
    return "\"\(escapedValue)\""
  }

  private static func describe(_ details: NSDictionary?) -> String {
    if let message = details?[NSAppleScript.errorMessage] as? String {
      return message
    }
    return "Check System Settings › Privacy & Security › Automation."
  }
}
