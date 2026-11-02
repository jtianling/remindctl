import Foundation
import Testing

@testable import remindctl

struct AttachmentsCommandTests {
  @Test("Attachment command resolves one target and optional export directory")
  func arguments() throws {
    let invocation = try CommandRouter().program.resolve(arguments: [
      "remindctl", "attachments", "ABCD", "--output", "./files", "--json",
    ])
    #expect(invocation.path.last == "attachments")
    #expect(invocation.parsedValues.argument(0) == "ABCD")
    #expect(invocation.parsedValues.option("output") == "./files")
    #expect(invocation.parsedValues.flag("jsonOutput"))
    #expect(throws: Error.self) {
      try CommandRouter().program.resolve(arguments: ["remindctl", "attachments"])
    }
    #expect(throws: Error.self) {
      try CommandRouter().program.resolve(arguments: ["remindctl", "attachments", "one", "two"])
    }
  }

  @Test("Output paths preserve spaces, expand tilde and reject empty input")
  func outputPath() throws {
    #expect(try AttachmentsCommand.outputDirectory(nil) == nil)
    #expect(
      try AttachmentsCommand.outputDirectory("~/attachment files")?.path
        == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("attachment files").path)
    #expect(throws: Error.self) { try AttachmentsCommand.outputDirectory("") }
    #expect(throws: Error.self) { try AttachmentsCommand.outputDirectory("   ") }
  }
}
