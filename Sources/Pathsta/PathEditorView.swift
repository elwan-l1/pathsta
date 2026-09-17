import AppKit
import PathstaCore
import UniformTypeIdentifiers

@MainActor
protocol PathEditorViewDelegate: AnyObject {
  func pathEditorDidRequestNavigation(_ text: String)
  func pathEditorDidRequestDirectoryCreation(_ text: String)
  func pathEditorDidBeginEditing()
  func pathEditorDidEndEditing()
}

@MainActor
final class PathEditorView: NSView, NSTextFieldDelegate {
  weak var delegate: PathEditorViewDelegate?

  var isEditing: Bool { editing }
  var playsErrorSound = true
  var allowsDirectoryCreation = true
  var sidebarWidth: CGFloat = 0 {
    didSet {
      if abs(sidebarWidth - oldValue) >= 0.5 {
        needsLayout = true
      }
    }
  }

  private let activationButton = PathActivationButton()
  private let editorBackgroundView = PathEditorBackgroundView()
  private let iconView = NSImageView()
  private let textField = PathTextField()
  private let completionController = PathCompletionController()
  private var committedText = ""
  private var editing = false
  private var editorVisible = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("PathEditorView doesn't support Interface Builder.")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    editorVisible ? super.hitTest(point) : activationButton
  }

  func show(path: URL) {
    committedText = path.path
    guard !isEditing else {
      return
    }
    setFolderIcon(for: path)
    textField.stringValue = committedText
    textField.placeholderString = nil
    textField.toolTip = committedText
    setHealthy(true)
  }

  func show(virtualLocation name: String) {
    guard !isEditing else {
      return
    }
    committedText = ""
    setFolderIcon(for: nil)
    textField.stringValue = "Finder › \(name)"
    textField.placeholderString = nil
    textField.toolTip =
      "This Finder view has no local filesystem path. Enter an absolute path to navigate."
    setHealthy(false)
  }

  func show(error: String) {
    guard !isEditing else {
      return
    }
    textField.placeholderString = error
    textField.toolTip = error
    setHealthy(false)
  }

  func finishNavigation(path: URL) {
    committedText = path.path
    textField.stringValue = committedText
    textField.placeholderString = nil
    textField.toolTip = committedText
    window?.makeFirstResponder(nil)
    setHealthy(true)
  }

  func rejectNavigation(message: String) {
    playErrorSoundIfEnabled()
    setHealthy(false)
    textField.toolTip = message
    textField.addPathstaShakeAnimation()
  }

  @objc func activateEditor() {
    guard !editorVisible else {
      return
    }
    editorVisible = true
    activationButton.isHidden = true
    editorBackgroundView.isHidden = false

    DispatchQueue.main.async { [weak self] in
      guard let self, self.editorVisible else {
        return
      }
      self.window?.makeKeyAndOrderFront(nil)
      guard self.window?.makeFirstResponder(self.textField) == true else {
        self.dismissEditor()
        return
      }
      self.beginEditingSession()
    }
  }

  func dismissEditor() {
    if textField.currentEditor() != nil {
      window?.makeFirstResponder(nil)
      return
    }
    editing = false
    editorVisible = false
    editorBackgroundView.isHidden = true
    activationButton.isHidden = false
  }

  func controlTextDidBeginEditing(_ notification: Notification) {
    beginEditingSession()
  }

  func controlTextDidChange(_ notification: Notification) {
    completionController.textDidChange()
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    editing = false
    editorVisible = false
    editorBackgroundView.isHidden = true
    activationButton.isHidden = false
    delegate?.pathEditorDidEndEditing()
  }

  func control(
    _ control: NSControl,
    textView: NSTextView,
    doCommandBy commandSelector: Selector
  ) -> Bool {
    switch commandSelector {
    case #selector(NSResponder.insertNewline(_:)):
      if allowsDirectoryCreation && isSafeShiftReturn {
        delegate?.pathEditorDidRequestDirectoryCreation(textView.string)
      } else {
        delegate?.pathEditorDidRequestNavigation(textView.string)
      }
      return true
    case #selector(NSResponder.insertTab(_:)):
      completePath(in: textView, backwards: false)
      return true
    case #selector(NSResponder.insertBacktab(_:)):
      completePath(in: textView, backwards: true)
      return true
    case #selector(NSResponder.cancelOperation(_:)):
      textField.stringValue = committedText
      window?.makeFirstResponder(nil)
      return true
    default:
      return false
    }
  }

  override func layout() {
    super.layout()
    activationButton.frame = bounds

    let safeSidebarWidth = min(max(0, sidebarWidth), max(0, bounds.width - 160))
    let nativeBorderInset: CGFloat = 1
    let nativeRightBorderInset: CGFloat = 1
    editorBackgroundView.frame = CGRect(
      x: safeSidebarWidth,
      y: nativeBorderInset,
      width: max(0, bounds.width - safeSidebarWidth - nativeRightBorderInset),
      height: max(0, bounds.height - (nativeBorderInset * 2))
    )

    let editorBounds = editorBackgroundView.bounds
    let iconSize = NSFont.systemFontSize + 3
    let textHeight = ceil(textField.intrinsicContentSize.height)
    iconView.frame = CGRect(
      x: 9,
      y: (editorBounds.height - iconSize) / 2,
      width: iconSize,
      height: iconSize
    )
    textField.frame = CGRect(
      x: 31,
      y: (editorBounds.height - textHeight) / 2,
      width: max(40, editorBounds.width - 40),
      height: textHeight
    )
  }
}

extension PathEditorView {
  private func configure() {
    activationButton.title = ""
    activationButton.isBordered = false
    activationButton.refusesFirstResponder = true
    activationButton.wantsLayer = true
    // A fully transparent layer can be omitted from AppKit hit testing on some macOS versions.
    activationButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.001).cgColor
    activationButton.target = self
    activationButton.action = #selector(activateEditor)
    activationButton.setAccessibilityLabel("Edit Finder folder path")
    addSubview(activationButton)

    editorBackgroundView.isHidden = true
    addSubview(editorBackgroundView)

    iconView.imageScaling = .scaleProportionallyDown
    iconView.setAccessibilityLabel("Current Finder folder")
    setFolderIcon(for: nil)
    editorBackgroundView.addSubview(iconView)

    textField.isEditable = true
    textField.isSelectable = true
    textField.isBordered = false
    textField.drawsBackground = false
    textField.focusRingType = .none
    textField.font = .systemFont(ofSize: NSFont.systemFontSize)
    textField.lineBreakMode = .byTruncatingMiddle
    textField.usesSingleLineMode = true
    textField.delegate = self
    textField.placeholderString = "Waiting for Finder…"
    textField.setAccessibilityLabel("Finder folder path")
    editorBackgroundView.addSubview(textField)
  }

  private func beginEditingSession() {
    if !editing {
      editing = true
      delegate?.pathEditorDidBeginEditing()
    }
    DispatchQueue.main.async { [weak self] in
      guard let self, let editor = self.textField.currentEditor() else {
        return
      }
      editor.selectedRange = NSRange(
        location: (self.textField.stringValue as NSString).length,
        length: 0
      )
    }
  }

  private func completePath(in editor: NSTextView, backwards: Bool) {
    let baseDirectory =
      committedText.isEmpty
      ? nil
      : URL(filePath: committedText, directoryHint: .isDirectory)
    completionController.complete(
      editor: editor,
      relativeTo: baseDirectory,
      backwards: backwards
    ) { [weak self] in
      self?.playErrorSoundIfEnabled()
    }
  }

  private func setHealthy(_ healthy: Bool) {
    textField.textColor = healthy ? .unemphasizedSelectedTextColor : .systemOrange
  }

  private var isSafeShiftReturn: Bool {
    guard let event = NSApp.currentEvent, event.type == .keyDown else {
      return false
    }
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    return modifiers.contains(.shift)
      && modifiers.isDisjoint(with: [.command, .control, .option])
  }

  private func playErrorSoundIfEnabled() {
    if playsErrorSound {
      NSSound.beep()
    }
  }

  private func setFolderIcon(for path: URL?) {
    let sourceImage =
      path.map { NSWorkspace.shared.icon(forFile: $0.path) }
      ?? NSWorkspace.shared.icon(for: .folder)
    let image = sourceImage.copy() as? NSImage ?? sourceImage
    image.isTemplate = false
    iconView.contentTintColor = nil
    iconView.image = image
  }
}
