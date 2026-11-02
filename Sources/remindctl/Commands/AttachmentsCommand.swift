import Commander
import Foundation
import RemindCore

enum AttachmentsCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "attachments",
      abstract: "List or export a reminder's image and file attachments",
      discussion: "Uses system ReminderKit. Exports locally available files without overwriting files.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "id", help: "Index or ID prefix", isOptional: false)
          ],
          options: [
            .make(
              label: "output", names: [.short("o"), .long("output")],
              help: "Copy all attachments into this directory", parsing: .singleValue)
          ])),
      usageExamples: [
        "remindctl attachments 4A83 --json",
        "remindctl attachments 4A83 --output ./attachments --json",
      ]
    ) { values, runtime in
      guard let input = values.argument(0) else {
        throw ParsedValuesError.missingArgument("id")
      }
      let output = try outputDirectory(values.option("output"))
      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try CommandHelpers.resolveShowIdentifiers([input], from: reminders)
      guard let reminder = resolved.first else {
        throw RemindCoreError.reminderNotFound(input)
      }
      let attachments = try await store.attachments(id: reminder.id)
      let result =
        try output.map {
          try ReminderAttachmentExport.export(attachments, to: $0)
        } ?? attachments
      OutputRenderer.printAttachments(result, format: runtime.outputFormat)
    }
  }

  static func outputDirectory(_ value: String?) throws -> URL? {
    guard let value else { return nil }
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw RemindCoreError.operationFailed("Attachment output directory cannot be empty")
    }
    return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
  }
}
