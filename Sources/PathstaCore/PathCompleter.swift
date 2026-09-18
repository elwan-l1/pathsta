import Foundation

/// Produces Finder-style directory completions for editable path text.
public enum PathCompleter {
  /// Returns sorted directory completions for the component that contains the insertion point.
  public static func directoryCompletions(
    for text: String,
    selection: NSRange,
    relativeTo currentDirectory: URL?,
    maximumResults: Int = 200,
    fileManager: FileManager = .default
  ) -> [String] {
    guard maximumResults > 0, !Task.isCancelled else {
      return []
    }
    let source = text as NSString
    let selectionStart = min(max(0, selection.location), source.length)
    let selectionEnd = min(max(selectionStart, NSMaxRange(selection)), source.length)
    let prefix = source.substring(to: selectionStart) as NSString
    let suffix = source.substring(from: selectionEnd)
    let slashRange = prefix.range(of: "/", options: .backwards)

    let componentStart = slashRange.location == NSNotFound ? 0 : NSMaxRange(slashRange)
    let componentPrefix = prefix.substring(from: componentStart)
    let textBeforeComponent = prefix.substring(to: componentStart)
    let parentText = parentPath(from: textBeforeComponent)

    guard let parentDirectory = directoryURL(for: parentText, relativeTo: currentDirectory) else {
      return []
    }

    var options: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]
    if !componentPrefix.hasPrefix(".") {
      options.insert(.skipsHiddenFiles)
    }
    var enumerationFailed = false
    guard
      let children = fileManager.enumerator(
        at: parentDirectory,
        includingPropertiesForKeys: nil,
        options: options,
        errorHandler: { _, _ in
          enumerationFailed = true
          return false
        }
      )
    else {
      return []
    }

    var completions: [String] = []
    for case let child as URL in children {
      guard !Task.isCancelled else {
        return []
      }
      guard
        let candidate = completion(
          for: child,
          componentPrefix: componentPrefix,
          textBeforeComponent: textBeforeComponent,
          suffix: suffix,
          fileManager: fileManager
        )
      else {
        continue
      }
      insert(candidate, into: &completions, limit: maximumResults)
    }
    guard !enumerationFailed, !Task.isCancelled else {
      return []
    }
    return completions
  }

  private static func insert(_ candidate: String, into results: inout [String], limit: Int) {
    var lowerBound = 0
    var upperBound = results.count
    while lowerBound < upperBound {
      let index = lowerBound + (upperBound - lowerBound) / 2
      if results[index].localizedStandardCompare(candidate) == .orderedAscending {
        lowerBound = index + 1
      } else {
        upperBound = index
      }
    }

    guard lowerBound < limit else {
      return
    }
    results.insert(candidate, at: lowerBound)
    if results.count > limit {
      results.removeLast()
    }
  }

  private static func parentPath(from textBeforeComponent: String) -> String {
    if textBeforeComponent == "/" {
      return "/"
    }
    return textBeforeComponent.hasSuffix("/")
      ? String(textBeforeComponent.dropLast())
      : textBeforeComponent
  }

  private static func directoryURL(
    for parentPath: String,
    relativeTo currentDirectory: URL?
  ) -> URL? {
    if parentPath.isEmpty {
      return currentDirectory?.resolvingSymlinksInPath()
    }

    let expandedPath = NSString(string: parentPath).expandingTildeInPath
    if expandedPath.hasPrefix("/") {
      return URL(filePath: expandedPath, directoryHint: .isDirectory)
        .standardizedFileURL
        .resolvingSymlinksInPath()
    }
    return currentDirectory?
      .appending(path: expandedPath, directoryHint: .isDirectory)
      .standardizedFileURL
      .resolvingSymlinksInPath()
  }

  private static func completion(
    for child: URL,
    componentPrefix: String,
    textBeforeComponent: String,
    suffix: String,
    fileManager: FileManager
  ) -> String? {
    let name = child.lastPathComponent
    guard name.hasLocalizedCaseInsensitivePrefix(componentPrefix) else {
      return nil
    }

    var isDirectory = ObjCBool(false)
    guard
      fileManager.fileExists(atPath: child.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return nil
    }

    let separator = suffix.hasPrefix("/") ? "" : "/"
    return textBeforeComponent + name + separator + suffix
  }
}

extension String {
  fileprivate func hasLocalizedCaseInsensitivePrefix(_ prefix: String) -> Bool {
    prefix.isEmpty
      || range(
        of: prefix,
        options: [.anchored, .caseInsensitive, .diacriticInsensitive]
      ) != nil
  }
}
