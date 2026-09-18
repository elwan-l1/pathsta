import PathstaCore
import Testing

@Suite("Command-line parsing")
struct PathstaCommandLineTests {
  @Test("Launches normally without arguments")
  func launchesApplication() {
    #expect(PathstaCommandLine.parse([]) == .runApplication)
  }

  @Test("Parses probe and help modes")
  func parsesSimpleModes() {
    #expect(PathstaCommandLine.parse(["--probe"]) == .probeFinder)
    #expect(PathstaCommandLine.parse(["--help"]) == .help)
    #expect(PathstaCommandLine.parse(["-h"]) == .help)
  }

  @Test("Preserves navigate paths containing spaces")
  func parsesNavigatePath() {
    #expect(
      PathstaCommandLine.parse(["--navigate", "/Users/Test/Project Files"])
        == .navigate("/Users/Test/Project Files")
    )
  }

  @Test(
    "Rejects malformed modes",
    arguments: [
      ["--navigate"],
      ["--navigate", ""],
      ["--unknown"],
      ["--probe", "trailing"],
      ["--probe", "--navigate", "/tmp"],
    ]
  )
  func rejectsMalformedArguments(_ arguments: [String]) {
    guard case .invalid = PathstaCommandLine.parse(arguments) else {
      Issue.record("Malformed arguments were accepted: \(arguments)")
      return
    }
  }
}
