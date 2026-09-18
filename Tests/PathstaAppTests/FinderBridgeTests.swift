import Foundation
import PathstaCore
import Testing

@testable import Pathsta

@Suite("Finder navigation identity")
struct FinderBridgeTests {
  @Test("File-reference navigation follows the created directory identity")
  @MainActor
  func fileReferenceFollowsCreatedDirectory() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appending(
      path: "pathsta-finder-bridge-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    try fileManager.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? fileManager.removeItem(at: root) }
    let parent = root.appending(path: "Parent", directoryHint: .isDirectory)
    let movedParent = root.appending(path: "MovedParent", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: parent, withIntermediateDirectories: false)

    let created = try DirectoryCreator.create("Parent/Created", relativeTo: root).get()
    try fileManager.moveItem(at: parent, to: movedParent)
    try fileManager.createDirectory(at: parent, withIntermediateDirectories: false)
    let replacement = parent.appending(path: "Created", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: replacement, withIntermediateDirectories: false)

    let resolved = try #require(created.resolvedURL())
    let expected = movedParent.appending(path: "Created", directoryHint: .isDirectory)

    #expect(try fileNumber(resolved) == fileNumber(expected))
    #expect(try fileNumber(resolved) != fileNumber(replacement))
  }
}

private func fileNumber(_ url: URL) throws -> NSNumber? {
  try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? NSNumber
}
