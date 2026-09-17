import Foundation
import PathstaCore
import Testing

@Suite("Safe directory creation")
struct DirectoryCreatorTests {
  @Test("Creates exactly one missing leaf directory")
  func createsLeafDirectory() throws {
    try withTemporaryDirectory { root in
      let created = try DirectoryCreator.create(
        "Created",
        relativeTo: root
      ).get()
      var isDirectory = ObjCBool(false)
      let exists = FileManager.default.fileExists(
        atPath: created.path,
        isDirectory: &isDirectory
      )
      #expect(exists)
      #expect(isDirectory.boolValue)
    }
  }

  @Test("Rejects an existing item")
  func rejectsExistingItem() throws {
    try withTemporaryDirectory { root in
      let existing = root.appending(path: "Existing", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: false)
      let result = DirectoryCreator.create(existing.path, relativeTo: nil)
      guard case .failure(.alreadyExists) = result else {
        Issue.record("An existing directory was accepted: \(result)")
        return
      }
    }
  }

  @Test("Rejects a dangling symbolic link")
  func rejectsDanglingSymbolicLink() throws {
    try withTemporaryDirectory { root in
      let link = root.appending(path: "Dangling")
      try FileManager.default.createSymbolicLink(
        at: link,
        withDestinationURL: root.appending(path: "Missing")
      )
      let result = DirectoryCreator.create(link.path, relativeTo: nil)
      guard case .failure(.alreadyExists) = result else {
        Issue.record("A dangling symbolic link was replaced: \(result)")
        return
      }
    }
  }

  @Test("Never creates intermediate directories")
  func rejectsMissingParent() throws {
    try withTemporaryDirectory { root in
      let missingParent = root.appending(path: "Missing", directoryHint: .isDirectory)
      let nested = missingParent.appending(path: "Child", directoryHint: .isDirectory)
      let result = DirectoryCreator.create(nested.path, relativeTo: nil)
      guard case .failure(.parentNotDirectory) = result else {
        Issue.record("A directory with a missing parent was accepted: \(result)")
        return
      }
      #expect(!FileManager.default.fileExists(atPath: missingParent.path))
    }
  }

  @Test("Requires a base directory for relative paths")
  func rejectsUnanchoredRelativePath() {
    let result = DirectoryCreator.create("Relative", relativeTo: nil)
    #expect(result == .failure(.relativePathRequiresCurrentDirectory))
  }

  @Test("Rejects remote file URLs")
  func rejectsRemoteFileURL() {
    let result = DirectoryCreator.create("file://example.com/tmp/New", relativeTo: nil)
    #expect(result == .failure(.notLocalFileURL))
  }
}

private func withTemporaryDirectory(_ operation: (URL) throws -> Void) throws {
  let root = FileManager.default.temporaryDirectory.appending(
    path: "pathsta-tests-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: root) }
  try operation(root)
}
