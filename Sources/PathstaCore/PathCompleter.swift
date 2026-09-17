import Foundation

/// Produces Finder-style directory completions for editable path text.
public enum PathCompleter {
  /// Returns sorted directory completions for the component that contains the insertion point.
  public static func directoryCompletions(
    for text: String,
    selection: NSRange,
    relativeTo currentDirectory: URL?,
    fileManager: FileManager = .default
  ) -> [String] {
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

    let options: FileManager.DirectoryEnumerationOptions =
      componentPrefix.hasPrefix(".") ? [] : [.skipsHiddenFiles]
    guard
      let children = try? fileManager.contentsOfDirectory(
        at: parentDirectory,
        includingPropertiesForKeys: nil,
        options: options
      )
    else {
      return []
    }

    return children.compactMap { child in
      completion(
        for: child,
        componentPrefix: componentPrefix,
        textBeforeComponent: textBeforeComponent,
        suffix: suffix,
        fileManager: fileManager
      )
    }
    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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
    range(
      of: prefix,
      options: [.anchored, .caseInsensitive, .diacriticInsensitive]
    ) != nil
  }
}
