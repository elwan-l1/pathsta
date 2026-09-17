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
    if CommandLine.arguments.contains("--probe") {
      probeFinder()
      return true
    }

    guard
      let argumentIndex = CommandLine.arguments.firstIndex(of: "--navigate"),
      CommandLine.arguments.indices.contains(argumentIndex + 1)
    else {
      return false
    }
    navigateFinder(to: CommandLine.arguments[argumentIndex + 1])
    return true
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
      case .success:
        print(directory.path)
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
