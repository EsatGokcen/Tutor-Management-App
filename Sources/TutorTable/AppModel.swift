import AppKit
import EventKit
import Foundation
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var students: [Student] = []
    @Published private(set) var sessions: [LessonSession] = []
    @Published private(set) var creditPurchases: [StudentCreditPurchase] = []
    @Published private(set) var timeOffEntries: [TimeOffEntry] = []
    @Published private(set) var settings = AppSettings()
    @Published private(set) var reminderStatusText = "Not requested yet"
    @Published private(set) var activeHotKeyDescription = "Command + Shift + T"
    @Published private(set) var appleCalendarStatusText = "Not connected"
    @Published private(set) var appleCalendarDetailText = "TutorTable can sync sessions to a calendar that is already available in Apple Calendar on this Mac."
    @Published private(set) var availableAppleCalendars: [AppleCalendarOption] = []
    @Published var bannerMessage: String?

    let storagePaths = StoragePaths()
    let voiceCommandManager = VoiceCommandManager()

    private let reminderManager = ReminderManager()
    private let launcherManager: LauncherManager
    private let appleCalendarSyncManager = AppleCalendarSyncManager()

    var onPresentWindow: (() -> Void)?

    init() {
        do {
            try storagePaths.ensureDirectories()
        } catch {
            bannerMessage = "Could not create the TutorTable data folder: \(error.localizedDescription)"
        }

        launcherManager = LauncherManager()

        load()
        refreshAppleCalendarIntegrationState()
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
            .filter { $0.endAt <= Date() }
            .filter { !$0.lessonNotes.isEmpty || !$0.homework.isEmpty }
            .sorted { $0.startAt > $1.startAt }
    }

    var unpaidSessions: [LessonSession] {
        sessions
            .filter { $0.paymentStatus.needsAttention }
            .sorted { $0.startAt < $1.startAt }
    }

    var outstandingBalance: Double {
        unpaidSessions.reduce(0) { partial, session in
            partial + session.paymentAmount
        }
    }

    var hasAnyRecords: Bool {
        !students.isEmpty || !sessions.isEmpty || !timeOffEntries.isEmpty
    }

    var isAppleCalendarSyncEnabled: Bool {
        settings.appleCalendarSyncEnabled
    }

    var selectedAppleCalendarIdentifier: String {
        settings.appleCalendarIdentifier
    }

    func configureSystemIntegrations() {
        launcherManager.startLauncherIfNeeded()
        refreshHotKeyStatus()
        refreshAppleCalendarIntegrationState()

        if settings.appleCalendarSyncEnabled && appleCalendarSyncManager.hasFullAccess() {
            syncAllSessionsToAppleCalendar(showSuccessBanner: false)
        }

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

    func newSessionDraft(preferredStudentID: UUID? = nil) -> SessionDraft {
        let preferredStudent = preferredStudentID.flatMap { student(for: $0) } ?? studentsSorted.first
        return SessionDraft(defaults: settings, student: preferredStudent)
    }

    func newSessionDraft(on date: Date, preferredStudentID: UUID? = nil) -> SessionDraft {
        var draft = newSessionDraft(preferredStudentID: preferredStudentID)
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: date)

        let defaultHour: Int
        let defaultMinute: Int

        if calendar.isDateInToday(selectedDay) {
            let now = Date()
            let roundedNow = calendar.nextDate(
                after: now.addingTimeInterval(-1),
                matching: DateComponents(minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) ?? now
            defaultHour = calendar.component(.hour, from: roundedNow)
            defaultMinute = 0
        } else {
            defaultHour = 15
            defaultMinute = 0
        }

        let startAt = calendar.date(
            bySettingHour: defaultHour,
            minute: defaultMinute,
            second: 0,
            of: selectedDay
        ) ?? selectedDay

        draft.startAt = startAt
        draft.endAt = calendar.date(byAdding: .hour, value: 1, to: startAt) ?? startAt.addingTimeInterval(3_600)
        return draft
    }

    func newCreditPurchaseDraft(preferredStudentID: UUID? = nil) -> CreditPurchaseDraft {
        let preferredStudent = preferredStudentID.flatMap { student(for: $0) } ?? studentsSorted.first
        return CreditPurchaseDraft(student: preferredStudent)
    }

    func newTimeOffDraft(on date: Date = Date()) -> TimeOffDraft {
        TimeOffDraft(on: date)
    }

    func copiedSessionDraft(from sessionID: UUID) -> SessionDraft? {
        guard let session = sessions.first(where: { $0.id == sessionID }) else {
            return nil
        }

        bannerMessage = "Copied the session. Change the dates and save to create a new one."
        return SessionDraft(copying: session)
    }

    func studentName(for studentID: UUID) -> String {
        students.first(where: { $0.id == studentID })?.fullName ?? "Unknown Student"
    }

    func sessions(for studentID: UUID) -> [LessonSession] {
        sessions
            .filter { $0.studentID == studentID }
            .sorted { $0.startAt > $1.startAt }
    }

    func creditPurchases(for studentID: UUID) -> [StudentCreditPurchase] {
        creditPurchases
            .filter { $0.studentID == studentID }
            .sorted {
                if $0.purchasedAt == $1.purchasedAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.purchasedAt > $1.purchasedAt
            }
    }

    func student(for studentID: UUID) -> Student? {
        students.first(where: { $0.id == studentID })
    }

    func timeOffEntriesForDay(_ date: Date) -> [TimeOffEntry] {
        guard let dayInterval = Calendar.current.dateInterval(of: .day, for: date) else {
            return []
        }

        return timeOffEntries
            .filter { entry in
                intervalsOverlap(startAt: dayInterval.start, endAt: dayInterval.end, with: entry.startAt, entry.endAt)
            }
            .sorted {
                if $0.startAt == $1.startAt {
                    return $0.endAt < $1.endAt
                }
                return $0.startAt < $1.startAt
            }
    }

    func requestAppleCalendarAccess() async {
        do {
            let granted = try await appleCalendarSyncManager.requestFullAccess()
            refreshAppleCalendarIntegrationState()

            guard granted else {
                bannerMessage = "TutorTable was not granted full Apple Calendar access."
                return
            }

            settings.appleCalendarSyncEnabled = true
            if settings.appleCalendarIdentifier.isEmpty {
                settings.appleCalendarIdentifier = preferredAppleCalendarIdentifier()
            }
            persist()
            refreshAppleCalendarIntegrationState()
            syncAllSessionsToAppleCalendar(showSuccessBanner: true)
        } catch {
            refreshAppleCalendarIntegrationState()
            bannerMessage = error.localizedDescription
        }
    }

    func refreshAppleCalendarIntegration() {
        refreshAppleCalendarIntegrationState()
    }

    func disableAppleCalendarSync() {
        settings.appleCalendarSyncEnabled = false
        persist()
        refreshAppleCalendarIntegrationState()
        bannerMessage = "Apple Calendar sync is turned off. Existing Apple Calendar events were left in place."
    }

    func setAppleCalendar(identifier: String) {
        settings.appleCalendarIdentifier = identifier
        persist()
        refreshAppleCalendarIntegrationState()

        if settings.appleCalendarSyncEnabled {
            syncAllSessionsToAppleCalendar(showSuccessBanner: true)
        } else {
            bannerMessage = "Selected a new Apple Calendar for future TutorTable syncing."
        }
    }

    func syncAllSessionsToAppleCalendar(showSuccessBanner: Bool = true) {
        guard settings.appleCalendarSyncEnabled else {
            if showSuccessBanner {
                bannerMessage = "Turn on Apple Calendar sync first."
            }
            return
        }

        refreshAppleCalendarIntegrationState()
        guard appleCalendarSyncManager.hasFullAccess() else {
            bannerMessage = "TutorTable needs full Apple Calendar access before it can sync sessions."
            return
        }
        guard !availableAppleCalendars.isEmpty else {
            bannerMessage = "TutorTable could not find a writable Apple Calendar to sync into."
            return
        }

        var syncedCount = 0
        var firstFailureMessage: String?

        for index in sessions.indices {
            guard let student = student(for: sessions[index].studentID) else {
                firstFailureMessage = firstFailureMessage ?? AppleCalendarSyncError.sessionStudentMissing.localizedDescription
                continue
            }

            do {
                sessions[index] = try appleCalendarSyncManager.sync(
                    session: sessions[index],
                    student: student,
                    preferredCalendarIdentifier: settings.appleCalendarIdentifier
                )
                syncedCount += 1
            } catch {
                firstFailureMessage = firstFailureMessage ?? error.localizedDescription
            }
        }

        persist()
        refreshAppleCalendarIntegrationState()

        if showSuccessBanner {
            bannerMessage = syncAllSessionsBannerMessage(
                syncedCount: syncedCount,
                failureMessage: firstFailureMessage
            )
        }
    }

    func creditStatus(for studentID: UUID) -> StudentCreditStatus? {
        buildCreditStatuses()[studentID]
    }

    func creditStatuses() -> [StudentCreditStatus] {
        buildCreditStatuses()
            .values
            .filter { $0.totalPurchasedHours > 0 || !$0.coveredSessions.isEmpty || !$0.purchases.isEmpty }
            .sorted { $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending }
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

    func sessions(in timeframe: IncomeTimeframe) -> [LessonSession] {
        sessions
            .filter { timeframe.contains($0.startAt) }
            .sorted { $0.startAt > $1.startAt }
    }

    func creditPurchases(in timeframe: IncomeTimeframe) -> [StudentCreditPurchase] {
        creditPurchases
            .filter { timeframe.contains($0.purchasedAt) }
            .sorted { $0.purchasedAt > $1.purchasedAt }
    }

    func incomeEarned(in timeframe: IncomeTimeframe) -> Double {
        sessions(in: timeframe)
            .filter { $0.paymentStatus.isPaid }
            .reduce(0) { $0 + $1.paymentAmount }
    }

    func paidSessionCount(in timeframe: IncomeTimeframe) -> Int {
        sessions(in: timeframe).filter { $0.paymentStatus.isPaid }.count
    }

    func paymentSummary(in timeframe: IncomeTimeframe) -> PaymentSummary {
        var summary = sessions(in: timeframe).reduce(into: PaymentSummary()) { summary, session in
            switch session.paymentStatus {
            case .paid:
                summary.collectedAmount += session.paymentAmount
                summary.paidSessionCount += 1
            case .unpaid:
                summary.unpaidAmount += session.paymentAmount
                summary.unpaidSessionCount += 1
            case .creditCovered:
                summary.creditCoveredAmount += session.paymentAmount
                summary.creditCoveredSessionCount += 1
            }
        }

        let purchases = creditPurchases(in: timeframe)
        summary.creditReceivedAmount = purchases.reduce(0) { $0 + $1.amountPaid }
        summary.creditPurchaseCount = purchases.count
        return summary
    }

    func paymentAttentionSessions(in timeframe: IncomeTimeframe) -> [LessonSession] {
        sessions(in: timeframe)
            .filter { $0.paymentStatus.needsAttention }
            .sorted { $0.startAt < $1.startAt }
    }

    func studentPaymentReports(in timeframe: IncomeTimeframe) -> [StudentPaymentReport] {
        let sessionsByStudent = Dictionary(grouping: sessions(in: timeframe), by: \.studentID)

        return sessionsByStudent.compactMap { studentID, studentSessions in
            guard let student = student(for: studentID) else {
                return nil
            }

            let collectedAmount = studentSessions
                .filter { $0.paymentStatus == .paid }
                .reduce(0) { $0 + $1.paymentAmount }
            let unpaidAmount = studentSessions
                .filter { $0.paymentStatus == .unpaid }
                .reduce(0) { $0 + $1.paymentAmount }
            let creditCoveredAmount = studentSessions
                .filter { $0.paymentStatus == .creditCovered }
                .reduce(0) { $0 + $1.paymentAmount }
            let paidSessionCount = studentSessions.filter { $0.paymentStatus == .paid }.count
            let creditCoveredSessionCount = studentSessions.filter { $0.paymentStatus == .creditCovered }.count
            let openSessionCount = studentSessions.filter { $0.paymentStatus.needsAttention }.count

            return StudentPaymentReport(
                studentID: student.id,
                studentName: student.fullName,
                collectedAmount: collectedAmount,
                unpaidAmount: unpaidAmount,
                creditCoveredAmount: creditCoveredAmount,
                paidSessionCount: paidSessionCount,
                creditCoveredSessionCount: creditCoveredSessionCount,
                openSessionCount: openSessionCount
            )
        }
        .sorted {
            ($0.collectedAmount + $0.unpaidAmount + $0.creditCoveredAmount) >
            ($1.collectedAmount + $1.unpaidAmount + $1.creditCoveredAmount)
        }
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
        let linkedSessions = sessions.filter { $0.studentID == id }
        let calendarSyncWarning = removeAppleCalendarEvents(for: linkedSessions)
        students.removeAll { $0.id == id }
        sessions.removeAll { $0.studentID == id }
        creditPurchases.removeAll { $0.studentID == id }
        recalculateCreditCoverage()
        bannerMessage = mergeBannerMessage(
            primary: "Deleted \(removedName) and any linked sessions.",
            syncWarning: calendarSyncWarning
        )
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
        if let unavailableEntry = unavailableTimeOffEntry(for: session) {
            bannerMessage = unavailableMessage(for: unavailableEntry)
            return nil
        }

        let baseBannerMessage: String
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            baseBannerMessage = "Updated the session for \(studentName(for: session.studentID))."
        } else {
            sessions.append(session)
            baseBannerMessage = "Added a session for \(studentName(for: session.studentID))."
        }

        recalculateCreditCoverage()
        let syncResult = syncSessionToAppleCalendarIfNeeded(sessionID: session.id)
        let syncedSession = syncResult.session ?? sessions.first(where: { $0.id == session.id })
        persist()
        bannerMessage = mergeBannerMessage(
            primary: baseBannerMessage,
            syncWarning: syncResult.warningMessage
        )
        Task {
            await refreshReminders(requestingAccessIfNeeded: false)
        }
        return syncedSession
    }

    func deleteSession(id: UUID) {
        guard let existing = sessions.first(where: { $0.id == id }) else {
            return
        }

        let calendarSyncWarning = removeAppleCalendarEvent(for: existing)
        sessions.removeAll { $0.id == id }
        recalculateCreditCoverage()
        bannerMessage = mergeBannerMessage(
            primary: "Deleted the session for \(studentName(for: existing.studentID)).",
            syncWarning: calendarSyncWarning
        )
        persist()
        Task {
            await refreshReminders(requestingAccessIfNeeded: false)
        }
    }

    @discardableResult
    func saveTimeOffEntry(_ draft: TimeOffDraft) -> TimeOffEntry? {
        guard draft.isValid else {
            bannerMessage = "Choose a valid unavailable period before saving time off."
            return nil
        }

        let entry = draft.makeEntry()
        if let index = timeOffEntries.firstIndex(where: { $0.id == entry.id }) {
            timeOffEntries[index] = entry
        } else {
            timeOffEntries.append(entry)
        }

        let overlappingSessions = sessions
            .filter { intervalsOverlap(startAt: $0.startAt, endAt: $0.endAt, with: entry.startAt, entry.endAt) }
            .sorted { $0.startAt < $1.startAt }

        if overlappingSessions.isEmpty {
            bannerMessage = "Saved unavailable time."
        } else {
            bannerMessage = "Saved unavailable time. \(overlappingSessions.count) existing session\(overlappingSessions.count == 1 ? "" : "s") still overlap it."
        }

        persist()
        return entry
    }

    func deleteTimeOffEntry(id: UUID) {
        guard let existing = timeOffEntries.first(where: { $0.id == id }) else {
            return
        }

        timeOffEntries.removeAll { $0.id == id }
        bannerMessage = "Deleted unavailable time for \(existing.displayTitle)."
        persist()
    }

    @discardableResult
    func saveCreditPurchase(_ draft: CreditPurchaseDraft) -> StudentCreditPurchase? {
        guard draft.isValid else {
            bannerMessage = "Choose a student and enter the credit hours and amount paid before saving."
            return nil
        }

        let purchase = draft.makePurchase(for: draft.studentID.flatMap { student(for: $0) })
        if let index = creditPurchases.firstIndex(where: { $0.id == purchase.id }) {
            creditPurchases[index] = purchase
            bannerMessage = "Updated the advance credit payment for \(studentName(for: purchase.studentID))."
        } else {
            creditPurchases.append(purchase)
            bannerMessage = "Added advance credit for \(studentName(for: purchase.studentID))."
        }

        recalculateCreditCoverage()
        persist()
        return purchase
    }

    func deleteCreditPurchase(id: UUID) {
        guard let existing = creditPurchases.first(where: { $0.id == id }) else {
            return
        }

        creditPurchases.removeAll { $0.id == id }
        recalculateCreditCoverage()
        bannerMessage = "Deleted the advance credit payment for \(studentName(for: existing.studentID))."
        persist()
    }

    func saveSettings(
        defaultSubject: String,
        defaultHourlyRate: Double,
        defaultSessionType: String,
        defaultSessionLocation: String,
        defaultSessionPaymentMethod: String
    ) {
        let trimmedSubject = defaultSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSessionType = defaultSessionType.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.defaultStudentSubject = trimmedSubject.isEmpty ? AppSettings.defaultStudentSubjectValue : trimmedSubject
        settings.defaultStudentHourlyRate = defaultHourlyRate
        settings.defaultSessionType = trimmedSessionType.isEmpty ? AppSettings.defaultSessionTypeValue : trimmedSessionType
        settings.defaultSessionLocation = defaultSessionLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.defaultSessionPaymentMethod = defaultSessionPaymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        bannerMessage = "Saved your student and session defaults."
        persist()
    }

    func refreshHotKeyStatus() {
        activeHotKeyDescription = launcherManager.loadStatus()?.displayName ?? launcherManager.fallbackDisplayName
    }

    func openDataFolder() {
        NSWorkspace.shared.open(storagePaths.rootDirectory)
    }

    func applyVoiceCommandTranscript() {
        let transcript = voiceCommandManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            bannerMessage = "Speak or type a voice command first."
            return
        }

        do {
            let intent = try VoiceCommandInterpreter.interpret(
                transcript: transcript,
                context: VoiceCommandContext(
                    students: students,
                    sessions: sessions,
                    settings: settings,
                    now: Date(),
                    calendar: .current
                )
            )

            switch intent {
            case .createSession(let createIntent):
                applyCreateSessionIntent(createIntent)
            case .updateSessionPayment(let updateIntent):
                applyUpdateSessionPaymentIntent(updateIntent)
            }
        } catch {
            bannerMessage = error.localizedDescription
        }
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
                paymentStatus: .unpaid,
                paymentMethod: "Cash",
                lessonNotes: "Improved consistency on sixteenth-note runs after slowing down the metronome.",
                homework: "Practice the alternate-picking pattern in three keys at 70 BPM.",
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
                createdAt: now,
                updatedAt: now
            )
        ]

        let sampleCreditPurchases = [
            StudentCreditPurchase(
                id: UUID(),
                studentID: lucas.id,
                purchasedAt: now,
                purchasedHours: 2,
                discountAmount: 0,
                amountPaid: 110,
                note: "Two lessons paid in advance.",
                createdAt: now,
                updatedAt: now
            )
        ]

        students = sampleStudents
        sessions = sampleSessions
        creditPurchases = sampleCreditPurchases
        timeOffEntries = []
        recalculateCreditCoverage()
        bannerMessage = "Added sample students, sessions, and advance credit so you can test the full interface."
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
            creditPurchases = snapshot.creditPurchases
            timeOffEntries = snapshot.timeOffEntries
            recalculateCreditCoverage()
        } catch CocoaError.fileReadNoSuchFile {
            settings = AppSettings()
            students = []
            sessions = []
            creditPurchases = []
            timeOffEntries = []
        } catch {
            bannerMessage = "TutorTable could not read the saved data file, so it started with a clean state."
            settings = AppSettings()
            students = []
            sessions = []
            creditPurchases = []
            timeOffEntries = []
        }
    }

    private func persist() {
        do {
            let snapshot = AppSnapshot(
                settings: settings,
                students: students,
                sessions: sessions,
                creditPurchases: creditPurchases,
                timeOffEntries: timeOffEntries
            )
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

    private func applyCreateSessionIntent(_ intent: VoiceCreateSessionIntent) {
        var draft = newSessionDraft(preferredStudentID: intent.studentID)
        draft.startAt = intent.startAt
        draft.endAt = intent.endAt
        draft.paymentStatus = intent.paymentStatus

        if let title = intent.title {
            draft.title = title
        }
        if let location = intent.location {
            draft.location = location
        }
        if let paymentAmount = intent.paymentAmount {
            draft.paymentAmount = paymentAmount
        }
        if let paymentMethod = intent.paymentMethod {
            draft.paymentMethod = paymentMethod
        }

        guard let session = saveSession(draft) else {
            return
        }

        let studentName = studentName(for: session.studentID)
        bannerMessage = "Created a session for \(studentName) on \(AppFormat.dateTimeFormatter.string(from: session.startAt))."
    }

    private func applyUpdateSessionPaymentIntent(_ intent: VoiceUpdateSessionPaymentIntent) {
        guard let index = sessions.firstIndex(where: { $0.id == intent.sessionID }) else {
            bannerMessage = "I couldn't find the session to update."
            return
        }

        sessions[index].paymentStatus = intent.paymentStatus
        if let paymentMethod = intent.paymentMethod {
            sessions[index].paymentMethod = paymentMethod
        }
        sessions[index].updatedAt = Date()
        recalculateCreditCoverage()
        let syncResult = syncSessionToAppleCalendarIfNeeded(sessionID: intent.sessionID)
        let session = syncResult.session ?? sessions[index]
        persist()
        Task {
            await refreshReminders(requestingAccessIfNeeded: false)
        }

        bannerMessage = mergeBannerMessage(
            primary: "Updated \(studentName(for: session.studentID))'s session on \(AppFormat.shortDateFormatter.string(from: session.startAt)) and marked it \(statusSummary(for: intent.paymentStatus)).",
            syncWarning: syncResult.warningMessage
        )
    }

    private func refreshAppleCalendarIntegrationState() {
        let snapshot = appleCalendarSyncManager.connectionSnapshot()
        availableAppleCalendars = snapshot.availableCalendars

        if settings.appleCalendarSyncEnabled,
           settings.appleCalendarIdentifier.isEmpty,
           let fallbackIdentifier = preferredAppleCalendarIdentifier(from: snapshot) {
            settings.appleCalendarIdentifier = fallbackIdentifier
            persist()
        }

        if settings.appleCalendarSyncEnabled,
           !settings.appleCalendarIdentifier.isEmpty,
           availableAppleCalendars.contains(where: { $0.id == settings.appleCalendarIdentifier }) == false,
           let fallbackIdentifier = preferredAppleCalendarIdentifier(from: snapshot) {
            settings.appleCalendarIdentifier = fallbackIdentifier
            persist()
        }

        appleCalendarStatusText = Self.appleCalendarStatusText(
            authorizationStatus: snapshot.authorizationStatus,
            syncEnabled: settings.appleCalendarSyncEnabled,
            selectedCalendar: availableAppleCalendars.first(where: { $0.id == settings.appleCalendarIdentifier })
        )
        appleCalendarDetailText = Self.appleCalendarDetailText(
            authorizationStatus: snapshot.authorizationStatus,
            syncEnabled: settings.appleCalendarSyncEnabled,
            availableCalendarCount: availableAppleCalendars.count,
            selectedCalendar: availableAppleCalendars.first(where: { $0.id == settings.appleCalendarIdentifier })
        )
    }

    private func preferredAppleCalendarIdentifier() -> String {
        preferredAppleCalendarIdentifier(from: appleCalendarSyncManager.connectionSnapshot()) ?? settings.appleCalendarIdentifier
    }

    private func preferredAppleCalendarIdentifier(from snapshot: AppleCalendarConnectionSnapshot) -> String? {
        if !settings.appleCalendarIdentifier.isEmpty,
           snapshot.availableCalendars.contains(where: { $0.id == settings.appleCalendarIdentifier }) {
            return settings.appleCalendarIdentifier
        }

        return snapshot.defaultCalendarIdentifier ?? snapshot.availableCalendars.first?.id
    }

    private func syncSessionToAppleCalendarIfNeeded(sessionID: UUID) -> (session: LessonSession?, warningMessage: String?) {
        guard settings.appleCalendarSyncEnabled else {
            return (sessions.first(where: { $0.id == sessionID }), nil)
        }

        refreshAppleCalendarIntegrationState()

        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return (nil, nil)
        }

        guard let student = student(for: sessions[index].studentID) else {
            return (sessions[index], AppleCalendarSyncError.sessionStudentMissing.localizedDescription)
        }

        do {
            sessions[index] = try appleCalendarSyncManager.sync(
                session: sessions[index],
                student: student,
                preferredCalendarIdentifier: settings.appleCalendarIdentifier
            )
            return (sessions[index], nil)
        } catch {
            return (sessions[index], error.localizedDescription)
        }
    }

    private func removeAppleCalendarEvent(for session: LessonSession) -> String? {
        guard settings.appleCalendarSyncEnabled else {
            return nil
        }

        do {
            try appleCalendarSyncManager.removeSyncedEvent(
                for: session,
                student: student(for: session.studentID),
                preferredCalendarIdentifier: settings.appleCalendarIdentifier
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func removeAppleCalendarEvents(for sessions: [LessonSession]) -> String? {
        guard settings.appleCalendarSyncEnabled else {
            return nil
        }

        for session in sessions {
            if let warning = removeAppleCalendarEvent(for: session) {
                return warning
            }
        }

        return nil
    }

    private func mergeBannerMessage(primary: String, syncWarning: String?) -> String {
        guard let syncWarning, !syncWarning.isEmpty else {
            return primary
        }

        return "\(primary) Apple Calendar sync warning: \(syncWarning)"
    }

    private func syncAllSessionsBannerMessage(syncedCount: Int, failureMessage: String?) -> String {
        let baseMessage = syncedCount == 1
            ? "Synced 1 session to Apple Calendar."
            : "Synced \(syncedCount) sessions to Apple Calendar."
        return mergeBannerMessage(primary: baseMessage, syncWarning: failureMessage)
    }

    private func statusSummary(for status: PaymentStatus) -> String {
        switch status {
        case .paid:
            return "paid"
        case .creditCovered:
            return "covered by credit"
        case .unpaid:
            return "unpaid"
        }
    }

    private func unavailableTimeOffEntry(for session: LessonSession) -> TimeOffEntry? {
        timeOffEntries
            .filter { intervalsOverlap(startAt: session.startAt, endAt: session.endAt, with: $0.startAt, $0.endAt) }
            .sorted { $0.startAt < $1.startAt }
            .first
    }

    private func unavailableMessage(for entry: TimeOffEntry) -> String {
        if entry.isAllDay {
            return "\(entry.displayTitle) makes that date unavailable."
        }

        return "\(entry.displayTitle) makes that time unavailable (\(AppFormat.dateTimeFormatter.string(from: entry.startAt)) to \(AppFormat.dateTimeFormatter.string(from: entry.endAt)))."
    }

    private func intervalsOverlap(startAt: Date, endAt: Date, with otherStartAt: Date, _ otherEndAt: Date) -> Bool {
        startAt < otherEndAt && endAt > otherStartAt
    }

    private static func appleCalendarStatusText(
        authorizationStatus: EKAuthorizationStatus,
        syncEnabled: Bool,
        selectedCalendar: AppleCalendarOption?
    ) -> String {
        if authorizationStatus == .notDetermined {
            return "Not connected"
        }
        if authorizationStatus == .restricted {
            return "Restricted by macOS"
        }
        if authorizationStatus == .denied {
            return "Access denied"
        }
        if #available(macOS 14.0, *), authorizationStatus == .writeOnly {
            return "Write-only access is not enough"
        }

        guard syncEnabled else {
            return "Access granted, sync is off"
        }

        if let selectedCalendar {
            if !selectedCalendar.likelySyncsAcrossDevices {
                return "Connected to \(selectedCalendar.displayName) on this Mac only"
            }
            return "Connected to \(selectedCalendar.displayName)"
        }
        return "Connected"
    }

    private static func appleCalendarDetailText(
        authorizationStatus: EKAuthorizationStatus,
        syncEnabled: Bool,
        availableCalendarCount: Int,
        selectedCalendar: AppleCalendarOption?
    ) -> String {
        if authorizationStatus == .notDetermined {
            return "Connect TutorTable once and it will use calendars that are already signed into Apple Calendar on this Mac."
        }
        if authorizationStatus == .restricted {
            return "Apple Calendar access is restricted on this Mac, so TutorTable cannot sync sessions right now."
        }
        if authorizationStatus == .denied {
            return "Allow Apple Calendar access in macOS privacy settings, then return here and refresh the connection."
        }
        if #available(macOS 14.0, *), authorizationStatus == .writeOnly {
            return "TutorTable needs full access so it can update and delete existing session events, not just create new ones."
        }

        if availableCalendarCount == 0 {
            return "Calendar access is available, but no writable calendars were found in Apple Calendar."
        }
        if let selectedCalendar, !selectedCalendar.likelySyncsAcrossDevices {
            return "The selected calendar appears to be stored only on this Mac, so its events usually will not show up on iPhone. Choose an iCloud, Google, or Exchange calendar in this card, then sync existing sessions again."
        }
        if syncEnabled {
            return "New sessions, edits, and deletes will sync automatically. Existing synced events keep Lesson Notes and Homework as separate sections in the Apple Calendar notes field."
        }
        return "Access is ready. Turn sync on to start sending TutorTable sessions into the calendar you choose below."
    }

    private func recalculateCreditCoverage() {
        let coveredSessionIDs = Set(
            buildCreditStatuses()
                .values
                .flatMap { $0.coveredSessions.map(\.id) }
        )

        for index in sessions.indices {
            if sessions[index].paymentStatus == .paid {
                continue
            }

            sessions[index].paymentStatus = coveredSessionIDs.contains(sessions[index].id) ? .creditCovered : .unpaid
        }
    }

    private func buildCreditStatuses() -> [UUID: StudentCreditStatus] {
        let knownStudentIDs = Set(students.map(\.id))
            .union(Set(sessions.map(\.studentID)))
            .union(Set(creditPurchases.map(\.studentID)))

        var statuses: [UUID: StudentCreditStatus] = [:]

        for studentID in knownStudentIDs {
            let studentName = student(for: studentID)?.fullName ?? "Unknown Student"
            let studentPurchases = creditPurchases(for: studentID)
                .sorted {
                    if $0.purchasedAt == $1.purchasedAt {
                        return $0.createdAt < $1.createdAt
                    }
                    return $0.purchasedAt < $1.purchasedAt
                }

            var purchaseStates = studentPurchases.map {
                CreditPurchaseState(purchase: $0, remainingHours: max(0, $0.purchasedHours))
            }

            let studentSessions = sessions(for: studentID)
                .sorted { $0.startAt < $1.startAt }

            var coveredSessions: [LessonSession] = []
            var uncoveredSessions: [LessonSession] = []

            for session in studentSessions {
                guard session.paymentStatus != .paid else {
                    continue
                }

                let requiredHours = session.durationHours
                guard requiredHours > 0 else {
                    uncoveredSessions.append(session)
                    continue
                }

                let eligiblePurchaseIndices = purchaseStates.indices.filter { index in
                    purchaseStates[index].purchase.purchasedAt <= session.startAt &&
                    purchaseStates[index].remainingHours > 0.0001
                }

                let availableHours = eligiblePurchaseIndices.reduce(0.0) { total, index in
                    total + purchaseStates[index].remainingHours
                }

                guard availableHours + 0.0001 >= requiredHours else {
                    uncoveredSessions.append(session)
                    continue
                }

                var remainingHoursToConsume = requiredHours
                for index in eligiblePurchaseIndices {
                    guard remainingHoursToConsume > 0.0001 else {
                        break
                    }

                    let consumedHours = min(purchaseStates[index].remainingHours, remainingHoursToConsume)
                    guard consumedHours > 0.0001 else {
                        continue
                    }

                    purchaseStates[index].remainingHours -= consumedHours
                    purchaseStates[index].coveredSessionIDs.append(session.id)
                    remainingHoursToConsume -= consumedHours
                }

                coveredSessions.append(session)
            }

            let purchaseUsage = purchaseStates
                .map { state in
                    CreditPurchaseUsage(
                        purchase: state.purchase,
                        usedHours: max(0, state.purchase.purchasedHours - state.remainingHours),
                        remainingHours: max(0, state.remainingHours),
                        coveredSessionIDs: state.coveredSessionIDs
                    )
                }
                .sorted { $0.purchase.purchasedAt > $1.purchase.purchasedAt }

            statuses[studentID] = StudentCreditStatus(
                studentID: studentID,
                studentName: studentName,
                totalPurchasedHours: studentPurchases.reduce(0) { $0 + $1.purchasedHours },
                usedHours: purchaseUsage.reduce(0) { $0 + $1.usedHours },
                remainingHours: purchaseUsage.reduce(0) { $0 + $1.remainingHours },
                totalAmountPaid: studentPurchases.reduce(0) { $0 + $1.amountPaid },
                totalDiscountAmount: studentPurchases.reduce(0) { $0 + $1.discountAmount },
                coveredSessions: coveredSessions.sorted { $0.startAt < $1.startAt },
                uncoveredSessions: uncoveredSessions.sorted { $0.startAt < $1.startAt },
                purchases: purchaseUsage
            )
        }

        return statuses
    }
}

private struct CreditPurchaseState {
    let purchase: StudentCreditPurchase
    var remainingHours: Double
    var coveredSessionIDs: [UUID] = []
}
