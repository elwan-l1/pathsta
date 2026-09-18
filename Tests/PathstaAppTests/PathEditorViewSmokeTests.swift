import AppKit
import Testing

@testable import Pathsta

@Suite("Path editor UI")
struct PathEditorViewSmokeTests {
  @Test("Lays out and exposes the Finder path activation control")
  @MainActor
  func laysOutActivationControl() throws {
    _ = NSApplication.shared
    let view = PathEditorView(frame: NSRect(x: 0, y: 0, width: 720, height: 28))
    view.sidebarWidth = 180
    view.show(path: URL(filePath: "/tmp", directoryHint: .isDirectory))
    view.layoutSubtreeIfNeeded()

    #expect(view.subviews.count == 2)
    let hitView = try #require(view.hitTest(NSPoint(x: 400, y: 14)))
    #expect(hitView.accessibilityLabel() == "Edit Finder folder path")
  }
}
