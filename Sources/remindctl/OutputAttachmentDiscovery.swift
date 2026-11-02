import RemindCore

extension OutputRenderer {
  static func attachmentCountText(_ reminder: ReminderItem) -> String {
    reminder.attachmentCount.map(String.init) ?? "unknown"
  }

  static func attachmentSuffix(_ reminder: ReminderItem) -> String {
    if reminder.attachmentCount == 0 { return "" }
    return " attachments=\(attachmentCountText(reminder))"
  }

  static func attachmentDetail(_ reminder: ReminderItem) -> String {
    let count = attachmentCountText(reminder)
    if let failure = reminder.attachmentError {
      return "Attachments: \(count) (\(failure))"
    }
    if let count = reminder.attachmentCount, count > 0 {
      return "Attachments: \(count) (remindctl attachments \(reminder.id))"
    }
    return "Attachments: \(count)"
  }
}
