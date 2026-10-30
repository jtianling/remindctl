import Foundation

public struct ReminderMetadataUpdate: Sendable {
  public let isFlagged: Bool?
  public let addTags: [String]
  public let removeTags: [String]
  public let renameTag: String?
  public let toTag: String?

  public var isEmpty: Bool {
    isFlagged == nil && addTags.isEmpty && removeTags.isEmpty && renameTag == nil
  }

  public init(
    isFlagged: Bool? = nil,
    addTags: [String] = [],
    removeTags: [String] = [],
    renameTag: String? = nil,
    toTag: String? = nil
  ) throws {
    guard (renameTag == nil) == (toTag == nil) else {
      throw RemindCoreError.operationFailed(
        "Use --rename-tag and --to-tag together")
    }
    let adding = try addTags.map(Self.validatedTag)
    let removing = try removeTags.map(Self.validatedTag)
    let oldName = try renameTag.map(Self.validatedTag)
    let newName = try toTag.map(Self.validatedTag)
    guard !Self.overlap(adding, removing) else {
      throw RemindCoreError.operationFailed("Cannot add and remove the same tag")
    }
    let renamed = [oldName, newName].compactMap { $0 }
    guard !Self.overlap(renamed, adding + removing) else {
      throw RemindCoreError.operationFailed(
        "Rename tags separately from adding or removing the same names")
    }
    self.isFlagged = isFlagged
    self.addTags = adding
    self.removeTags = removing
    self.renameTag = oldName
    self.toTag = newName
  }

  private static func overlap(_ lhs: [String], _ rhs: [String]) -> Bool {
    lhs.contains { first in
      rhs.contains { first.compare($0, options: .caseInsensitive) == .orderedSame }
    }
  }

  private static func validatedTag(_ input: String) throws -> String {
    let name = input.hasPrefix("#") ? String(input.dropFirst()) : input
    let forbidden = CharacterSet.whitespacesAndNewlines
      .union(.controlCharacters).union(CharacterSet(charactersIn: "#"))
    guard !name.isEmpty, name.rangeOfCharacter(from: forbidden) == nil else {
      throw RemindCoreError.operationFailed(
        "Invalid tag name: use a non-empty name without spaces or #")
    }
    return name
  }
}
