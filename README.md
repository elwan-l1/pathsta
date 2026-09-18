<p align="center">
  <img src="docs/assets/readme/pathsta.svg" width="140" alt="Pathsta">
</p>

<h1 align="center">Pathsta</h1>

<p align="center">A simple editable path bar for Finder.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14 or later">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License"></a>
</p>

<p align="center">
  <img src="docs/assets/readme/pathsta.png" width="900" alt="Click Finder's path bar to edit the current path with Pathsta">
</p>

Click Finder's path bar, type or paste a path and press Return. Pathsta follows the active Finder window, supports Tab completion and stays out of the way when you click elsewhere.

> **⚠ Compatibility:** Pathsta has currently been tested only on macOS 27. Finder's interface and accessibility behavior can differ between macOS releases, so older versions may have edge cases or not work yet. Bug reports and contributions are welcome.

## Features

- **Path completion:** Press Tab or Shift-Tab to cycle through matching folders, including symbolic links.
- **Safe folder creation:** Press Shift-Return to create one missing folder and navigate to it. Can be disabled from the menu bar.
- **Not found feedback:** Play a sound when a path cannot be found. Can be disabled from the menu bar.
- **Live synchronization:** The field follows the active Finder window and updates when its location changes.

## Install

Download Pathsta from [Releases](https://github.com/elwan-l1/pathsta/releases).

Open Pathsta and allow Finder automation when macOS asks. Initial releases support Apple silicon.

## Build

Requires macOS 14+, Xcode 27+ and Homebrew.

```sh
make bootstrap
make verify
make open
```

## Contributing

Issues and pull requests are welcome, especially compatibility fixes for other macOS versions. Please run `make verify` before submitting a change.

## License

Pathsta is available under the [MIT License](LICENSE).
