import Foundation
import PathstaCore
import Testing

@Suite("Finder automation values")
struct FinderAutomationTests {
  @Test("Escapes AppleScript string delimiters and control characters")
  func escapesAppleScriptLiteral() {
    let value = "Disk \\\"quoted\"\r\nFolder"
    #expect(AppleScriptLiteral.quote(value) == "\"Disk \\\\\\\"quoted\\\"\\r\\nFolder\"")
  }

  @Test("Rejects missing and empty Finder locations")
  func rejectsInvalidLocations() {
    #expect(FinderReplyParser.parse(path: nil, sidebarWidth: 10) == .failure(.invalidReply))
    #expect(FinderReplyParser.parse(path: "", sidebarWidth: 10) == .failure(.noWindow))
  }

  @Test("Parses local Finder locations and clamps negative sidebar widths")
  func parsesDirectoryLocation() throws {
    let state = try FinderReplyParser.parse(path: "/tmp/../tmp", sidebarWidth: -4).get()
    #expect(state.location == .directory(URL(filePath: "/tmp", directoryHint: .isDirectory)))
    #expect(state.sidebarWidth == 0)
  }

  @Test("Parses virtual Finder locations")
  func parsesVirtualLocation() throws {
    let state = try FinderReplyParser.parse(
      path: FinderReplyParser.virtualLocationPrefix + "Recents",
      sidebarWidth: 240
    ).get()
    #expect(state == FinderWindowState(location: .virtual("Recents"), sidebarWidth: 240))
  }
}
