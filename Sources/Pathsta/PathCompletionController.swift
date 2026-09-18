import AppKit
import PathstaCore

@MainActor
final class PathCompletionController {
  typealias CompletionProvider = @Sendable (String, NSRange, URL?) -> [String]

  private struct Cycle {
    let completions: [String]
    var index: Int
    var renderedText: String
  }

  private var cycle: Cycle?
  private var requestTask: Task<Void, Never>?
  private var isApplyingCompletion = false
  private let completionProvider: CompletionProvider

  init(
    completionProvider: @escaping CompletionProvider = { text, selection, currentDirectory in
      PathCompleter.directoryCompletions(
        for: text,
        selection: selection,
        relativeTo: currentDirectory
      )
    }
  ) {
    self.completionProvider = completionProvider
  }

  deinit {
    requestTask?.cancel()
  }

  func cancel() {
    requestTask?.cancel()
    requestTask = nil
    cycle = nil
  }

  func textDidChange() {
    if !isApplyingCompletion {
      cancel()
    }
  }

  func complete(
    editor: NSTextView,
    relativeTo currentDirectory: URL?,
    backwards: Bool,
    onMissingCompletion: @escaping @MainActor () -> Void
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

    cancel()
    let sourceText = editor.string
    let sourceSelection = editor.selectedRange
    let worker = Task.detached(priority: .userInitiated) { [completionProvider] in
      completionProvider(sourceText, sourceSelection, currentDirectory)
    }
    requestTask = Task { [weak self, weak editor] in
      let completions = await withTaskCancellationHandler {
        await worker.value
      } onCancel: {
        worker.cancel()
      }

      guard
        let self,
        !Task.isCancelled,
        let editor,
        editor.string == sourceText,
        editor.selectedRange == sourceSelection
      else {
        return
      }
      requestTask = nil
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
  }

  private func apply(_ completion: String, to editor: NSTextView) {
    isApplyingCompletion = true
    defer { isApplyingCompletion = false }
    editor.string = completion
    editor.selectedRange = NSRange(location: (completion as NSString).length, length: 0)
  }
}
