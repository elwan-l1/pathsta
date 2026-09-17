import CoreGraphics

/// Computes the overlay frames that align with Finder's bottom path row.
public enum WindowGeometry {
  /// Finder's native path row height in AppKit points.
  public static let nativePathBarHeight: CGFloat = 28

  /// Converts a Quartz window frame to AppKit's bottom-left coordinate space.
  public static func appKitFrame(
    fromQuartzFrame frame: CGRect,
    mainScreenHeight: CGFloat
  ) -> CGRect {
    CGRect(
      x: frame.minX,
      y: mainScreenHeight - frame.maxY,
      width: frame.width,
      height: frame.height
    )
  }

  /// Returns the full-width frame used to detect clicks in Finder's path row.
  public static func pathBarHostFrame(finderFrame: CGRect) -> CGRect {
    CGRect(
      x: finderFrame.minX,
      y: finderFrame.minY,
      width: finderFrame.width,
      height: nativePathBarHeight
    ).integral
  }

  /// Returns the visible editor frame after accounting for Finder's sidebar.
  public static func pathBarFrame(
    finderFrame: CGRect,
    sidebarWidth: CGFloat,
    edgeInset: CGFloat = 0,
    bottomInset: CGFloat = 0,
    height: CGFloat = nativePathBarHeight
  ) -> CGRect {
    let maximumSidebarWidth = max(0, finderFrame.width - 160)
    let safeSidebarWidth = min(max(0, sidebarWidth), maximumSidebarWidth)
    return CGRect(
      x: finderFrame.minX + safeSidebarWidth + edgeInset,
      y: finderFrame.minY + bottomInset,
      width: max(144, finderFrame.width - safeSidebarWidth - (edgeInset * 2)),
      height: height
    ).integral
  }
}
