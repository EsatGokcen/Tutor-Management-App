import AppKit
import Foundation
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var students: [Student] = []
    @Published private(set) var sessions: [LessonSession] = []
    @Published private(set) var settings = AppSettings()
    @Published private(set) var reminderStatusText = "Not requested yet"
    @Published private(set) var activeHotKeyDescription = "Command + Option + M"
    @Published var bannerMessage: String?

    let storagePaths = StoragePaths()
    let audioRecorder: AudioRecorder

    private let reminderManager = ReminderManager()
    private let launcherManager: LauncherManager

    var onPresentWindow: (() -> Void)?

    init() {
        do {
            try storagePaths.ensureDirectories()
        } catch {
            bannerMessage = "Could not create the TutorTable data folder: \(error.localizedDescription)"
        }

        audioRecorder = AudioRecorder(audioDirectory: storagePaths.audioDirectory)
        launcherManager = LauncherManager(rootDirectory: storagePaths.rootDirectory)

        audioRecorder.onRecordingFinished = { [weak self] fileName in
            self?.bannerMessage = "Saved audio note: \(fileName)"
        }

        load()
    }

    var studentsSorted: [Student] {
        students.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    var upcomingSessions: [LessonSession] {
        sessions
            .filter { $0.endAt >= Date() }
            .sorted { $0.startAt < $1.startAt }
    }

    var recentLessons: [LessonSession] {
        sessions
            .filter { !$0.lessonNotes.isEmpty || !$0.homework.isEmpty || $0.audioNoteFilename != nil }
            .sorted { $0.startAt > $1.startAt }
    }

    var unpaidSessions: [LessonSession] {
        sessions
            .filter { $0.paymentStatus != .paid }
            .sorted { $0.startAt < $1.startAt }
    }

    var outstandingBalance: Double {
        unpaidSessions.reduce(0) { partial, session in
            partial + session.paymentAmount
        }
    }

    var hasAnyRecords: Bool {
        !students.isEmpty || !sessions.isEmpty
    }

    func configureSystemIntegrations() {
        launcherManager.startLauncherIfNeeded()
        refreshHotKeyStatus()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshHotKeyStatus()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshHotKeyStatus()
        }

        Task {
            await refreshReminders(requestingAccessIfNeeded: true)
        }
    }

    func newStudentDraft() -> StudentDraft {
        StudentDraft(defaults: settings)
    }

    func newSessionDraft() -> SessionDraft {
        var draft = SessionDraft()
        if let firstStudent = studentsSorted.first {
            draft.studentID = firstStudent.id
            draft.paymentAmount = firstStudent.hourlyRate
        }
        return draft
    }

    func studentName(for studentID: UUID) -> String {
        students.first(where: { $0.id == studentID })?.fullName ?? "Unknown Student"
    }

    func sessions(for studentID: UUID) -> [LessonSession] {
        sessions
            .filter { $0.studentID == studentID }
            .sorted { $0.startAt > $1.startAt }
    }

    func student(for studentID: UUID) -> Student? {
        students.first(where: { $0.id == studentID })
    }

    func filteredSessions(using filter: SessionFilter) -> [LessonSession] {
        switch filter {
        case .upcoming:
            return upcomingSessions
        case .unpaid:
            return unpaidSessions
        case .all:
            return sessions.sorted { $0.startAt > $1.startAt }
        }
    }

    func incomeEarned(in timeframe: IncomeTimeframe) -> Double {
        sessions
            .filter { $0.paymentStatus == .paid }
            .filter { timeframe.contains($0.startAt) }
            .reduce(0) { $0 + $1.paymentAmount }
    }

    func paidSessionCount(in timeframe: IncomeTimeframe) -> Int {
        sessions.filter { $0.paymentStatus == .paid && timeframe.contains($0.startAt) }.count
    }

    @discardableResult
    func saveStudent(_ draft: StudentDraft) -> Student? {
        guard draft.isValid else {
            bannerMessage = "Add at least a student name before saving."
            return nil
        }

        let student = draft.makeStudent()
        if let index = students.firstIndex(where: { $0.id == student.id }) {
            students[index] = student
            bannerMessage = "Updated \(student.fullName)."
        } else {
            students.append(student)
            bannerMessage = "Added \(student.fullName)."
        }

        persist()
        return student
    }

    func deleteStudent(id: UUID) {
        let removedName = students.first(where: { $0.id == id })?.fullName ?? "student"
        students.removeAll { $0.id == id }
        sessions.removeAll { $0.studentID == id }
        bannerMessage = "Deleted \(removedName) and any linked sessions."
        persist()
        Task {
            await refreshReminders(requestingAccessIfNeeded: false)
        }
    }

    @discardableResult
    func saveSession(_ draft: SessionDraft) -> LessonSession? {
        guard draft.isValid else {
            bannerMessage = "Choose a student and make sure the end time is after the start time."
            return nil
        }

        let session = draft.makeSession()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            bannerMessage = "Updated the session for \(studentName(for: session.studentID))."
        } else {
            sessions.append(session)
            bannerMessage = "Added a session for \(studentName(for: session.studentID))."
        }

        persist()
        Task {
            await refreshReminders(requestingAccessIfNeeded: false)
        }
        return session
    }

    func deleteSession(id: UUID) {
        guard let existing = sessions.first(where: { $0.id == id }) else {
            return
        }

        sessions.removeAll { $0.id == id }
        bannerMessage = "Deleted the session for \(studentName(for: existing.studentID))."
        persist()
        Task {
            await refreshReminders(requestingAccessIfNeeded: false)
        }
    }

    func saveSettings(defaultSubject: String, defaultHourlyRate: Double) {
        let trimmedSubject = defaultSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.defaultStudentSubject = trimmedSubject.isEmpty ? AppSettings.defaultStudentSubjectValue : trimmedSubject
        settings.defaultStudentHourlyRate = defaultHourlyRate
        bannerMessage = "Saved your default student subject and hourly rate."
        persist()
    }

    func refreshHotKeyStatus() {
        activeHotKeyDescription = launcherManager.loadStatus()?.displayName ?? launcherManager.fallbackDisplayName
    }

    func startRecording(for sessionID: UUID) {
        audioRecorder.startRecording(for: sessionID)
        if audioRecorder.errorMessage == nil {
            bannerMessage = "Recording voice note..."
        }
    }

    func stopRecording() -> String? {
        let fileName = audioRecorder.stopRecording()
        if let fileName {
            bannerMessage = "Saved voice note \(fileName)."
        }
        return fileName
    }

    func openDataFolder() {
        NSWorkspace.shared.open(storagePaths.rootDirectory)
    }

    func revealAudioNote(named fileName: String) {
        audioRecorder.revealAudioNote(named: fileName)
    }

    func dismissBanner() {
        bannerMessage = nil
    }

    func addSampleData() {
        guard !hasAnyRecords else {
            bannerMessage = "Sample data was not added because TutorTable already has saved records."
            return
        }

        let now = Date()
        let calendar = Calendar.current

        let maya = Student(
            id: UUID(),
            fullName: "Maya Patel",
            subject: "Electric Guitar",
            phoneNumber: "+44 7700 900101",
            email: "maya.parent@example.com",
            hourlyRate: 45,
            notes: "Enjoys melodic solo practice and responds well to slow breakdowns.",
            createdAt: now
        )

        let lucas = Student(
            id: UUID(),
            fullName: "Lucas Bennett",
            subject: "Electric Guitar",
            phoneNumber: "+44 7700 900102",
            email: "lucas@example.com",
            hourlyRate: 55,
            notes: "Working on timing consistency for riff-based practice.",
            createdAt: now
        )

        let sofia = Student(
            id: UUID(),
            fullName: "Sofia Nguyen",
            subject: "Electric Guitar",
            phoneNumber: "+44 7700 900103",
            email: "sofia.family@example.com",
            hourlyRate: 40,
            notes: "Focused on chord transitions and confidence when improvising.",
            createdAt: now
        )

        let sampleStudents = [maya, lucas, sofia]

        let sampleSessions = [
            LessonSession(
                id: UUID(),
                studentID: maya.id,
                title: "Pentatonic Shapes and Bends",
                location: "Home visit",
                startAt: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                endAt: calendar.date(byAdding: .minute, value: 60, to: calendar.date(byAdding: .day, value: 1, to: now) ?? now) ?? now,
                reminderMinutesBefore: 30,
                paymentAmount: 45,
                paymentStatus: .unpaid,
                paymentMethod: "Bank transfer",
                lessonNotes: "",
                homework: "",
                audioNoteFilename: nil,
                createdAt: now,
                updatedAt: now
            ),
            LessonSession(
                id: UUID(),
                studentID: lucas.id,
                title: "Alternate Picking Workout",
                location: "Zoom",
                startAt: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
                endAt: calendar.date(byAdding: .minute, value: 90, to: calendar.date(byAdding: .day, value: 3, to: now) ?? now) ?? now,
                reminderMinutesBefore: 45,
                paymentAmount: 82.5,
                paymentStatus: .partiallyPaid,
                paymentMethod: "Cash",
                lessonNotes: "Improved consistency on sixteenth-note runs after slowing down the metronome.",
                homework: "Practice the alternate-picking pattern in three keys at 70 BPM.",
                audioNoteFilename: nil,
                createdAt: now,
                updatedAt: now
            ),
            LessonSession(
                id: UUID(),
                studentID: sofia.id,
                title: "Chord Progressions and Dynamics",
                location: "Library study room",
                startAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                endAt: calendar.date(byAdding: .minute, value: 75, to: calendar.date(byAdding: .day, value: -2, to: now) ?? now) ?? now,
                reminderMinutesBefore: 20,
                paymentAmount: 50,
                paymentStatus: .paid,
                paymentMethod: "Card reader",
                lessonNotes: "Built a cleaner strumming pattern and started dynamic control exercises.",
                homework: "Practice the I-V-vi-IV progression with two dynamic levels.",
                audioNoteFilename: nil,
                createdAt: now,
                updatedAt: now
            )
        ]

        students = sampleStudents
        sessions = sampleSessions
        bannerMessage = "Added sample students and sessions so you can test the full interface."
        persist()

        Task {
            await refreshReminders(requestingAccessIfNeeded: false)
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storagePaths.dataFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(AppSnapshot.self, from: data)
            settings = snapshot.settings
            students = snapshot.students
            sessions = snapshot.sessions
        } catch CocoaError.fileReadNoSuchFile {
            settings = AppSettings()
            students = []
            sessions = []
        } catch {
            bannerMessage = "TutorTable could not read the saved data file, so it started with a clean state."
            settings = AppSettings()
            students = []
            sessions = []
        }
    }

    private func persist() {
        do {
            let snapshot = AppSnapshot(settings: settings, students: students, sessions: sessions)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(snapshot)
            try encoded.write(to: storagePaths.dataFile, options: .atomic)
        } catch {
            bannerMessage = "TutorTable could not save your data: \(error.localizedDescription)"
        }
    }

    private func refreshReminders(requestingAccessIfNeeded: Bool) async {
        let status: UNAuthorizationStatus
        if requestingAccessIfNeeded {
            status = await reminderManager.requestAuthorizationIfNeeded()
        } else {
            status = await reminderManager.refreshNotifications(
                sessions: sessions,
                students: Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
            )
            reminderStatusText = Self.reminderStatusDescription(for: status)
            return
        }

        reminderStatusText = Self.reminderStatusDescription(for: status)
        _ = await reminderManager.refreshNotifications(
            sessions: sessions,
            students: Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
        )
    }

    private static func reminderStatusDescription(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Provisionally enabled"
        case .denied:
            return "Denied in macOS settings"
        case .notDetermined:
            return "Permission not requested yet"
        case .ephemeral:
            return "Temporarily enabled"
        @unknown default:
            return "Unknown"
        }
    }
}
