import Foundation
import ReminderKitBridge

extension RemindersStore {
  public func attachments(id: String) throws -> [ReminderAttachment] {
    let attachments = try RCReminderAttachmentStore.readAttachments(id)
    let items = try attachments.map {
      try ReminderAttachment(
        id: $0.identifier, reminderID: id, kind: $0.kind,
        contentType: $0.contentType, byteCount: $0.byteCount, sourceURL: $0.fileURL)
    }
    guard Set(items.map(\.id)).count == items.count else {
      throw RemindCoreError.operationFailed("Duplicate native attachment identifiers")
    }
    return items.sorted { $0.id < $1.id }
  }
}

public enum ReminderAttachmentExport {
  public static func export(
    _ attachments: [ReminderAttachment], to directory: URL
  ) throws -> [ReminderAttachment] {
    guard directory.isFileURL else {
      throw RemindCoreError.operationFailed("Attachment output must be a local directory")
    }
    let target = try resolvedDirectory(directory)
    let protected = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Group Containers/group.com.apple.reminders")
      .resolvingSymlinksInPath().path
    guard target.path != protected, !target.path.hasPrefix(protected + "/") else {
      throw RemindCoreError.operationFailed("Cannot export into the Reminders data directory")
    }
    try validate(attachments, directory: target)
    guard !attachments.isEmpty else { return [] }
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    return try attachments.map { attachment in
      let destination = target.appendingPathComponent(attachment.filename)
      guard let source = attachment.sourceURL else {
        throw RemindCoreError.operationFailed("Missing source for \(attachment.id)")
      }
      do {
        try FileManager.default.copyItem(at: source, to: destination)
      } catch {
        throw RemindCoreError.operationFailed(
          "Unable to export attachment \(attachment.id): \(error.localizedDescription). "
            + "Files already copied to \(target.path) are retained.")
      }
      return try ReminderAttachment(
        id: attachment.id, reminderID: attachment.reminderID,
        kind: attachment.kind.rawValue, contentType: attachment.contentType,
        byteCount: attachment.byteCount, sourceURL: source,
        exportedPath: destination.path)
    }
  }

  static func resolvedDirectory(_ directory: URL) throws -> URL {
    var ancestor = directory.standardizedFileURL
    var missing: [String] = []
    var isDirectory: ObjCBool = false
    while !FileManager.default.fileExists(atPath: ancestor.path, isDirectory: &isDirectory) {
      if (try? FileManager.default.destinationOfSymbolicLink(atPath: ancestor.path)) != nil {
        throw RemindCoreError.operationFailed("Output directory contains a broken symbolic link")
      }
      missing.append(ancestor.lastPathComponent)
      let parent = ancestor.deletingLastPathComponent()
      guard parent.path != ancestor.path else {
        throw RemindCoreError.operationFailed("Unable to resolve output directory")
      }
      ancestor = parent
    }
    guard isDirectory.boolValue else {
      throw RemindCoreError.operationFailed("Attachment output must be a directory")
    }
    return missing.reversed().reduce(ancestor.resolvingSymlinksInPath()) {
      $0.appendingPathComponent($1, isDirectory: true)
    }
  }

  private static func validate(
    _ attachments: [ReminderAttachment], directory: URL
  ) throws {
    guard Set(attachments.map(\.filename)).count == attachments.count else {
      throw RemindCoreError.operationFailed("Duplicate attachment export filenames")
    }
    for attachment in attachments {
      guard attachment.isAvailable else {
        throw RemindCoreError.operationFailed(
          "Cannot export attachment \(attachment.id): "
            + (attachment.unavailableReason ?? "Local file is unavailable"))
      }
      let destination = directory.appendingPathComponent(attachment.filename)
      if (try? destination.checkResourceIsReachable()) == true
        || (try? FileManager.default.destinationOfSymbolicLink(
          atPath: destination.path)) != nil
      {
        throw RemindCoreError.operationFailed(
          "Refusing to overwrite existing attachment export: \(destination.path)")
      }
    }
  }
}
