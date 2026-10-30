import Foundation
import ReminderKitBridge

public struct ReminderMetadata: Sendable, Equatable {
  public let isFlagged: Bool
  public let tags: [String]
}

extension RemindersStore {
  public func nativeMetadata(id: String) throws -> ReminderMetadata {
    let result = try RCReminderMetadataStore.readReminder(id)
    return ReminderMetadata(isFlagged: result.flagged, tags: result.tags)
  }

  public func updateNativeMetadata(
    id: String, update: ReminderMetadataUpdate
  ) throws -> ReminderItem {
    let result = try RCReminderMetadataStore.updateReminder(
      id,
      flagged: update.isFlagged.map { NSNumber(value: $0) },
      addTags: update.addTags,
      removeTags: update.removeTags,
      renameTag: update.renameTag,
      toTag: update.toTag
    )
    let metadata = ReminderMetadata(isFlagged: result.flagged, tags: result.tags)
    do {
      return try refreshedReminder(id: id).withMetadata(metadata)
    } catch {
      throw RemindCoreError.operationFailed(
        "Native metadata was saved, but refreshing the reminder failed: "
          + error.localizedDescription
          + ". Inspect info --native before retrying a tag rename.")
    }
  }
}

extension ReminderItem {
  public func withMetadata(_ metadata: ReminderMetadata) -> ReminderItem {
    ReminderItem(
      id: id,
      title: title,
      notes: notes,
      url: url,
      isCompleted: isCompleted,
      completionDate: completionDate,
      creationDate: creationDate,
      lastModifiedDate: lastModifiedDate,
      priority: priority,
      dueDate: dueDate,
      dueDateIsAllDay: dueDateIsAllDay,
      alarmDate: alarmDate,
      recurrenceRule: recurrenceRule,
      locationTrigger: locationTrigger,
      listID: listID,
      listName: listName,
      isFlagged: metadata.isFlagged,
      tags: metadata.tags
    )
  }
}
