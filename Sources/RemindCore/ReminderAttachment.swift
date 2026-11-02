import Foundation
import UniformTypeIdentifiers

public struct ReminderAttachment: Encodable, Sendable, Equatable, Identifiable {
  public enum Kind: String, Encodable, Sendable {
    case image
    case file
  }

  public let id: String
  public let reminderID: String
  public let kind: Kind
  public let contentType: String
  public let byteCount: UInt64
  public let filename: String
  public let isAvailable: Bool
  public let unavailableReason: String?
  public let exportedPath: String?
  let sourceURL: URL?

  enum CodingKeys: String, CodingKey {
    case id, reminderID, kind, contentType, byteCount, filename
    case isAvailable, unavailableReason, exportedPath
  }

  init(
    id: String, reminderID: String, kind: String, contentType: String,
    byteCount: UInt64, sourceURL: URL?, exportedPath: String? = nil
  ) throws {
    guard let uuid = UUID(uuidString: id), UUID(uuidString: reminderID) != nil,
      let kind = Kind(rawValue: kind), !contentType.isEmpty,
      sourceURL == nil || sourceURL?.isFileURL == true
    else {
      throw RemindCoreError.operationFailed("Invalid native attachment metadata")
    }
    self.id = uuid.uuidString
    self.reminderID = reminderID
    self.kind = kind
    self.contentType = contentType
    self.byteCount = byteCount
    self.sourceURL = sourceURL
    self.exportedPath = exportedPath
    let ext = UTType(contentType)?.preferredFilenameExtension ?? "bin"
    let safeExtension =
      ext.unicodeScalars.allSatisfy {
        CharacterSet.alphanumerics.contains($0)
      } && !ext.isEmpty
    filename = "\(uuid.uuidString).\(safeExtension ? ext : "bin")"
    unavailableReason = Self.availabilityError(sourceURL, byteCount: byteCount)
    isAvailable = unavailableReason == nil
  }

  private static func availabilityError(_ url: URL?, byteCount: UInt64) -> String? {
    guard let url else {
      return "Attachment has no local file; download it in Reminders.app first"
    }
    do {
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard values.isRegularFile == true else { return "Attachment is not a regular file" }
      guard FileManager.default.isReadableFile(atPath: url.path) else {
        return "Attachment file is not readable: \(url.path)"
      }
      guard let size = values.fileSize, size >= 0, UInt64(size) == byteCount else {
        return "Attachment file size does not match native metadata"
      }
      return nil
    } catch {
      return "Attachment file is unavailable: \(error.localizedDescription)"
    }
  }
}
