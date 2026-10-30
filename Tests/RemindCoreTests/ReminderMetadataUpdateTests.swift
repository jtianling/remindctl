import Foundation
import Testing

@testable import RemindCore

struct ReminderMetadataUpdateTests {
  @Test("Native metadata preserves unset flags and normalizes tag prefixes")
  func normalization() throws {
    let update = try ReminderMetadataUpdate(
      addTags: ["#工作", "project-one"], removeTags: ["#旧标签"],
      renameTag: "#before", toTag: "#after")
    #expect(update.isFlagged == nil)
    #expect(update.addTags == ["工作", "project-one"])
    #expect(update.removeTags == ["旧标签"])
    #expect(update.renameTag == "before")
    #expect(update.toTag == "after")
    #expect(!update.isEmpty)
    #expect(try ReminderMetadataUpdate().isEmpty)
    #expect(try !ReminderMetadataUpdate(isFlagged: false).isEmpty)
  }

  @Test(
    "Invalid tags fail schema validation",
    arguments: [
      "", "#", "##work", "two words", " work", "work\n", "a\u{0}b", "a#b",
    ])
  func invalidTags(_ name: String) {
    #expect(throws: Error.self) { try ReminderMetadataUpdate(addTags: [name]) }
    #expect(throws: Error.self) { try ReminderMetadataUpdate(removeTags: [name]) }
    #expect(throws: Error.self) {
      try ReminderMetadataUpdate(renameTag: "old", toTag: name)
    }
  }

  @Test("Renames require both old and new names")
  func incompleteRename() {
    #expect(throws: Error.self) { try ReminderMetadataUpdate(renameTag: "old") }
    #expect(throws: Error.self) { try ReminderMetadataUpdate(toTag: "new") }
  }

  @Test("Conflicting tag actions reject case and prefix variations")
  func conflicts() {
    #expect(throws: Error.self) {
      try ReminderMetadataUpdate(addTags: ["#Work"], removeTags: ["work"])
    }
    #expect(throws: Error.self) {
      try ReminderMetadataUpdate(
        addTags: ["NEW"], renameTag: "old", toTag: "new")
    }
    #expect(throws: Error.self) {
      try ReminderMetadataUpdate(
        removeTags: ["OLD"], renameTag: "old", toTag: "new")
    }
  }

  @Test(
    "Conflict checks use the native Unicode comparison",
    arguments: [
      ("ß", "ss"), ("ﬀ", "ff"), ("Å", "å"),
    ])
  func unicodeConflicts(names: (String, String)) {
    #expect(throws: Error.self) {
      try ReminderMetadataUpdate(addTags: [names.0], removeTags: [names.1])
    }
    #expect(throws: Error.self) {
      try ReminderMetadataUpdate(
        addTags: [names.0], renameTag: "old", toTag: names.1)
    }
  }

  @Test("Native metadata enriches reminders without losing EventKit fields")
  func enrichedReminder() throws {
    let item = ReminderItem(
      id: "test", title: "Title", notes: "Notes", url: URL(string: "https://example.com"),
      isCompleted: true, completionDate: Date(timeIntervalSince1970: 100),
      priority: .high, dueDate: Date(timeIntervalSince1970: 200),
      dueDateIsAllDay: true, listID: "list", listName: "List")
    let updated = item.withMetadata(ReminderMetadata(isFlagged: false, tags: []))
    #expect(updated.id == item.id)
    #expect(updated.notes == item.notes)
    #expect(updated.url == item.url)
    #expect(updated.completionDate == item.completionDate)
    #expect(updated.dueDate == item.dueDate)
    #expect(updated.dueDateIsAllDay)
    #expect(updated.priority == .high)
    #expect(updated.isFlagged == false)
    #expect(updated.tags == [])
    let data = try JSONEncoder().encode(updated)
    #expect(try JSONDecoder().decode(ReminderItem.self, from: data) == updated)
    let legacy = try JSONEncoder().encode(item)
    #expect(try JSONDecoder().decode(ReminderItem.self, from: legacy).tags == nil)
  }
}
