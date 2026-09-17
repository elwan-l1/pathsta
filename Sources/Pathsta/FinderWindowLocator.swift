import AppKit
import PathstaCore

@MainActor
struct FinderWindowLocator {
  func frontWindowFrame(processIdentifier: pid_t) -> CGRect? {
    guard
      let windows = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[CFString: Any]]
    else {
      return nil
    }

    for window in windows {
      guard
        (window[kCGWindowOwnerPID] as? NSNumber)?.int32Value == processIdentifier,
        (window[kCGWindowLayer] as? NSNumber)?.intValue == 0,
        let bounds = window[kCGWindowBounds] as? NSDictionary,
        let quartzFrame = CGRect(dictionaryRepresentation: bounds),
        quartzFrame.width >= 320,
        quartzFrame.height >= 180
      else {
        continue
      }
      return appKitFrame(fromQuartzFrame: quartzFrame)
    }
    return nil
  }

  func appKitFrame(
    fromQuartzFrame frame: CGRect,
    mainScreenHeight: CGFloat? = nil
  ) -> CGRect {
    let screenHeight = mainScreenHeight ?? NSScreen.screens.first?.frame.maxY ?? 0
    return WindowGeometry.appKitFrame(
      fromQuartzFrame: frame,
      mainScreenHeight: screenHeight
    )
  }
}
