import Commander
import Foundation
import RemindCore

enum InfoCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "info",
      abstract: "Show reminder details",
      discussion: "Use an index from the default show view or an ID prefix.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "id", help: "Index or ID prefix", isOptional: false)
          ],
          flags: [
            .make(
              label: "native", names: [.long("native")],
              help: "Include native flag and tags using system ReminderKit")
          ]
        )
      ),
      usageExamples: [
        "remindctl info 1",
        "remindctl info 4A83",
        "remindctl info 4A83 --json",
        "remindctl info 4A83 --native --json",
      ]
    ) { values, runtime in
      guard let input = values.argument(0) else {
        throw ParsedValuesError.missingArgument("id")
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try CommandHelpers.resolveShowIdentifiers([input], from: reminders)
      guard let reminder = resolved.first else {
        throw RemindCoreError.reminderNotFound(input)
      }

      let detailed =
        if values.flag("native") {
          try await reminder.withMetadata(store.nativeMetadata(id: reminder.id))
        } else {
          reminder
        }
      OutputRenderer.printReminderDetail(detailed, format: runtime.outputFormat)
    }
  }
}
