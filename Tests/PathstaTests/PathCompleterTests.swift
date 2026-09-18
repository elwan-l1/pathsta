import Foundation
import PathstaCore
import Testing

@Suite("Path completion")
struct PathCompleterTests {
  @Test("Suggests directories but not files")
  func suggestsDirectoriesOnly() throws {
    try withCompletionDirectory { root in
      try FileManager.default.createDirectory(
        at: root.appending(path: "Alpha", directoryHint: .isDirectory),
        withIntermediateDirectories: false
      )
      try FileManager.default.createDirectory(
        at: root.appending(path: "Alpine", directoryHint: .isDirectory),
        withIntermediateDirectories: false
      )
      FileManager.default.createFile(
        atPath: root.appending(path: "Almanac.txt").path,
        contents: Data()
      )

      let input = root.path + "/al"
      let completions = PathCompleter.directoryCompletions(
        for: input,
        selection: NSRange(location: (input as NSString).length, length: 0),
        relativeTo: nil
      )
      #expect(completions == [root.path + "/Alpha/", root.path + "/Alpine/"])
    }
  }

  @Test("Completes relative directory names")
  func relativeCompletion() throws {
    try withCompletionDirectory { root in
      try FileManager.default.createDirectory(
        at: root.appending(path: "Documents", directoryHint: .isDirectory),
        withIntermediateDirectories: false
      )
      let completions = PathCompleter.directoryCompletions(
        for: "Doc",
        selection: NSRange(location: 3, length: 0),
        relativeTo: root
      )
      #expect(completions == ["Documents/"])
    }
  }

  @Test("Completes directory symbolic links but not file symbolic links")
  func symbolicLinkCompletion() throws {
    try withCompletionDirectory { root in
      let target = root.appending(path: "Target", directoryHint: .isDirectory)
      let linkedDirectory = root.appending(path: "LinkedFolder", directoryHint: .isDirectory)
      let linkedFile = root.appending(path: "LinkedFile")
      try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
      try FileManager.default.createDirectory(
        at: target.appending(path: "Inside", directoryHint: .isDirectory),
        withIntermediateDirectories: false
      )

      let file = root.appending(path: "File.txt")
      FileManager.default.createFile(atPath: file.path, contents: Data())
      try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: target)
      try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: file)

      let linkInput = root.path + "/Linked"
      let linkCompletions = PathCompleter.directoryCompletions(
        for: linkInput,
        selection: NSRange(location: (linkInput as NSString).length, length: 0),
        relativeTo: nil
      )
      #expect(linkCompletions == [root.path + "/LinkedFolder/"])

      let childInput = linkedDirectory.path + "/In"
      let childCompletions = PathCompleter.directoryCompletions(
        for: childInput,
        selection: NSRange(location: (childInput as NSString).length, length: 0),
        relativeTo: nil
      )
      #expect(childCompletions == [linkedDirectory.path + "/Inside/"])

      let relativeCompletions = PathCompleter.directoryCompletions(
        for: "In",
        selection: NSRange(location: 2, length: 0),
        relativeTo: linkedDirectory
      )
      #expect(relativeCompletions == ["Inside/"])
    }
  }

  @Test("Caps completion results after sorting")
  func capsSortedResults() throws {
    try withCompletionDirectory { root in
      for name in ["Zulu", "Alpha", "Echo", "Bravo"] {
        try FileManager.default.createDirectory(
          at: root.appending(path: name, directoryHint: .isDirectory),
          withIntermediateDirectories: false
        )
      }

      let completions = PathCompleter.directoryCompletions(
        for: "",
        selection: NSRange(location: 0, length: 0),
        relativeTo: root,
        maximumResults: 2
      )
      #expect(completions == ["Alpha/", "Bravo/"])
    }
  }

  @Test("Returns no results once its task is cancelled")
  func observesCancellation() async throws {
    try await withCompletionDirectory { root in
      try FileManager.default.createDirectory(
        at: root.appending(path: "Alpha", directoryHint: .isDirectory),
        withIntermediateDirectories: false
      )
      let (stream, continuation) = AsyncStream<Void>.makeStream()
      let task = Task {
        for await _ in stream {
          break
        }
        return PathCompleter.directoryCompletions(
          for: "",
          selection: NSRange(location: 0, length: 0),
          relativeTo: root
        )
      }
      task.cancel()
      continuation.yield()
      continuation.finish()
      #expect(await task.value == [])
    }
  }
}

private func withCompletionDirectory(_ operation: (URL) throws -> Void) throws {
  let root = FileManager.default.temporaryDirectory.appending(
    path: "pathsta-completion-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: root) }
  try operation(root)
}

private func withCompletionDirectory(
  _ operation: (URL) async throws -> Void
) async throws {
  let root = FileManager.default.temporaryDirectory.appending(
    path: "pathsta-completion-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: root) }
  try await operation(root)
}
