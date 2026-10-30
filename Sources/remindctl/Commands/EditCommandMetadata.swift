import Commander
import RemindCore

enum EditCommandMetadata {
  static let options: [OptionDefinition] = [
    .make(
      label: "addTag", names: [.long("add-tag")],
      help: "Add a native tag (repeatable)", parsing: .singleValue),
    .make(
      label: "removeTag", names: [.long("remove-tag")],
      help: "Remove a native tag from this reminder (repeatable)",
      parsing: .singleValue),
    .make(
      label: "renameTag", names: [.long("rename-tag")],
      help: "Rename a tag on this reminder; requires --to-tag", parsing: .singleValue),
    .make(
      label: "toTag", names: [.long("to-tag")],
      help: "New name for --rename-tag", parsing: .singleValue),
  ]

  static let flags: [FlagDefinition] = [
    .make(label: "flag", names: [.long("flag")], help: "Flag this reminder"),
    .make(label: "unflag", names: [.long("unflag")], help: "Remove the flag"),
  ]

  static func parse(_ values: ParsedValues) throws -> ReminderMetadataUpdate {
    let flag = values.flag("flag")
    let unflag = values.flag("unflag")
    guard !(flag && unflag) else {
      throw RemindCoreError.operationFailed(
        "Use either --flag or --unflag, not both")
    }
    for label in ["renameTag", "toTag"] {
      guard (values.options[label]?.count ?? 0) <= 1 else {
        throw RemindCoreError.operationFailed(
          "Only one tag rename is allowed per edit")
      }
    }
    return try ReminderMetadataUpdate(
      isFlagged: flag ? true : (unflag ? false : nil),
      addTags: values.options["addTag"] ?? [],
      removeTags: values.options["removeTag"] ?? [],
      renameTag: values.option("renameTag"),
      toTag: values.option("toTag")
    )
  }
}
