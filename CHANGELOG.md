# Changelog

All notable changes to Pathsta are documented here.

## [Unreleased]

## [1.0.1] - 2026-09-19

### Added

- Added secure, user-initiated updates from signed GitHub releases.

### Changed

- Reduced idle Finder polling and made path completion asynchronous, cancellable, and capped.
- Set the app minimum to macOS 27 and documented its sandboxing tradeoff.

### Security

- Limited release credentials to the signing and notarization steps that use them.
- Prevented folder creation from being redirected by parent-path replacement races.

## [1.0.0] - 2026-09-17

### Added

- An editable path field attached to Finder's native path bar.
- Live synchronization with the active Finder window.
- Tab completion for folders and symbolic links.
- Optional Shift-Return folder creation and not-found sound feedback.
