import CoreGraphics
import PathstaCore
import Testing

@Suite("Finder overlay geometry")
struct WindowGeometryTests {
  @Test("Converts Quartz coordinates to AppKit coordinates")
  func coordinateConversion() {
    let quartzFrame = CGRect(x: 50, y: 100, width: 800, height: 600)
    let appKitFrame = WindowGeometry.appKitFrame(
      fromQuartzFrame: quartzFrame,
      mainScreenHeight: 1_200
    )
    #expect(appKitFrame == CGRect(x: 50, y: 500, width: 800, height: 600))
  }

  @Test("Offsets the visible editor by the Finder sidebar")
  func sidebarOffset() {
    let finderFrame = CGRect(x: 50, y: 100, width: 800, height: 600)
    let pathBarFrame = WindowGeometry.pathBarFrame(
      finderFrame: finderFrame,
      sidebarWidth: 205
    )
    #expect(pathBarFrame == CGRect(x: 255, y: 100, width: 595, height: 28))
  }

  @Test("Supports a hidden Finder sidebar")
  func hiddenSidebar() {
    let finderFrame = CGRect(x: 50, y: 100, width: 800, height: 600)
    let pathBarFrame = WindowGeometry.pathBarFrame(
      finderFrame: finderFrame,
      sidebarWidth: 0
    )
    #expect(pathBarFrame == CGRect(x: 50, y: 100, width: 800, height: 28))
  }

  @Test("Uses Finder's complete native path row as the click target")
  func fullWidthClickTarget() {
    let finderFrame = CGRect(x: 50, y: 100, width: 800, height: 600)
    let hostFrame = WindowGeometry.pathBarHostFrame(finderFrame: finderFrame)
    #expect(hostFrame == CGRect(x: 50, y: 100, width: 800, height: 28))
  }
}
