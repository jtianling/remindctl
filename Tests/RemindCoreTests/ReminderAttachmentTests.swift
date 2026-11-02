import Foundation
import Testing

@testable import RemindCore

struct ReminderAttachmentTests {
  private let reminderID = "0B17F239-E2F5-4796-903C-DA81229415D3"
  private let attachmentID = "89E5F496-F749-467A-862C-0C3384712B3D"

  private func attachment(
    source: URL?, id: String? = nil, kind: String = "file",
    size: UInt64 = 5
  ) throws -> ReminderAttachment {
    try ReminderAttachment(
      id: id ?? attachmentID, reminderID: reminderID, kind: kind,
      contentType: "public.plain-text", byteCount: size, sourceURL: source)
  }

  @Test("Native metadata rejects invalid identifiers, kinds and remote URLs")
  func invalidMetadata() throws {
    #expect(throws: Error.self) { try attachment(source: nil, id: "../file") }
    #expect(throws: Error.self) { try attachment(source: nil, kind: "unexpected") }
    #expect(throws: Error.self) {
      try attachment(source: URL(string: "https://example.com/file"))
    }
  }

  @Test("Unavailable attachments retain metadata and explain the missing file")
  func unavailable() throws {
    let missing = try attachment(source: nil)
    #expect(!missing.isAvailable)
    #expect(missing.unavailableReason?.contains("download") == true)
    let absent = try attachment(source: URL(fileURLWithPath: "/missing/" + UUID().uuidString))
    #expect(!absent.isAvailable)
    #expect(absent.unavailableReason?.contains("unavailable") == true)
    let object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(missing)) as? [String: Any])
    #expect(object["sourceURL"] == nil)
    #expect(object["id"] as? String == attachmentID)
    #expect(object["isAvailable"] as? Bool == false)
  }

  @Test(
    "File and image exports preserve bytes and leave their source unchanged",
    arguments: ["file", "image"])
  func exportBytes(kind: String) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.txt")
    let data = Data("hello".utf8)
    try data.write(to: source)
    let item = try attachment(source: source, kind: kind)
    #expect(item.isAvailable)
    let result = try ReminderAttachmentExport.export([item], to: root.appendingPathComponent("out"))
    let path = try #require(result.first?.exportedPath)
    #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == data)
    #expect(try Data(contentsOf: source) == data)
    #expect(result.first?.filename == attachmentID + ".txt")
    #expect(throws: Error.self) {
      try ReminderAttachmentExport.export([item], to: root.appendingPathComponent("out"))
    }
    #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == data)
  }

  @Test("Validation rejects unavailable, duplicate and mismatched sources before copying")
  func exportValidation() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.txt")
    try Data("hello".utf8).write(to: source)
    let item = try attachment(source: source)
    let missing = try attachment(source: nil, id: UUID().uuidString)
    let mismatched = try attachment(source: source, size: 10)
    #expect(!mismatched.isAvailable)
    let output = root.appendingPathComponent("out")
    for items in [[item, missing], [item, item], [mismatched]] {
      #expect(throws: Error.self) { try ReminderAttachmentExport.export(items, to: output) }
      #expect(!FileManager.default.fileExists(atPath: output.path))
    }
    #expect(try !attachment(source: root).isAvailable)
  }

  @Test("Existing broken symlinks cannot be overwritten by exports")
  func brokenSymlink() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.txt")
    try Data("hello".utf8).write(to: source)
    let item = try attachment(source: source)
    let destination = root.appendingPathComponent(item.filename)
    try FileManager.default.createSymbolicLink(
      at: destination, withDestinationURL: root.appendingPathComponent("missing"))
    #expect(throws: Error.self) { try ReminderAttachmentExport.export([item], to: root) }
    #expect(
      try FileManager.default.destinationOfSymbolicLink(atPath: destination.path)
        == root.appendingPathComponent("missing").path)
  }

  @Test("Empty attachment export creates no directory; managed and remote paths are rejected")
  func outputPaths() throws {
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    #expect(try ReminderAttachmentExport.export([], to: output).isEmpty)
    #expect(!FileManager.default.fileExists(atPath: output.path))
    let managed = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Group Containers/group.com.apple.reminders/test")
    #expect(throws: Error.self) { try ReminderAttachmentExport.export([], to: managed) }
    let remote = try #require(URL(string: "https://example.com/output"))
    #expect(throws: Error.self) { try ReminderAttachmentExport.export([], to: remote) }
  }

  @Test("New output subdirectories resolve symlinked parents before protection checks")
  func symlinkedParent() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let link = root.appendingPathComponent("alias")
    let home = FileManager.default.homeDirectoryForCurrentUser
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: home)
    let path = "Library/Group Containers/group.com.apple.reminders/missing-" + UUID().uuidString
    #expect(throws: Error.self) {
      try ReminderAttachmentExport.export([], to: link.appendingPathComponent(path))
    }
    #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(path).path))
    let resolved = try ReminderAttachmentExport.resolvedDirectory(link.appendingPathComponent("new/export"))
    #expect(resolved.path == home.resolvingSymlinksInPath().appendingPathComponent("new/export").path)
  }
}
