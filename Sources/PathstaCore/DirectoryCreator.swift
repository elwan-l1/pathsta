import CoreFoundation
import Darwin
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

/// A newly created directory with a stable reference for identity-preserving handoff.
public struct CreatedDirectory: Sendable, Equatable {
  /// The directory's path when creation completed.
  public let url: URL

  /// File-reference URL data bound to the created filesystem object rather than its pathname.
  public let fileReferenceData: Data

  /// Creates a directory result from its initial path and stable file-reference data.
  public init(url: URL, fileReferenceData: Data) {
    self.url = url
    self.fileReferenceData = fileReferenceData
  }

  /// Resolves the current path for the created filesystem object.
  public func resolvedURL() -> URL? {
    filePathURL(from: fileReferenceData)
  }
}

/// Creates exactly one missing leaf directory beneath an existing parent.
public enum DirectoryCreator {
  /// Creates a leaf directory without creating intermediates or replacing existing items.
  public static func create(
    _ input: String,
    relativeTo currentDirectory: URL?,
    fileManager: FileManager = .default
  ) -> Result<CreatedDirectory, DirectoryCreationError> {
    create(
      input,
      relativeTo: currentDirectory,
      fileManager: fileManager,
      beforeCreatingLeaf: {}
    )
  }

  static func create(
    _ input: String,
    relativeTo currentDirectory: URL?,
    fileManager: FileManager,
    beforeCreatingLeaf: () throws -> Void
  ) -> Result<CreatedDirectory, DirectoryCreationError> {
    let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      return .failure(.empty)
    }

    let candidateResult = directoryCandidate(
      from: trimmedInput,
      relativeTo: currentDirectory
    )
    let candidate: URL
    switch candidateResult {
    case .success(let resolvedCandidate):
      candidate = resolvedCandidate
    case .failure(let error):
      return .failure(error)
    }

    let standardizedCandidate = candidate.standardizedFileURL
    let leafName = standardizedCandidate.lastPathComponent
    guard
      !leafName.isEmpty,
      standardizedCandidate.path != "/",
      !leafName.utf8.contains(0)
    else {
      return .failure(.invalidName)
    }

    let parent = standardizedCandidate.deletingLastPathComponent()
    let target = parent.appending(path: leafName, directoryHint: .isDirectory)
    return createLeaf(
      named: leafName,
      beneath: parent,
      requestedTarget: target,
      fileManager: fileManager,
      beforeCreatingLeaf: beforeCreatingLeaf
    )
  }

  private static func createLeaf(
    named leafName: String,
    beneath parent: URL,
    requestedTarget target: URL,
    fileManager: FileManager,
    beforeCreatingLeaf: () throws -> Void
  ) -> Result<CreatedDirectory, DirectoryCreationError> {
    let parentDescriptor = open(
      parent.path,
      O_SEARCH | O_DIRECTORY | O_CLOEXEC
    )
    guard parentDescriptor >= 0 else {
      return failureOpeningParent(parent, target: target)
    }
    defer { close(parentDescriptor) }

    guard let actualParent = directoryURL(for: parentDescriptor) else {
      return .failure(
        .creationFailed(target.path, "The parent folder location could not be read.")
      )
    }
    let actualTarget = actualParent.appending(path: leafName, directoryHint: .isDirectory)
    let leafPath = fileManager.fileSystemRepresentation(withPath: leafName)
    var metadata = stat()
    if fstatat(parentDescriptor, leafPath, &metadata, AT_SYMLINK_NOFOLLOW) == 0 {
      return .failure(.alreadyExists(actualTarget.path))
    }
    let lookupError = errno
    guard lookupError == ENOENT else {
      return .failure(.creationFailed(actualTarget.path, systemErrorDescription(lookupError)))
    }

    do {
      try beforeCreatingLeaf()
    } catch {
      return .failure(.creationFailed(actualTarget.path, error.localizedDescription))
    }
    guard mkdirat(parentDescriptor, leafPath, mode_t(0o777)) == 0 else {
      let creationError = errno
      let failureTarget =
        directoryURL(for: parentDescriptor)?
        .appending(path: leafName, directoryHint: .isDirectory) ?? actualTarget
      if creationError == EEXIST {
        return .failure(.alreadyExists(failureTarget.path))
      }
      return .failure(.creationFailed(failureTarget.path, systemErrorDescription(creationError)))
    }

    let createdDescriptor = openat(
      parentDescriptor,
      leafPath,
      O_SEARCH | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
    )
    guard createdDescriptor >= 0 else {
      return .failure(
        .creationFailed(actualTarget.path, systemErrorDescription(errno))
      )
    }
    defer { close(createdDescriptor) }
    guard let createdDirectory = createdDirectory(for: createdDescriptor) else {
      return .failure(
        .creationFailed(actualTarget.path, "The created folder identity could not be read.")
      )
    }
    return .success(createdDirectory)
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

  private static func directoryURL(for descriptor: Int32) -> URL? {
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    let result: Int32 = buffer.withUnsafeMutableBufferPointer { storage in
      guard let baseAddress = storage.baseAddress else {
        return Int32(-1)
      }
      return fcntl(descriptor, F_GETPATH, UnsafeMutableRawPointer(baseAddress))
    }
    guard result == 0, let path = string(fromNullTerminated: buffer) else {
      return nil
    }
    return URL(filePath: path, directoryHint: .isDirectory)
  }

  private static func createdDirectory(for descriptor: Int32) -> CreatedDirectory? {
    let descriptorURL = URL(
      filePath: "/dev/fd/\(descriptor)",
      directoryHint: .isDirectory
    )
    guard
      let unmanagedReference = CFURLCreateFileReferenceURL(
        kCFAllocatorDefault,
        descriptorURL as CFURL,
        nil
      )
    else {
      return nil
    }
    let reference = unmanagedReference.takeRetainedValue()
    guard
      let unmanagedPath = CFURLCreateFilePathURL(kCFAllocatorDefault, reference, nil),
      let referenceString = CFURLGetString(reference) as String?,
      let referenceData = referenceString.data(using: .utf8)
    else {
      return nil
    }
    return CreatedDirectory(
      url: unmanagedPath.takeRetainedValue() as URL,
      fileReferenceData: referenceData
    )
  }

  private static func failureOpeningParent(
    _ parent: URL,
    target: URL
  ) -> Result<CreatedDirectory, DirectoryCreationError> {
    let openError = errno
    if openError == ENOENT || openError == ENOTDIR || openError == ELOOP {
      return .failure(.parentNotDirectory(parent.path))
    }
    return .failure(.creationFailed(target.path, systemErrorDescription(openError)))
  }

  private static func systemErrorDescription(_ errorNumber: Int32) -> String {
    String(cString: strerror(errorNumber))
  }

  private static func string(fromNullTerminated buffer: [CChar]) -> String? {
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(bytes: bytes, encoding: .utf8)
  }
}

private func filePathURL(from referenceData: Data) -> URL? {
  let bytes = [UInt8](referenceData)
  guard
    let reference = bytes.withUnsafeBufferPointer({ storage in
      CFURLCreateWithBytes(
        kCFAllocatorDefault,
        storage.baseAddress,
        storage.count,
        CFStringBuiltInEncodings.UTF8.rawValue,
        nil
      )
    }),
    let path = CFURLCreateFilePathURL(kCFAllocatorDefault, reference, nil)
  else {
    return nil
  }
  return path.takeRetainedValue() as URL
}
