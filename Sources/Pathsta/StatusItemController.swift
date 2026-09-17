import AppKit

@MainActor
protocol StatusItemControllerDelegate: AnyObject {
  func statusItemDidRequestAutomationSettings()
  func statusItemDidSetErrorSoundEnabled(_ isEnabled: Bool)
  func statusItemDidSetDirectoryCreationEnabled(_ isEnabled: Bool)
}

@MainActor
final class StatusItemController: NSObject {
  weak var delegate: StatusItemControllerDelegate?

  private let statusItem = NSStatusBar.system.statusItem(
    withLength: NSStatusItem.squareLength
  )
  private let errorSoundMenuItem = NSMenuItem()
  private let directoryCreationMenuItem = NSMenuItem()

  init(
    delegate: StatusItemControllerDelegate,
    errorSoundEnabled: Bool,
    directoryCreationEnabled: Bool
  ) {
    self.delegate = delegate
    super.init()
    configureButton()
    configureMenu(
      errorSoundEnabled: errorSoundEnabled,
      directoryCreationEnabled: directoryCreationEnabled
    )
  }

  @objc private func toggleErrorSound() {
    errorSoundMenuItem.state = errorSoundMenuItem.state == .on ? .off : .on
    delegate?.statusItemDidSetErrorSoundEnabled(errorSoundMenuItem.state == .on)
  }

  @objc private func toggleDirectoryCreation() {
    directoryCreationMenuItem.state = directoryCreationMenuItem.state == .on ? .off : .on
    delegate?.statusItemDidSetDirectoryCreationEnabled(
      directoryCreationMenuItem.state == .on
    )
  }

  @objc private func openAutomationSettings() {
    delegate?.statusItemDidRequestAutomationSettings()
  }

  private func configureButton() {
    let image =
      NSImage(named: "MenuBarIcon")
      ?? NSImage(
        systemSymbolName: "folder.badge.gearshape",
        accessibilityDescription: "Pathsta"
      )
    image?.isTemplate = true
    statusItem.button?.image = image
    statusItem.button?.setAccessibilityLabel("Pathsta")
  }

  private func configureMenu(
    errorSoundEnabled: Bool,
    directoryCreationEnabled: Bool
  ) {
    let menu = NSMenu()
    let heading = NSMenuItem(title: "Pathsta", action: nil, keyEquivalent: "")
    heading.isEnabled = false
    menu.addItem(heading)
    menu.addItem(.separator())

    configureToggleItem(
      errorSoundMenuItem,
      title: "Play Error Sound",
      action: #selector(toggleErrorSound),
      isEnabled: errorSoundEnabled
    )
    menu.addItem(errorSoundMenuItem)

    configureToggleItem(
      directoryCreationMenuItem,
      title: "Allow Shift-Return Folder Creation",
      action: #selector(toggleDirectoryCreation),
      isEnabled: directoryCreationEnabled
    )
    menu.addItem(directoryCreationMenuItem)
    menu.addItem(
      menuItem(title: "Automation Settings…", action: #selector(openAutomationSettings))
    )
    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit Pathsta",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = NSApp
    menu.addItem(quitItem)
    statusItem.menu = menu
  }

  private func configureToggleItem(
    _ item: NSMenuItem,
    title: String,
    action: Selector,
    isEnabled: Bool
  ) {
    item.title = title
    item.action = action
    item.target = self
    item.state = isEnabled ? .on : .off
  }

  private func menuItem(title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }
}
