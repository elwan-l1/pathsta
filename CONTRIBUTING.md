# Contributing to Pathsta

Thanks for helping improve Pathsta. Issues and pull requests are welcome, especially compatibility fixes for other macOS versions.

## Reporting bugs and requesting features

Open an [issue](https://github.com/elwan-l1/pathsta/issues/new/choose) and pick the matching template. For security vulnerabilities, follow the [security policy](SECURITY.md) instead of opening a public issue.

## Development setup

Building the app requires macOS 27+, Xcode 27+ and Homebrew.

```sh
make bootstrap
make open
```

The Xcode project is generated from `project.yml` with XcodeGen, so edit `project.yml` rather than the project file by hand.

## Before opening a pull request

Run the full check, which runs formatting, linting and both test suites:

```sh
make verify
```

Use `make format` to fix formatting issues.

- Keep changes focused. One pull request should do one thing.
- Add or update tests for behavior changes.
- Update `CHANGELOG.md` and the README when user-visible behavior changes.
- Write short, imperative commit messages that start with a gitmoji, for example `✨ Add path history`.

## Releases

Releases are cut by the maintainer. See [RELEASING.md](RELEASING.md).

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.
