import AppKit

final class PathTextField: NSTextField {
  override var needsPanelToBecomeKey: Bool { true }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    window?.makeKey()
    window?.makeFirstResponder(self)
    super.mouseDown(with: event)
  }
}

final class PathActivationButton: NSButton {
  override var needsPanelToBecomeKey: Bool { true }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    guard event.type == .leftMouseDown, let action else {
      return
    }
    NSApp.sendAction(action, to: target, from: self)
  }
}

final class PathEditorBackgroundView: NSView {
  override var wantsUpdateLayer: Bool { true }
  override var isOpaque: Bool { true }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.isOpaque = true
    layer?.masksToBounds = true
    layer?.maskedCorners = [.layerMaxXMinYCorner]
    layer?.cornerCurve = .continuous
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("PathEditorBackgroundView doesn't support Interface Builder.")
  }

  override func updateLayer() {
    effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
      self?.layer?.backgroundColor = NSColor.unemphasizedSelectedContentBackgroundColor.cgColor
    }
  }

  override func layout() {
    super.layout()
    layer?.cornerRadius = bounds.height / 2
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }
}

extension NSView {
  func addPathstaShakeAnimation() {
    guard let layer else {
      return
    }
    let animation = CAKeyframeAnimation(keyPath: "position.x")
    animation.values = [0, -4, 4, -3, 3, 0]
    animation.keyTimes = [0, 0.16, 0.32, 0.55, 0.78, 1]
    animation.duration = 0.24
    animation.isAdditive = true
    layer.add(animation, forKey: "pathsta.shake")
  }
}
