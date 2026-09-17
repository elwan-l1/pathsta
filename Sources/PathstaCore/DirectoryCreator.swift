import Foundation

/// Errors produced by the guarded single-folder creation operation.
public enum DirectoryCreationError: LocalizedError, Equatable {
  /// The field contains no path.
  case empty

  /// The field contains a nonlocal or malformed file URL.
  case notLocalFileURL

  /// A relative path was supplied without an active Finder directory.
  case relativePathRequiresCurrentDirectory

  /// The requested path doesn't contain a valid leaf name.
  case invalidName

  /// The immediate parent isn't an existing directory.
  case parentNotDirectory(String)

  /// A file, directory, or symbolic link already occupies the target path.
  case alreadyExists(String)

  /// The filesystem rejected creation of the requested directory.
  case creationFailed(String, String)

  /// A message suitable for presenting beside the path field.
  public var errorDescription: String? {
    switch self {
    case .empty:
      "Enter a folder path."
    case .notLocalFileURL:
      "Only local file URLs are supported."
    case .relativePathRequiresCurrentDirectory:
      "A relative folder needs a current Finder directory."
    case .invalidName:
      "Enter a name for the new folder."
    case .parentNotDirectory(let path):
      "Parent folder does not exist: \(path)"
    case .alreadyExists(let path):
      "An item already exists at: \(path)"
    case let .creationFailed(path, reason):
      "Could not create \(path): \(reason)"
    }
  }
}

/// Creates exactly one missing leaf directory beneath an existing parent.
public enum DirectoryCreator {
  /// Creates a leaf directory without creating intermediates or replacing existing items.
  public static func create(
    _ input: String,
    relativeTo currentDirectory: URL?,
    fileManager: FileManager = .default
  ) -> Result<URL, DirectoryCreationError> {
    let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      return .failure(.empty)
    }

    let candidateResult = directoryCandidate(
      from: trimmedInput,
      relativeTo: currentDirectory
    )
    guard case .success(let candidate) = candidateResult else {
      return candidateResult
    }

    let standardizedCandidate = candidate.standardizedFileURL
    let leafName = standardizedCandidate.lastPathComponent
    guard !leafName.isEmpty, standardizedCandidate.path != "/" else {
      return .failure(.invalidName)
    }

    // Resolve the existing parent first so creation never follows a new leaf symlink.
    let parent = standardizedCandidate.deletingLastPathComponent().resolvingSymlinksInPath()
    var parentIsDirectory = ObjCBool(false)
    guard
      fileManager.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory),
      parentIsDirectory.boolValue
    else {
      return .failure(.parentNotDirectory(parent.path))
    }

    let target = parent.appending(path: leafName, directoryHint: .isDirectory)
    if itemExistsIncludingDanglingSymbolicLink(at: target, fileManager: fileManager) {
      return .failure(.alreadyExists(target.path))
    }

    do {
      try fileManager.createDirectory(
        at: target,
        withIntermediateDirectories: false,
        attributes: nil
      )
      return .success(target.resolvingSymlinksInPath())
    } catch {
      return .failure(.creationFailed(target.path, error.localizedDescription))
    }
  }

  private static func directoryCandidate(
    from input: String,
    relativeTo currentDirectory: URL?
  ) -> Result<URL, DirectoryCreationError> {
    if input.lowercased().hasPrefix("file:") {
      guard let fileURL = URL(string: input), fileURL.isLocalFileURL else {
        return .failure(.notLocalFileURL)
      }
      return .success(fileURL)
    }

    let expandedPath = NSString(string: input).expandingTildeInPath
    if expandedPath.hasPrefix("/") {
      return .success(URL(filePath: expandedPath, directoryHint: .isDirectory))
    }
    guard let currentDirectory else {
      return .failure(.relativePathRequiresCurrentDirectory)
    }
    return .success(
      currentDirectory.appending(path: expandedPath, directoryHint: .isDirectory)
    )
  }

  private static func itemExistsIncludingDanglingSymbolicLink(
    at url: URL,
    fileManager: FileManager
  ) -> Bool {
    if fileManager.fileExists(atPath: url.path) {
      return true
    }
    return (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
  }
}
