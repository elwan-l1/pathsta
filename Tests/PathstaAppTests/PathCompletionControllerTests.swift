import AppKit
import Dispatch
import Testing

@testable import Pathsta

@Suite("Path completion controller")
struct PathCompletionControllerTests {
  @Test("Cancels detached completion work when the text changes")
  @MainActor
  func cancelsDetachedWork() async {
    let started = DispatchSemaphore(value: 0)
    let cancelled = DispatchSemaphore(value: 0)
    let controller = PathCompletionController { _, _, _ in
      started.signal()
      while !Task.isCancelled {
        Thread.sleep(forTimeInterval: 0.001)
      }
      cancelled.signal()
      return []
    }
    let editor = NSTextView()

    controller.complete(
      editor: editor,
      relativeTo: nil,
      backwards: false,
      onMissingCompletion: {}
    )
    #expect(await wait(for: started))

    controller.textDidChange()

    #expect(await wait(for: cancelled))
  }

  @Test("Cancels detached completion work when the controller is released")
  @MainActor
  func cancelsDetachedWorkOnRelease() async {
    let started = DispatchSemaphore(value: 0)
    let cancelled = DispatchSemaphore(value: 0)
    var controller: PathCompletionController? = PathCompletionController { _, _, _ in
      started.signal()
      while !Task.isCancelled {
        Thread.sleep(forTimeInterval: 0.001)
      }
      cancelled.signal()
      return []
    }
    let editor = NSTextView()

    controller?.complete(
      editor: editor,
      relativeTo: nil,
      backwards: false,
      onMissingCompletion: {}
    )
    #expect(await wait(for: started))

    controller = nil

    #expect(await wait(for: cancelled))
  }
}

private func wait(for semaphore: DispatchSemaphore) async -> Bool {
  await withCheckedContinuation { continuation in
    DispatchQueue.global().async {
      continuation.resume(returning: semaphore.wait(timeout: .now() + 1) == .success)
    }
  }
}
