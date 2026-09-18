import AppKit
import PathstaCore

/// Reads and changes Finder state through Finder's public AppleScript dictionary.
@MainActor
final class FinderBridge {
  private static let appleScriptSuite: AEEventClass = 0x6173_6372  // 'ascr'
  private static let subroutineEvent: AEEventID = 0x7073_6272  // 'psbr'
  private static let subroutineNameKeyword: AEKeyword = 0x736E_616D  // 'snam'

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

  private let navigationScript = NSAppleScript(
    source: """
      on navigateTo(destinationFolder)
        tell application "Finder"
          if exists front Finder window then
            set target of front Finder window to destinationFolder
          else
            open destinationFolder
          end if
        end tell
      end navigateTo
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
    guard reply.numberOfItems >= 2 else {
      return .failure(.invalidReply)
    }
    return FinderReplyParser.parse(
      path: reply.atIndex(1)?.stringValue,
      sidebarWidth: reply.atIndex(2)?.int32Value
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

  func navigate(
    to directory: URL,
    fileReferenceData: Data? = nil
  ) -> Result<URL, FinderBridgeError> {
    guard let navigationScript else {
      return .failure(.navigationFailed("The navigation command could not be compiled."))
    }

    let targetDescriptor: NSAppleEventDescriptor?
    let bookmark: Data?
    if let fileReferenceData {
      bookmark = nil
      targetDescriptor = NSAppleEventDescriptor(
        descriptorType: DescType(typeFileURL),
        data: fileReferenceData
      )
    } else {
      do {
        let generatedBookmark = try Self.bookmarkData(for: directory)
        bookmark = generatedBookmark
        targetDescriptor = NSAppleEventDescriptor(
          descriptorType: DescType(typeBookmarkData),
          data: generatedBookmark
        )
      } catch {
        return .failure(.navigationFailed(error.localizedDescription))
      }
    }
    guard let targetDescriptor else {
      return .failure(.navigationFailed("The navigation target could not be encoded."))
    }
    let event = Self.navigationEvent(argument: targetDescriptor)
    var errorDetails: NSDictionary?
    _ = navigationScript.executeAppleEvent(event, error: &errorDetails)
    guard errorDetails == nil else {
      return .failure(.navigationFailed(Self.describe(errorDetails)))
    }
    if let fileReferenceData,
      let resolved = CreatedDirectory(
        url: directory,
        fileReferenceData: fileReferenceData
      ).resolvedURL()
    {
      return .success(resolved)
    }
    guard let bookmark else {
      return .failure(.navigationFailed("The navigation target could not be resolved."))
    }
    do {
      return .success(try Self.resolveBookmark(bookmark))
    } catch {
      return .failure(.navigationFailed(error.localizedDescription))
    }
  }

  static func bookmarkData(for directory: URL) throws -> Data {
    try directory.bookmarkData(
      options: [.minimalBookmark],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  static func resolveBookmark(_ bookmark: Data) throws -> URL {
    var isStale = false
    return try URL(
      resolvingBookmarkData: bookmark,
      options: [.withoutUI],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
  }

  private static func navigationEvent(
    argument: NSAppleEventDescriptor
  ) -> NSAppleEventDescriptor {
    let event = NSAppleEventDescriptor(
      eventClass: appleScriptSuite,
      eventID: subroutineEvent,
      targetDescriptor: .null(),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    event.setParam(
      NSAppleEventDescriptor(string: "navigateTo"),
      forKeyword: subroutineNameKeyword
    )
    let arguments = NSAppleEventDescriptor.list()
    arguments.insert(argument, at: 1)
    event.setParam(arguments, forKeyword: AEKeyword(keyDirectObject))
    return event
  }

  private static func describe(_ details: NSDictionary?) -> String {
    if let message = details?[NSAppleScript.errorMessage] as? String {
      return message
    }
    return "Check System Settings › Privacy & Security › Automation."
  }
}
