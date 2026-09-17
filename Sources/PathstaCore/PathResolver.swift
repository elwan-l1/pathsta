import Foundation

/// Errors produced while converting editable text into a local directory URL.
public enum PathResolverError: LocalizedError, Equatable {
  /// The field contains no path.
  case empty

  /// The field contains a nonlocal or malformed file URL.
  case notLocalFileURL

  /// The resolved item isn't an existing directory.
  case notDirectory(String)

  /// A message suitable for presenting beside the path field.
  public var errorDescription: String? {
    switch self {
    case .empty:
      "Enter a folder path."
    case .notLocalFileURL:
      "Only local file URLs are supported."
    case .notDirectory(let path):
      "Folder does not exist: \(path)"
    }
  }
}

/// Resolves absolute paths, relative paths, tilde paths, and local file URLs.
public enum PathResolver {
  /// Resolves editable path text to an existing local directory.
  public static func resolve(
    _ input: String,
    relativeTo currentDirectory: URL?,
    fileManager: FileManager = .default
  ) -> Result<URL, PathResolverError> {
    let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      return .failure(.empty)
    }

    let candidate: URL
    if trimmedInput.lowercased().hasPrefix("file:") {
      guard let fileURL = URL(string: trimmedInput), fileURL.isLocalFileURL else {
        return .failure(.notLocalFileURL)
      }
      candidate = fileURL
    } else {
      let expandedPath = NSString(string: trimmedInput).expandingTildeInPath
      if expandedPath.hasPrefix("/") {
        candidate = URL(filePath: expandedPath, directoryHint: .isDirectory)
      } else if let currentDirectory {
        candidate = currentDirectory.appending(
          path: expandedPath,
          directoryHint: .isDirectory
        )
      } else {
        candidate = URL(filePath: expandedPath, directoryHint: .isDirectory)
      }
    }

    let directory = candidate.standardizedFileURL.resolvingSymlinksInPath()
    var isDirectory = ObjCBool(false)
    guard
      fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return .failure(.notDirectory(directory.path))
    }
    return .success(directory)
  }
}
