import EventKit
import Foundation

struct AppleCalendarOption: Identifiable, Equatable {
    let id: String
    let title: String
    let sourceTitle: String
    let sourceType: EKSourceType

    var displayName: String {
        if sourceTitle.isEmpty {
            return title
        }
        return "\(title) • \(sourceTitle)"
    }

    var likelySyncsAcrossDevices: Bool {
        switch sourceType {
        case .exchange, .calDAV, .mobileMe:
            return true
        case .local, .subscribed, .birthdays:
            return false
        @unknown default:
            return false
        }
    }
}

struct AppleCalendarConnectionSnapshot {
    let authorizationStatus: EKAuthorizationStatus
    let availableCalendars: [AppleCalendarOption]
    let defaultCalendarIdentifier: String?
}

enum AppleCalendarSyncError: LocalizedError {
    case fullAccessRequired
    case noWritableCalendars
    case targetCalendarMissing
    case sessionStudentMissing
    case accessRequestFailed(String)
    case eventSaveFailed(String)
    case eventDeleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .fullAccessRequired:
            return "TutorTable needs full Apple Calendar access before it can sync sessions."
        case .noWritableCalendars:
            return "No writable Apple Calendar calendars are available on this Mac."
        case .targetCalendarMissing:
            return "TutorTable could not find the selected Apple Calendar."
        case .sessionStudentMissing:
            return "TutorTable could not find the student linked to that session."
        case .accessRequestFailed(let message):
            return "TutorTable could not request Apple Calendar access: \(message)"
        case .eventSaveFailed(let message):
            return "TutorTable could not save the Apple Calendar event: \(message)"
        case .eventDeleteFailed(let message):
            return "TutorTable could not delete the Apple Calendar event: \(message)"
        }
    }
}

final class AppleCalendarSyncManager {
    private let eventStore = EKEventStore()

    func requestFullAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let completion: (Bool, Error?) -> Void = { granted, error in
                if let error {
                    continuation.resume(throwing: AppleCalendarSyncError.accessRequestFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: granted)
                }
            }

            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents(completion: completion)
            } else {
                eventStore.requestAccess(to: .event, completion: completion)
            }
        }
    }

    func connectionSnapshot() -> AppleCalendarConnectionSnapshot {
        let status = authorizationStatus()
        let calendars = hasFullAccess(status: status) ? writableCalendars().map(Self.makeOption) : []
        let defaultIdentifier = hasFullAccess(status: status) ? resolvedDefaultCalendar()?.calendarIdentifier : nil

        return AppleCalendarConnectionSnapshot(
            authorizationStatus: status,
            availableCalendars: calendars,
            defaultCalendarIdentifier: defaultIdentifier
        )
    }

    func sync(session: LessonSession, student: Student, preferredCalendarIdentifier: String?) throws -> LessonSession {
        guard hasFullAccess() else {
            throw AppleCalendarSyncError.fullAccessRequired
        }

        let calendar = try resolvedCalendar(preferredIdentifier: preferredCalendarIdentifier)
        let event = findExistingEvent(for: session, student: student, preferredCalendar: calendar) ?? EKEvent(eventStore: eventStore)

        event.calendar = calendar
        event.title = "\(student.fullName) • \(session.title)"
        event.location = trimmedOrNil(session.location)
        event.startDate = session.startAt
        event.endDate = session.endAt
        event.notes = eventNotes(for: session, student: student)
        event.url = nil
        event.alarms = session.reminderMinutesBefore > 0
            ? [EKAlarm(relativeOffset: -Double(session.reminderMinutesBefore) * 60)]
            : []

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            throw AppleCalendarSyncError.eventSaveFailed(error.localizedDescription)
        }

        var updatedSession = session
        updatedSession.appleCalendarItemIdentifier = event.calendarItemIdentifier
        return updatedSession
    }

    func removeSyncedEvent(for session: LessonSession, student: Student?, preferredCalendarIdentifier: String?) throws {
        guard hasFullAccess() else {
            throw AppleCalendarSyncError.fullAccessRequired
        }

        let preferredCalendar = try? resolvedCalendar(preferredIdentifier: preferredCalendarIdentifier)
        guard let event = findExistingEvent(for: session, student: student, preferredCalendar: preferredCalendar) else {
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            throw AppleCalendarSyncError.eventDeleteFailed(error.localizedDescription)
        }
    }

    func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func hasFullAccess() -> Bool {
        hasFullAccess(status: authorizationStatus())
    }

    private func hasFullAccess(status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    private func writableCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { lhs, rhs in
                if lhs.source.sourceType.isLikelySyncSource != rhs.source.sourceType.isLikelySyncSource {
                    return lhs.source.sourceType.isLikelySyncSource && !rhs.source.sourceType.isLikelySyncSource
                }
                let lhsLabel = "\(lhs.source.title) \(lhs.title)"
                let rhsLabel = "\(rhs.source.title) \(rhs.title)"
                return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
            }
    }

    private func resolvedDefaultCalendar() -> EKCalendar? {
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
           defaultCalendar.allowsContentModifications,
           defaultCalendar.source.sourceType.isLikelySyncSource {
            return defaultCalendar
        }

        let writable = writableCalendars()
        if let syncedCalendar = writable.first(where: { $0.source.sourceType.isLikelySyncSource }) {
            return syncedCalendar
        }

        if let defaultCalendar = eventStore.defaultCalendarForNewEvents, defaultCalendar.allowsContentModifications {
            return defaultCalendar
        }

        return writable.first
    }

    private func resolvedCalendar(preferredIdentifier: String?) throws -> EKCalendar {
        if let preferredIdentifier, !preferredIdentifier.isEmpty {
            if let calendar = eventStore.calendar(withIdentifier: preferredIdentifier), calendar.allowsContentModifications {
                return calendar
            }
            throw AppleCalendarSyncError.targetCalendarMissing
        }

        guard let fallback = resolvedDefaultCalendar() else {
            throw AppleCalendarSyncError.noWritableCalendars
        }
        return fallback
    }

    private func findExistingEvent(for session: LessonSession, student: Student?, preferredCalendar: EKCalendar?) -> EKEvent? {
        if let identifier = session.appleCalendarItemIdentifier,
           let event = eventStore.calendarItem(withIdentifier: identifier) as? EKEvent {
            return event
        }

        let searchCalendars = preferredCalendar.map { [$0] }
        let searchStart = session.startAt.addingTimeInterval(-172_800)
        let searchEnd = session.endAt.addingTimeInterval(172_800)
        let predicate = eventStore.predicateForEvents(withStart: searchStart, end: searchEnd, calendars: searchCalendars)
        let marker = sessionMarker(for: session)
        let expectedURL = URL(string: "tutortable://session/\(session.id.uuidString)")
        let expectedTitle = student.map { "\($0.fullName) • \(session.title)" }

        return eventStore.events(matching: predicate).first { event in
            if event.url == expectedURL {
                return true
            }
            if event.notes?.contains(marker) == true {
                return true
            }
            if let expectedTitle,
               event.title == expectedTitle,
               abs(event.startDate.timeIntervalSince(session.startAt)) < 60,
               abs(event.endDate.timeIntervalSince(session.endAt)) < 60 {
                return true
            }
            return false
        }
    }

    private func eventNotes(for session: LessonSession, student: Student) -> String {
        var sections: [String] = []

        sections.append("Student\n\(student.fullName)")
        sections.append("Subject\n\(student.subject)")
        sections.append("Payment\nStatus: \(session.paymentStatus.title)\nAmount: \(AppFormat.currency(session.paymentAmount))\nMethod: \(session.paymentMethod.isEmpty ? "Not set" : session.paymentMethod)")
        sections.append("Lesson Notes\n\(session.lessonNotes.isEmpty ? "None recorded." : session.lessonNotes)")
        sections.append("Homework\n\(session.homework.isEmpty ? "None recorded." : session.homework)")
        return sections.joined(separator: "\n\n")
    }

    private func sessionMarker(for session: LessonSession) -> String {
        "TutorTable Session ID: \(session.id.uuidString)"
    }

    private func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func makeOption(from calendar: EKCalendar) -> AppleCalendarOption {
        AppleCalendarOption(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            sourceType: calendar.source.sourceType
        )
    }
}

private extension EKSourceType {
    var isLikelySyncSource: Bool {
        switch self {
        case .exchange, .calDAV, .mobileMe:
            return true
        case .local, .subscribed, .birthdays:
            return false
        @unknown default:
            return false
        }
    }
}
