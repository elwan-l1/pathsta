import AppKit

/// A nonactivating panel that can still own the field editor while Finder remains active.
final class PathOverlayPanel: NSPanel {
  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isOpaque = false
    backgroundColor = .clear
    ignoresMouseEvents = false
    hasShadow = false
    level = .floating
    isFloatingPanel = true
    becomesKeyOnlyIfNeeded = true
    hidesOnDeactivate = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
  }

  // Text editing needs a key window, but making the panel main would deactivate Finder.
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard
      modifiers == .command,
      let key = event.charactersIgnoringModifiers?.lowercased(),
      let editor = firstResponder as? NSTextView
    else {
      return super.performKeyEquivalent(with: event)
    }

    // Nonactivating panels don't receive the normal Edit menu routing, so forward its shortcuts.
    switch key {
    case "a":
      editor.selectAll(nil)
    case "c":
      editor.copy(nil)
    case "v":
      editor.paste(nil)
    case "x":
      editor.cut(nil)
    default:
      return super.performKeyEquivalent(with: event)
    }
    return true
  }
}
