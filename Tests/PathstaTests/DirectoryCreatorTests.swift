import Foundation
import Testing

@testable import PathstaCore

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
        atPath: created.url.path,
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

  @Test("Creates beneath the opened parent when its path is replaced")
  func resistsParentReplacement() throws {
    try withTemporaryDirectory { root in
      let parent = root.appending(path: "Parent", directoryHint: .isDirectory)
      let movedParent = root.appending(path: "MovedParent", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)

      let result = DirectoryCreator.create(
        "Parent/Created",
        relativeTo: root,
        fileManager: .default,
        beforeCreatingLeaf: {
          try FileManager.default.moveItem(at: parent, to: movedParent)
          try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        }
      )

      let created = try result.get()
      let createdPath = created.url
      #expect(createdPath.lastPathComponent == "Created")
      #expect(try fileNumber(createdPath.deletingLastPathComponent()) == fileNumber(movedParent))
      #expect(FileManager.default.fileExists(atPath: createdPath.path))
      #expect(
        !FileManager.default.fileExists(
          atPath: parent.appending(path: "Created", directoryHint: .isDirectory).path
        )
      )
    }
  }

  @Test("Returns a stable identity for the created directory")
  func returnsStableCreatedDirectoryIdentity() throws {
    try withTemporaryDirectory { root in
      let parent = root.appending(path: "Parent", directoryHint: .isDirectory)
      let movedParent = root.appending(path: "MovedParent", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)

      let created = try DirectoryCreator.create("Parent/Created", relativeTo: root).get()
      try FileManager.default.moveItem(at: parent, to: movedParent)
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
      try FileManager.default.createDirectory(
        at: parent.appending(path: "Created", directoryHint: .isDirectory),
        withIntermediateDirectories: false
      )

      let resolved = try #require(created.resolvedURL())
      let expected = movedParent.appending(path: "Created", directoryHint: .isDirectory)
      #expect(try fileNumber(resolved) == fileNumber(expected))
    }
  }

  @Test("Reports conflicts beneath the descriptor-bound parent")
  func reportsRacedConflictLocation() throws {
    try withTemporaryDirectory { root in
      let parent = root.appending(path: "Parent", directoryHint: .isDirectory)
      let movedParent = root.appending(path: "MovedParent", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)

      let result = DirectoryCreator.create(
        "Parent/Created",
        relativeTo: root,
        fileManager: .default,
        beforeCreatingLeaf: {
          try FileManager.default.moveItem(at: parent, to: movedParent)
          try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
          try FileManager.default.createDirectory(
            at: movedParent.appending(path: "Created", directoryHint: .isDirectory),
            withIntermediateDirectories: false
          )
        }
      )

      guard case .failure(.alreadyExists(let path)) = result else {
        Issue.record("The descriptor-bound conflict was not reported: \(result)")
        return
      }
      #expect(
        try fileNumber(URL(filePath: path, directoryHint: .isDirectory))
          == fileNumber(movedParent.appending(path: "Created", directoryHint: .isDirectory))
      )
    }
  }

  @Test("Creates beneath a parent reached through a symbolic link")
  func followsExistingParentSymbolicLink() throws {
    try withTemporaryDirectory { root in
      let actualParent = root.appending(path: "Actual", directoryHint: .isDirectory)
      let linkedParent = root.appending(path: "Linked", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(
        at: actualParent,
        withIntermediateDirectories: false
      )
      try FileManager.default.createSymbolicLink(
        at: linkedParent,
        withDestinationURL: actualParent
      )

      let created = try DirectoryCreator.create(
        "Linked/Created",
        relativeTo: root
      ).get()
      #expect(try fileNumber(created.url.deletingLastPathComponent()) == fileNumber(actualParent))
      #expect(FileManager.default.fileExists(atPath: created.url.path))
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

private func fileNumber(_ url: URL) throws -> NSNumber? {
  try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? NSNumber
}
