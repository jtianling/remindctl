import Foundation
import RemindCore

extension OutputRenderer {
  static func printAttachments(_ attachments: [ReminderAttachment], format: OutputFormat) {
    switch format {
    case .json:
      printJSON(attachments)
    case .quiet:
      Swift.print(attachments.count)
    case .plain:
      for item in attachments {
        Swift.print(
          [
            item.id, item.kind.rawValue, item.contentType, String(item.byteCount),
            item.isAvailable ? "available" : "unavailable", item.exportedPath ?? "",
          ].joined(separator: "\t"))
      }
    case .standard, .table:
      guard !attachments.isEmpty else {
        Swift.print("No image or file attachments found")
        return
      }
      for item in attachments {
        let status = item.exportedPath ?? item.unavailableReason ?? "available"
        Swift.print("\(item.filename) [\(item.kind.rawValue)] \(item.byteCount) bytes — \(status)")
      }
    }
  }
}
