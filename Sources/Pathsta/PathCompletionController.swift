import AppKit
import PathstaCore

@MainActor
final class PathCompletionController {
  private struct Cycle {
    let completions: [String]
    var index: Int
    var renderedText: String
  }

  private var cycle: Cycle?
  private var isApplyingCompletion = false

  func textDidChange() {
    if !isApplyingCompletion {
      cycle = nil
    }
  }

  func complete(
    editor: NSTextView,
    relativeTo currentDirectory: URL?,
    backwards: Bool,
    onMissingCompletion: () -> Void
  ) {
    if var currentCycle = cycle,
      currentCycle.renderedText == editor.string,
      currentCycle.completions.count > 1
    {
      let offset = backwards ? -1 : 1
      currentCycle.index =
        (currentCycle.index + offset + currentCycle.completions.count)
        % currentCycle.completions.count
      currentCycle.renderedText = currentCycle.completions[currentCycle.index]
      cycle = currentCycle
      apply(currentCycle.renderedText, to: editor)
      return
    }

    cycle = nil
    let completions = PathCompleter.directoryCompletions(
      for: editor.string,
      selection: editor.selectedRange,
      relativeTo: currentDirectory
    )
    guard !completions.isEmpty else {
      onMissingCompletion()
      return
    }

    let index = backwards ? completions.count - 1 : 0
    let renderedText = completions[index]
    cycle = Cycle(
      completions: completions,
      index: index,
      renderedText: renderedText
    )
    apply(renderedText, to: editor)
  }

  private func apply(_ completion: String, to editor: NSTextView) {
    isApplyingCompletion = true
    defer { isApplyingCompletion = false }
    editor.string = completion
    editor.selectedRange = NSRange(location: (completion as NSString).length, length: 0)
  }
}
