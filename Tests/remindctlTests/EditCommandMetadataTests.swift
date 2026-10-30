import Commander
import Testing

@testable import remindctl

struct EditCommandMetadataTests {
  private func parse(_ arguments: [String]) throws -> ParsedValues {
    try CommandRouter().program.resolve(
      arguments: ["remindctl", "edit", "test-id"] + arguments
    ).parsedValues
  }

  @Test("Repeated native tag options retain every value")
  func repeatedTags() throws {
    let values = try parse([
      "--flag", "--add-tag", "#工作", "--add-tag", "project",
      "--remove-tag", "old", "--remove-tag", "unused",
    ])
    let update = try EditCommandMetadata.parse(values)
    #expect(update.isFlagged == true)
    #expect(update.addTags == ["工作", "project"])
    #expect(update.removeTags == ["old", "unused"])
  }

  @Test("Flag removal and single-reminder tag rename can be combined")
  func renameAndUnflag() throws {
    let values = try parse([
      "--unflag", "--rename-tag", "#old", "--to-tag", "new",
    ])
    let update = try EditCommandMetadata.parse(values)
    #expect(update.isFlagged == false)
    #expect(update.renameTag == "old")
    #expect(update.toTag == "new")
  }

  @Test(
    "Contradictory flags and ambiguous renames are rejected",
    arguments: [
      ["--flag", "--unflag"],
      ["--rename-tag", "old"],
      ["--to-tag", "new"],
      ["--rename-tag", "one", "--rename-tag", "two", "--to-tag", "new"],
      ["--rename-tag", "old", "--to-tag", "one", "--to-tag", "two"],
    ])
  func invalidOptions(_ arguments: [String]) throws {
    let values = try parse(arguments)
    #expect(throws: Error.self) { try EditCommandMetadata.parse(values) }
  }

  @Test("Info exposes an explicit native metadata read")
  func nativeInfo() throws {
    let invocation = try CommandRouter().program.resolve(
      arguments: ["remindctl", "info", "test-id", "--native", "--json"])
    #expect(invocation.parsedValues.flags.contains("native"))
  }
}
