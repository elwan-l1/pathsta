import Foundation
import PathstaCore
import Testing

@Suite("Path resolution")
struct PathResolverTests {
  @Test("Resolves an absolute directory")
  func absoluteDirectory() throws {
    let actual = try PathResolver.resolve("/tmp", relativeTo: nil).get().path
    let expected = URL(filePath: "/tmp").resolvingSymlinksInPath().path
    #expect(actual == expected)
  }

  @Test("Resolves a relative directory")
  func relativeDirectory() throws {
    let base = URL(
      filePath: FileManager.default.currentDirectoryPath,
      directoryHint: .isDirectory
    )
    let actual = try PathResolver.resolve("Sources", relativeTo: base).get()
    #expect(actual.lastPathComponent == "Sources")
  }

  @Test("Resolves a local file URL")
  func fileURL() throws {
    let actual = try PathResolver.resolve(
      URL(filePath: "/tmp").absoluteString,
      relativeTo: nil
    ).get().path
    let expected = URL(filePath: "/tmp").resolvingSymlinksInPath().path
    #expect(actual == expected)
  }

  @Test("Rejects a remote file URL")
  func remoteFileURL() {
    let result = PathResolver.resolve("file://example.com/tmp", relativeTo: nil)
    #expect(result == .failure(.notLocalFileURL))
  }

  @Test("Rejects a missing directory")
  func missingDirectory() {
    let result = PathResolver.resolve(
      "/this/folder/does/not/exist/pathsta",
      relativeTo: nil
    )
    guard case .failure(.notDirectory) = result else {
      Issue.record("A missing directory was accepted: \(result)")
      return
    }
  }

  @Test("Rejects empty input")
  func emptyInput() {
    #expect(PathResolver.resolve("   ", relativeTo: nil) == .failure(.empty))
  }
}
