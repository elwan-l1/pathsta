import AppKit
import Testing

@testable import Pathsta

@Suite("Status item")
struct StatusItemControllerTests {
  @Test("Offers a user-initiated update check")
  @MainActor
  func offersUserInitiatedUpdateCheck() throws {
    _ = NSApplication.shared
    let delegate = StatusItemDelegateSpy()
    let updateTarget = UpdateCheckTarget()
    let controller = StatusItemController(
      delegate: delegate,
      errorSoundEnabled: true,
      directoryCreationEnabled: false,
      checkForUpdatesTarget: updateTarget,
      checkForUpdatesAction: #selector(UpdateCheckTarget.checkForUpdates(_:))
    )

    let menu = try #require(controller.menu)
    let updateItem = try #require(
      menu.items.first { $0.title == "Check for Updates…" }
    )

    #expect(updateItem.target === updateTarget)
    #expect(updateItem.action == #selector(UpdateCheckTarget.checkForUpdates(_:)))
    let updateIndex = try #require(menu.items.firstIndex(of: updateItem))
    let quitIndex = try #require(menu.items.firstIndex { $0.title == "Quit Pathsta" })
    #expect(menu.items[updateIndex + 1].isSeparatorItem)
    #expect(updateIndex + 2 == quitIndex)
  }
}

@MainActor
private final class StatusItemDelegateSpy: StatusItemControllerDelegate {
  func statusItemDidRequestAutomationSettings() {}

  func statusItemDidSetErrorSoundEnabled(_ isEnabled: Bool) {}

  func statusItemDidSetDirectoryCreationEnabled(_ isEnabled: Bool) {}
}

@MainActor
private final class UpdateCheckTarget: NSObject {
  @objc func checkForUpdates(_ sender: Any?) {}
}
