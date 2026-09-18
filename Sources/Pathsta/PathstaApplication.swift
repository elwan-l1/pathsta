import AppKit
import PathstaCore

@main
enum PathstaApplication {
  @MainActor
  static func main() {
    if runCommandLineActionIfRequested() {
      return
    }

    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
  }

  @MainActor
  private static func runCommandLineActionIfRequested() -> Bool {
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      return false
    }
    switch PathstaCommandLine.parse(Array(CommandLine.arguments.dropFirst())) {
    case .runApplication:
      return false
    case .probeFinder:
      probeFinder()
      return true
    case .navigate(let path):
      navigateFinder(to: path)
      return true
    case .help:
      print(PathstaCommandLine.usage)
      return true
    case .invalid(let message):
      writeStandardError("\(message)\n\n\(PathstaCommandLine.usage)")
      exit(EXIT_FAILURE)
    }
  }

  @MainActor
  private static func probeFinder() {
    switch FinderBridge().currentDirectory() {
    case .success(let directory):
      print(directory.path)
    case .failure(let error):
      writeStandardError("Pathsta probe failed: \(error.localizedDescription)")
      exit(EXIT_FAILURE)
    }
  }

  @MainActor
  private static func navigateFinder(to input: String) {
    switch PathResolver.resolve(input, relativeTo: nil) {
    case .failure(let error):
      writeStandardError("Invalid path: \(error.localizedDescription)")
      exit(EXIT_FAILURE)
    case .success(let directory):
      switch FinderBridge().navigate(to: directory) {
      case .success(let navigatedDirectory):
        print(navigatedDirectory.path)
      case .failure(let error):
        writeStandardError("Navigation failed: \(error.localizedDescription)")
        exit(EXIT_FAILURE)
      }
    }
  }

  private static func writeStandardError(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
  }
}
