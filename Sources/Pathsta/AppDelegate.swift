import AppKit
import OSLog
import PathstaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, PathEditorViewDelegate,
  StatusItemControllerDelegate
{
  private enum PreferenceKey {
    static let allowsDirectoryCreation = "allowsDirectoryCreation"
    static let playsErrorSound = "playsErrorSound"
  }

  private static let logger = Logger(
    subsystem: "com.elwan.pathsta",
    category: "application"
  )

  private let finderBundleIdentifier = "com.apple.finder"
  private let bridge = FinderBridge()
  private let locator = FinderWindowLocator()
  private let panel = PathOverlayPanel()
  private let pathEditor = PathEditorView()

  private var pollTimer: Timer?
  private var globalMouseMonitor: Any?
  private var lifetimeActivity: NSObjectProtocol?
  private var statusItemController: StatusItemController?
  private var finderApplication: NSRunningApplication?
  private var currentDirectory: URL?
  private var sidebarWidth: CGFloat = 0
  private var pollTick = 0

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureProcessLifetime()
    configurePreferences()
    configureOverlay()
    configureStatusItem()
    observeActiveApplication()
    startPolling()
    installGlobalMouseMonitor()
    updateActiveApplication(forcePath: true)
    Self.logger.info("Pathsta is ready and waiting for Finder")
  }

  func applicationWillTerminate(_ notification: Notification) {
    pollTimer?.invalidate()
    if let globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
    }
    if let lifetimeActivity {
      ProcessInfo.processInfo.endActivity(lifetimeActivity)
    }
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  func pathEditorDidRequestNavigation(_ text: String) {
    switch PathResolver.resolve(text, relativeTo: currentDirectory) {
    case .failure(let error):
      pathEditor.rejectNavigation(message: error.localizedDescription)
    case .success(let directory):
      navigate(to: directory, createdDirectory: false)
    }
  }

  func pathEditorDidRequestDirectoryCreation(_ text: String) {
    switch DirectoryCreator.create(text, relativeTo: currentDirectory) {
    case .failure(let error):
      pathEditor.rejectNavigation(message: error.localizedDescription)
    case .success(let directory):
      navigate(to: directory, createdDirectory: true)
    }
  }

  func pathEditorDidBeginEditing() {
    startPolling()
    Self.logger.debug("Path editor opened")
  }

  func pathEditorDidEndEditing() {
    Self.logger.debug("Path editor closed")
    if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != finderBundleIdentifier {
      finderApplication?.activate()
    }
  }

  func statusItemDidRequestAutomationSettings() {
    guard
      let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
      )
    else {
      return
    }
    NSWorkspace.shared.open(settingsURL)
  }

  func statusItemDidSetErrorSoundEnabled(_ isEnabled: Bool) {
    pathEditor.playsErrorSound = isEnabled
    UserDefaults.standard.set(isEnabled, forKey: PreferenceKey.playsErrorSound)
  }

  func statusItemDidSetDirectoryCreationEnabled(_ isEnabled: Bool) {
    pathEditor.allowsDirectoryCreation = isEnabled
    UserDefaults.standard.set(isEnabled, forKey: PreferenceKey.allowsDirectoryCreation)
  }

  @objc private func activeApplicationChanged(_ notification: Notification) {
    updateActiveApplication(forcePath: true)
  }
}

extension AppDelegate {
  private func configureProcessLifetime() {
    ProcessInfo.processInfo.automaticTerminationSupportEnabled = true
    lifetimeActivity = ProcessInfo.processInfo.beginActivity(
      options: [.automaticTerminationDisabled, .suddenTerminationDisabled],
      reason: "Pathsta must remain available for Finder path-bar clicks"
    )
    NSApp.setActivationPolicy(.accessory)
  }

  private func configurePreferences() {
    UserDefaults.standard.register(defaults: [
      PreferenceKey.allowsDirectoryCreation: true,
      PreferenceKey.playsErrorSound: true,
    ])
    pathEditor.playsErrorSound = UserDefaults.standard.bool(
      forKey: PreferenceKey.playsErrorSound
    )
    pathEditor.allowsDirectoryCreation = UserDefaults.standard.bool(
      forKey: PreferenceKey.allowsDirectoryCreation
    )
  }

  private func configureOverlay() {
    panel.contentView = pathEditor
    pathEditor.delegate = self
  }

  private func configureStatusItem() {
    statusItemController = StatusItemController(
      delegate: self,
      errorSoundEnabled: pathEditor.playsErrorSound,
      directoryCreationEnabled: pathEditor.allowsDirectoryCreation
    )
  }

  private func observeActiveApplication() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(activeApplicationChanged(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )
  }

  private func startPolling() {
    guard pollTimer == nil else {
      return
    }

    // Finder emits no public notification for path or sidebar-width changes.
    let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.updateActiveApplication(forcePath: false)
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
  }

  private func installGlobalMouseMonitor() {
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) {
      [weak self] event in
      let mouseLocation = NSEvent.mouseLocation
      let targetProcessIdentifier = event.cgEvent.map {
        pid_t($0.getIntegerValueField(.eventTargetUnixProcessID))
      }
      DispatchQueue.main.async { [weak self] in
        MainActor.assumeIsolated {
          self?.handleGlobalMouseDown(
            at: mouseLocation,
            targetProcessIdentifier: targetProcessIdentifier
          )
        }
      }
    }
  }

  private func handleGlobalMouseDown(
    at point: CGPoint,
    targetProcessIdentifier: pid_t?
  ) {
    if pathEditor.isEditing {
      let clickedEditor =
        targetProcessIdentifier == ProcessInfo.processInfo.processIdentifier
        && panel.frame.contains(point)
      if !clickedEditor {
        // A global monitor observes rather than consumes the click, so Finder acts on it once.
        pathEditor.dismissEditor()
      }
      return
    }

    guard
      let finderApplication = NSRunningApplication.runningApplications(
        withBundleIdentifier: finderBundleIdentifier
      ).first,
      targetProcessIdentifier == finderApplication.processIdentifier,
      let finderFrame = locator.frontWindowFrame(
        processIdentifier: finderApplication.processIdentifier
      ),
      WindowGeometry.pathBarHostFrame(finderFrame: finderFrame).contains(point)
    else {
      return
    }

    self.finderApplication = finderApplication
    refresh(forcePath: true)
    pathEditor.activateEditor()
  }

  private func updateActiveApplication(forcePath: Bool) {
    let frontmostApplication = NSWorkspace.shared.frontmostApplication
    if frontmostApplication?.bundleIdentifier == finderBundleIdentifier {
      finderApplication = frontmostApplication
      refresh(forcePath: forcePath)
    } else if frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
      pathEditor.isEditing
    {
      refresh(forcePath: false)
    } else if frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier,
      !pathEditor.isEditing
    {
      pathEditor.dismissEditor()
      panel.orderOut(nil)
    }
  }

  private func refresh(forcePath: Bool) {
    guard
      let finderApplication,
      let finderFrame = locator.frontWindowFrame(
        processIdentifier: finderApplication.processIdentifier
      )
    else {
      panel.orderOut(nil)
      return
    }

    pollTick += 1
    // Geometry stays responsive at 120 ms; AppleScript state is sampled at half that frequency.
    if forcePath || pollTick.isMultiple(of: 2) {
      updateFinderState()
    }

    pathEditor.sidebarWidth = sidebarWidth
    let panelFrame = WindowGeometry.pathBarHostFrame(finderFrame: finderFrame)
    if panel.frame != panelFrame {
      panel.setFrame(panelFrame, display: true, animate: false)
    }
    if !panel.isVisible {
      panel.orderFrontRegardless()
      Self.logger.debug("Attached overlay to Finder window")
    }
  }

  private func updateFinderState() {
    switch bridge.windowState() {
    case .success(let state):
      updateSidebarWidth(state.sidebarWidth)
      updateLocation(state.location)
    case .failure(let error):
      pathEditor.show(error: error.localizedDescription)
    }
  }

  private func updateSidebarWidth(_ newWidth: CGFloat) {
    if abs(newWidth - sidebarWidth) >= 1 {
      Self.logger.debug("Finder sidebar width changed to \(newWidth) points")
    }
    sidebarWidth = newWidth
  }

  private func updateLocation(_ location: FinderLocation) {
    switch location {
    case .directory(let directory):
      guard directory != currentDirectory else {
        return
      }
      if pathEditor.isEditing {
        pathEditor.dismissEditor()
      }
      currentDirectory = directory
      pathEditor.show(path: directory)
      Self.logger.debug("Finder directory changed: \(directory.path, privacy: .private)")
    case .virtual(let name):
      currentDirectory = nil
      pathEditor.show(virtualLocation: name)
    }
  }

  private func navigate(to directory: URL, createdDirectory: Bool) {
    switch bridge.navigate(to: directory) {
    case .success:
      currentDirectory = directory
      pathEditor.finishNavigation(path: directory)
      Self.logger.debug("Finder navigation succeeded: \(directory.path, privacy: .private)")
    case .failure(let error):
      let message =
        createdDirectory
        ? "Folder was created, but Finder could not open it: \(error.localizedDescription)"
        : error.localizedDescription
      pathEditor.rejectNavigation(message: message)
    }
  }

}
