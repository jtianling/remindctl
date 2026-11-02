import Foundation
import Testing

@testable import RemindCore

struct ReminderAttachmentDiscoveryTests {
  private func reminder(_ id: String) -> ReminderItem {
    ReminderItem(
      id: id, title: "Title", notes: "Notes", isCompleted: false,
      completionDate: nil, lastModifiedDate: Date(timeIntervalSince1970: 100),
      priority: .high, dueDate: nil, listID: "list", listName: "List",
      isFlagged: true, tags: ["work"])
  }

  @Test("Default discovery maps zero and multiple attachments without losing metadata")
  func counts() throws {
    let originals = [reminder("one"), reminder("two")]
    var calls = 0
    let items = ReminderAttachmentDiscovery.enrich(originals) { identifiers in
      calls += 1
      #expect(identifiers == ["one", "two"])
      return ["two": .available(2), "one": .available(0)]
    } log: { _ in
      Issue.record("Unexpected warning")
    }
    #expect(calls == 1)
    #expect(items.map(\.attachmentCount) == [0, 2])
    for (item, original) in zip(items, originals) {
      #expect(item.id == original.id)
      #expect(item.notes == original.notes)
      #expect(item.lastModifiedDate == original.lastModifiedDate)
      #expect(item.tags == original.tags)
      #expect(item.isFlagged == original.isFlagged)
      #expect(item.attachmentError == nil)
    }
    let data = try JSONEncoder().encode(items)
    #expect(try JSONDecoder().decode([ReminderItem].self, from: data) == items)
    let updated = items[1].withMetadata(ReminderMetadata(isFlagged: false, tags: []))
    #expect(updated.attachmentCount == 2)
  }

  @Test("Partial failures and missing results are unknown rather than zero")
  func partialFailure() throws {
    var warnings: [String] = []
    let items = ReminderAttachmentDiscovery.enrich(
      [reminder("ok"), reminder("denied"), reminder("missing")],
      load: { _ in ["ok": .available(0), "denied": .unavailable("Access denied")] },
      log: { warnings.append($0) })
    #expect(items.count == 3)
    #expect(items[0].attachmentCount == 0)
    #expect(items[1].attachmentCount == nil)
    #expect(items[1].attachmentError == "Access denied")
    #expect(items[2].attachmentCount == nil)
    #expect(items[2].attachmentError == "No native attachment summary returned")
    #expect(warnings.count == 2)
    #expect(warnings[0].contains("denied: Access denied"))
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(items[1])) as? [String: Any])
    #expect(object["attachmentCount"] == nil)
    #expect(object["attachmentError"] as? String == "Access denied")
    let updated = items[1].withMetadata(ReminderMetadata(isFlagged: false, tags: []))
    #expect(updated.attachmentError == "Access denied")
  }

  @Test("Backend failure retains every reminder and logs the actual reason once")
  func backendFailure() {
    var warnings: [String] = []
    let items = ReminderAttachmentDiscovery.enrich(
      [reminder("one"), reminder("two")],
      load: { _ in throw RemindCoreError.operationFailed("ReminderKit interface missing") },
      log: { warnings.append($0) })
    #expect(items.map(\.attachmentCount) == [nil, nil])
    #expect(items.allSatisfy { $0.attachmentError == "ReminderKit interface missing" })
    #expect(warnings.count == 1)
    #expect(warnings[0].contains("ReminderKit interface missing"))
  }

  @Test("Empty listings never contact the private backend")
  func empty() async {
    let result = await ReminderAttachmentDiscovery.discover([]) { _ in
      Issue.record("Empty discovery must not query ReminderKit")
      return [:]
    }
    #expect(result.isEmpty)
  }

  @Test("Slow native discovery times out and still returns reminder details")
  func timeout() async {
    let result = await ReminderAttachmentDiscovery.discover(
      [reminder("slow")], after: .milliseconds(10)
    ) { _ in
      Thread.sleep(forTimeInterval: 0.2)
      return ["slow": .available(1)]
    }
    #expect(result.count == 1)
    #expect(result[0].id == "slow")
    #expect(result[0].attachmentCount == nil)
    #expect(result[0].attachmentError == "Timed out reading native attachment counts")
  }

  @Test("Older reminder JSON remains decodable without attachment discovery fields")
  func legacyJSON() throws {
    let item = reminder("legacy")
    let decoded = try JSONDecoder().decode(
      ReminderItem.self, from: JSONEncoder().encode(item))
    #expect(decoded.attachmentCount == nil)
    #expect(decoded.attachmentError == nil)
  }
}
