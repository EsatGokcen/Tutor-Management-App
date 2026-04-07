import Foundation
import UserNotifications

final class ReminderManager {
    private let center = UNUserNotificationCenter.current()
    private static let requestPrefix = "tutortable-session-"

    func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        let currentSettings = await notificationSettings()
        if currentSettings.authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        return await notificationSettings().authorizationStatus
    }

    func refreshNotifications(
        sessions: [LessonSession],
        students: [UUID: Student]
    ) async -> UNAuthorizationStatus {
        let requestIDs = await pendingTutorTableRequestIDs()
        if !requestIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: requestIDs)
        }

        let status = await notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else {
            return status
        }

        for session in sessions {
            let fireDate = session.startAt.addingTimeInterval(TimeInterval(-session.reminderMinutesBefore * 60))
            guard fireDate > Date() else {
                continue
            }

            let studentName = students[session.studentID]?.fullName ?? "Student"
            let content = UNMutableNotificationContent()
            content.title = "\(studentName) lesson reminder"
            content.body = "\(session.title) starts at \(AppFormat.dateTimeFormatter.string(from: session.startAt)). Payment: \(AppFormat.currency(session.paymentAmount))."
            content.sound = .default

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.requestIdentifier(for: session.id),
                content: content,
                trigger: trigger
            )

            try? await add(request)
        }

        return status
    }

    private func pendingTutorTableRequestIDs() async -> [String] {
        let requests = await pendingRequests()
        return requests.map(\.identifier).filter { $0.hasPrefix(Self.requestPrefix) }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { continuation.resume(returning: $0) }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { continuation.resume(returning: $0) }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func requestIdentifier(for sessionID: UUID) -> String {
        "\(requestPrefix)\(sessionID.uuidString)"
    }
}
