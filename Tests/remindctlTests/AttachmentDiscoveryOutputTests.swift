import RemindCore
import Testing

@testable import remindctl

struct AttachmentDiscoveryOutputTests {
  private func reminder(count: Int?, error: String? = nil) -> ReminderItem {
    ReminderItem(
      id: "ABCD", title: "Title", notes: nil, isCompleted: false,
      completionDate: nil, priority: .none, dueDate: nil,
      listID: "list", listName: "List", attachmentCount: count,
      attachmentError: error)
  }

  @Test("Normal listings indicate attachments and details provide the next command")
  func positiveCount() {
    let item = reminder(count: 2)
    #expect(OutputRenderer.attachmentSuffix(item) == " attachments=2")
    #expect(OutputRenderer.attachmentCountText(item) == "2")
    #expect(
      OutputRenderer.attachmentDetail(item)
        == "Attachments: 2 (remindctl attachments ABCD)")
  }

  @Test("Known zero remains distinct from unavailable attachment information")
  func zeroAndUnknown() {
    let empty = reminder(count: 0)
    #expect(OutputRenderer.attachmentSuffix(empty).isEmpty)
    #expect(OutputRenderer.attachmentDetail(empty) == "Attachments: 0")
    let unknown = reminder(count: nil, error: "Access denied")
    #expect(OutputRenderer.attachmentSuffix(unknown) == " attachments=unknown")
    #expect(OutputRenderer.attachmentCountText(unknown) == "unknown")
    #expect(
      OutputRenderer.attachmentDetail(unknown)
        == "Attachments: unknown (Access denied)")
  }
}
