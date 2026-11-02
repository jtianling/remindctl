import Foundation
import ReminderKitBridge

enum ReminderAttachmentSummary: Equatable, Sendable {
  case available(Int)
  case unavailable(String)
}

enum ReminderAttachmentDiscovery {
  static func discover(
    _ reminders: [ReminderItem],
    after duration: Duration = RemindersStore.externalOperationTimeout,
    load: @escaping @Sendable ([String]) throws -> [String: ReminderAttachmentSummary] = readCounts
  ) async -> [ReminderItem] {
    guard !reminders.isEmpty else { return [] }
    let identifiers = reminders.map(\.id)
    do {
      let counts: [String: ReminderAttachmentSummary] = try await AsyncTimeout.withTimeout(
        after: duration,
        timeoutError: .operationFailed("Timed out reading native attachment counts")
      ) { completion in
        DispatchQueue.global(qos: .utility).async {
          do {
            completion.resume(returning: try load(identifiers))
          } catch {
            completion.resume(throwing: error)
          }
        }
        return nil
      }
      return enrich(reminders, load: { _ in counts })
    } catch {
      return enrich(reminders, load: { _ in throw error })
    }
  }

  static func enrich(
    _ reminders: [ReminderItem],
    load: ([String]) throws -> [String: ReminderAttachmentSummary] = readCounts,
    log: (String) -> Void = logFailure
  ) -> [ReminderItem] {
    guard !reminders.isEmpty else { return [] }
    let summaries: [String: ReminderAttachmentSummary]
    do {
      summaries = try load(reminders.map(\.id))
    } catch {
      let failure = error.localizedDescription
      log("Unable to read attachment counts: \(failure)")
      return reminders.map { $0.withAttachmentSummary(.unavailable(failure)) }
    }
    return reminders.map { reminder in
      let summary =
        summaries[reminder.id]
        ?? .unavailable("No native attachment summary returned")
      if case .unavailable(let failure) = summary {
        log("Unable to read attachments for \(reminder.id): \(failure)")
      }
      return reminder.withAttachmentSummary(summary)
    }
  }

  private static func readCounts(_ identifiers: [String]) throws
    -> [String: ReminderAttachmentSummary]
  {
    let results = try RCReminderAttachmentDiscovery.readSummaries(identifiers)
    let expected = Set(identifiers)
    var summaries: [String: ReminderAttachmentSummary] = [:]
    for result in results {
      guard expected.contains(result.identifier), summaries[result.identifier] == nil else {
        throw RemindCoreError.operationFailed("Invalid native attachment summary identifiers")
      }
      if let count = result.count, count.intValue >= 0, result.failure == nil {
        summaries[result.identifier] = .available(count.intValue)
      } else if result.count == nil, let failure = result.failure, !failure.isEmpty {
        summaries[result.identifier] = .unavailable(failure)
      } else {
        throw RemindCoreError.operationFailed("Invalid native attachment count or error")
      }
    }
    return summaries
  }

  private static func logFailure(_ message: String) {
    FileHandle.standardError.write(Data(("Warning: " + message + "\n").utf8))
  }
}

extension ReminderItem {
  func withAttachmentSummary(_ summary: ReminderAttachmentSummary) -> ReminderItem {
    let count: Int?
    let failure: String?
    switch summary {
    case .available(let value):
      count = value
      failure = nil
    case .unavailable(let reason):
      count = nil
      failure = reason
    }
    return ReminderItem(
      id: id, title: title, notes: notes, url: url, isCompleted: isCompleted,
      completionDate: completionDate, creationDate: creationDate,
      lastModifiedDate: lastModifiedDate, priority: priority, dueDate: dueDate,
      dueDateIsAllDay: dueDateIsAllDay, alarmDate: alarmDate,
      recurrenceRule: recurrenceRule, locationTrigger: locationTrigger,
      listID: listID, listName: listName, isFlagged: isFlagged, tags: tags,
      attachmentCount: count, attachmentError: failure)
  }
}
