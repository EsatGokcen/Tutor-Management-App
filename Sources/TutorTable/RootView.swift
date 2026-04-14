import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let bannerMessage = appModel.bannerMessage {
                BannerView(message: bannerMessage) {
                    appModel.dismissBanner()
                }
            }

            TabView {
                OverviewView()
                    .tabItem {
                        Label("Overview", systemImage: "house")
                    }

                StudentsView()
                    .tabItem {
                        Label("Students", systemImage: "person.3")
                    }

                SessionsView()
                    .tabItem {
                        Label("Sessions", systemImage: "calendar")
                    }

                LessonsCalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar.day.timeline.left")
                    }

                PaymentsView()
                    .tabItem {
                        Label("Payments", systemImage: "sterlingsign.circle")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .padding(24)
        }
        .font(.system(size: 15.5))
        .controlSize(.large)
        .background(Color(nsColor: .underPageBackgroundColor))
        .frame(minWidth: 1160, minHeight: 800)
    }
}

struct OverviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var incomeTimeframe: IncomeTimeframe = .monthly

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Overview")
                    .font(.system(size: 28, weight: .semibold))

                if !appModel.hasAnyRecords {
                    GroupBox("Getting Started") {
                        Text("TutorTable is ready. Add your first student or visit Settings to load sample data and adjust your default lesson subject and rate.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 18
                ) {
                    MetricCard(title: "Students", value: "\(appModel.students.count)", subtitle: "Tracked locally")
                    MetricCard(title: "Upcoming", value: "\(appModel.upcomingSessions.count)", subtitle: "Scheduled lessons")
                    MetricCard(title: "Outstanding", value: AppFormat.currency(appModel.outstandingBalance), subtitle: "Awaiting payment")
                    IncomeMetricCard(
                        timeframe: $incomeTimeframe,
                        total: appModel.incomeEarned(in: incomeTimeframe),
                        paidSessions: appModel.paidSessionCount(in: incomeTimeframe)
                    )
                }

                GroupBox("Upcoming Sessions") {
                    VStack(alignment: .leading, spacing: 14) {
                        if appModel.upcomingSessions.isEmpty {
                            EmptyStateView(message: "Your upcoming sessions will show up here once you add them.")
                        } else {
                            ForEach(Array(appModel.upcomingSessions.prefix(6))) { session in
                                SessionSummaryRow(
                                    title: session.title,
                                    subtitle: "\(appModel.studentName(for: session.studentID)) • \(AppFormat.dateTimeFormatter.string(from: session.startAt))",
                                    trailing: session.paymentStatus.title
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }

                GroupBox("Recent Lesson Memory") {
                    VStack(alignment: .leading, spacing: 14) {
                        if appModel.recentLessons.isEmpty {
                            EmptyStateView(message: "Past lessons with notes, homework, or audio notes will appear here.")
                        } else {
                            ForEach(Array(appModel.recentLessons.prefix(8))) { session in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(appModel.studentName(for: session.studentID)) • \(AppFormat.shortDateFormatter.string(from: session.startAt))")
                                        .font(.title3.weight(.semibold))
                                    if !session.lessonNotes.isEmpty {
                                        Text(session.lessonNotes)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                    if !session.homework.isEmpty {
                                        Text("Homework: \(session.homework)")
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if let audioNoteFilename = session.audioNoteFilename {
                                        Button("Reveal Audio Note") {
                                            appModel.revealAudioNote(named: audioNoteFilename)
                                        }
                                        .buttonStyle(.link)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
    }
}

struct StudentsView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedStudentID: UUID?
    @State private var draft = StudentDraft()

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Students")
                        .font(.system(size: 24, weight: .semibold))
                    Spacer()
                    Button("New Student") {
                        selectedStudentID = nil
                        draft = appModel.newStudentDraft()
                    }
                }

                List(selection: $selectedStudentID) {
                    ForEach(appModel.studentsSorted) { student in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(student.fullName)
                                .font(.title3.weight(.semibold))
                            Text(student.subject)
                                .foregroundStyle(.secondary)
                            if !student.contactSummary.isEmpty {
                                Text(student.contactSummary)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(student.id)
                    }
                }
            }
            .frame(width: 320)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox("Student Details") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("New students start with your saved defaults from Settings.")
                                .foregroundStyle(.secondary)

                            TextField("Full name", text: $draft.fullName)
                            TextField("Subject", text: $draft.subject)
                            TextField("Phone number", text: $draft.phoneNumber)
                            TextField("Email address", text: $draft.email)

                            HStack {
                                Text("Hourly rate")
                                Spacer()
                                TextField(
                                    "0.00",
                                    value: $draft.hourlyRate,
                                    format: .number.precision(.fractionLength(2))
                                )
                                .frame(width: 160)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tutor notes")
                                TextEditor(text: $draft.notes)
                                    .frame(minHeight: 170)
                            }

                            HStack {
                                Button("Save Student") {
                                    if let savedStudent = appModel.saveStudent(draft) {
                                        selectedStudentID = savedStudent.id
                                        draft = StudentDraft(student: savedStudent)
                                    }
                                }
                                .disabled(!draft.isValid)

                                Button("Use Saved Defaults") {
                                    let previousName = draft.fullName
                                    draft = appModel.newStudentDraft()
                                    draft.fullName = previousName
                                }

                                Button("Delete Student") {
                                    guard let selectedStudentID else {
                                        return
                                    }
                                    appModel.deleteStudent(id: selectedStudentID)
                                    self.selectedStudentID = nil
                                    draft = appModel.newStudentDraft()
                                }
                                .disabled(selectedStudentID == nil)
                            }
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Past Lessons For This Student") {
                        VStack(alignment: .leading, spacing: 14) {
                            if let selectedStudentID {
                                let sessions = appModel.sessions(for: selectedStudentID)
                                if sessions.isEmpty {
                                    EmptyStateView(message: "Sessions for the selected student will appear here.")
                                } else {
                                    ForEach(sessions) { session in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("\(session.title) • \(AppFormat.dateTimeFormatter.string(from: session.startAt))")
                                                .font(.title3.weight(.semibold))
                                            Text("Payment: \(session.paymentStatus.title) • \(AppFormat.currency(session.paymentAmount))")
                                                .foregroundStyle(.secondary)
                                            if !session.lessonNotes.isEmpty {
                                                Text(session.lessonNotes)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(3)
                                            }
                                            if !session.homework.isEmpty {
                                                Text("Homework: \(session.homework)")
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 6)
                                    }
                                }
                            } else {
                                EmptyStateView(message: "Select a student to browse their lesson history.")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .onAppear {
            if let first = appModel.studentsSorted.first {
                selectedStudentID = first.id
                draft = StudentDraft(student: first)
            } else {
                draft = appModel.newStudentDraft()
            }
        }
        .onChange(of: selectedStudentID) { newValue in
            if let newValue, let student = appModel.student(for: newValue) {
                draft = StudentDraft(student: student)
            } else {
                draft = appModel.newStudentDraft()
            }
        }
        .onChange(of: appModel.settings) { _ in
            if selectedStudentID == nil {
                draft = appModel.newStudentDraft()
            }
        }
    }
}

struct SessionsView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedSessionID: UUID?
    @State private var filter: SessionFilter = .upcoming
    @State private var draft = SessionDraft()
    @State private var skipNextSelectionReset = false
    @State private var skipNextStudentRateRefresh = false

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Sessions")
                        .font(.system(size: 24, weight: .semibold))
                    Spacer()
                    Button("New Session") {
                        selectedSessionID = nil
                        draft = appModel.newSessionDraft()
                    }
                    .disabled(appModel.students.isEmpty)
                }

                Picker("Filter", selection: $filter) {
                    ForEach(SessionFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if appModel.students.isEmpty {
                    EmptyStateView(message: "Create at least one student before adding sessions.")
                } else {
                    List(selection: $selectedSessionID) {
                        ForEach(appModel.filteredSessions(using: filter)) { session in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.title)
                                    .font(.title3.weight(.semibold))
                                Text("\(appModel.studentName(for: session.studentID)) • \(AppFormat.dateTimeFormatter.string(from: session.startAt))")
                                    .foregroundStyle(.secondary)
                                Text("\(session.paymentStatus.title) • \(AppFormat.currency(session.paymentAmount))")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                            .tag(session.id)
                        }
                    }
                }
            }
            .frame(width: 370)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox("Session Details") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("New sessions start with your saved defaults from Settings. You can also copy an existing session and only change the dates.")
                                .foregroundStyle(.secondary)

                            Picker("Student", selection: Binding(
                                get: { draft.studentID ?? appModel.studentsSorted.first?.id ?? UUID() },
                                set: { draft.studentID = $0 }
                            )) {
                                ForEach(appModel.studentsSorted) { student in
                                    Text(student.fullName).tag(student.id)
                                }
                            }

                            TextField("Session type", text: $draft.title)
                            TextField("Location or meeting link", text: $draft.location)

                            DatePicker("Starts", selection: $draft.startAt)
                            DatePicker("Ends", selection: $draft.endAt)

                            Stepper("Reminder: \(draft.reminderMinutesBefore) minutes before", value: $draft.reminderMinutesBefore, in: 0...1_440, step: 5)

                            HStack {
                                Text("Payment amount")
                                Spacer()
                                TextField(
                                    "0.00",
                                    value: $draft.paymentAmount,
                                    format: .number.precision(.fractionLength(2))
                                )
                                .frame(width: 160)
                            }

                            Picker("Payment status", selection: $draft.paymentStatus) {
                                ForEach(PaymentStatus.allCases) { status in
                                    Text(status.title).tag(status)
                                }
                            }

                            TextField("Payment method", text: $draft.paymentMethod)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lesson notes")
                                TextEditor(text: $draft.lessonNotes)
                                    .frame(minHeight: 140)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Homework or next steps")
                                TextEditor(text: $draft.homework)
                                    .frame(minHeight: 110)
                            }
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Voice Notes") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Record a quick lesson recap with your Mac microphone and attach it to this session.")
                                .foregroundStyle(.secondary)

                            HStack {
                                if appModel.audioRecorder.isRecording {
                                    Button("Stop Recording") {
                                        draft.audioNoteFilename = appModel.stopRecording()
                                    }
                                } else {
                                    Button("Record Voice Note") {
                                        let targetID = draft.id ?? UUID()
                                        if draft.id == nil {
                                            draft.id = targetID
                                        }
                                        appModel.startRecording(for: targetID)
                                    }
                                }

                                if let audioNoteFilename = draft.audioNoteFilename {
                                    Button("Reveal Audio File") {
                                        appModel.revealAudioNote(named: audioNoteFilename)
                                    }
                                }
                            }

                            if let audioNoteFilename = draft.audioNoteFilename {
                                Text("Attached file: \(audioNoteFilename)")
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            if let errorMessage = appModel.audioRecorder.errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    }

                    HStack {
                        Button("Save Session") {
                            if let savedSession = appModel.saveSession(draft) {
                                selectedSessionID = savedSession.id
                                draft = SessionDraft(session: savedSession)
                            }
                        }
                        .disabled(appModel.students.isEmpty || !draft.isValid)

                        Button("Use Saved Defaults") {
                            applySavedSessionDefaults()
                        }
                        .disabled(appModel.students.isEmpty)

                        Button("Copy Session") {
                            copySelectedSession()
                        }
                        .disabled(selectedSessionID == nil)

                        Button("Delete Session") {
                            guard let selectedSessionID else {
                                return
                            }
                            appModel.deleteSession(id: selectedSessionID)
                            self.selectedSessionID = nil
                            draft = appModel.newSessionDraft()
                        }
                        .disabled(selectedSessionID == nil)
                    }
                }
            }
        }
        .onAppear {
            if let first = appModel.filteredSessions(using: filter).first {
                selectedSessionID = first.id
                draft = SessionDraft(session: first)
            } else {
                draft = appModel.newSessionDraft()
            }
        }
        .onChange(of: selectedSessionID) { newValue in
            if let newValue, let session = appModel.sessions.first(where: { $0.id == newValue }) {
                draft = SessionDraft(session: session)
            } else if skipNextSelectionReset {
                skipNextSelectionReset = false
            } else {
                draft = appModel.newSessionDraft(preferredStudentID: draft.studentID)
            }
        }
        .onChange(of: filter) { _ in
            if let first = appModel.filteredSessions(using: filter).first {
                selectedSessionID = first.id
                draft = SessionDraft(session: first)
            } else {
                selectedSessionID = nil
                draft = appModel.newSessionDraft(preferredStudentID: draft.studentID)
            }
        }
        .onChange(of: draft.studentID) { newValue in
            if skipNextStudentRateRefresh {
                skipNextStudentRateRefresh = false
                return
            }

            guard selectedSessionID == nil,
                  let newValue,
                  let student = appModel.student(for: newValue) else {
                return
            }
            draft.paymentAmount = student.hourlyRate
        }
        .onChange(of: appModel.settings) { _ in
            guard selectedSessionID == nil else {
                return
            }
            applySavedSessionDefaults()
        }
    }

    private func applySavedSessionDefaults() {
        let currentStudentID = draft.studentID
        let currentStartAt = draft.startAt
        let currentEndAt = draft.endAt
        let currentReminderMinutesBefore = draft.reminderMinutesBefore
        let currentPaymentStatus = draft.paymentStatus
        let currentLessonNotes = draft.lessonNotes
        let currentHomework = draft.homework
        let currentAudioNoteFilename = draft.audioNoteFilename
        let currentCreatedAt = draft.createdAt
        let currentID = draft.id

        draft = appModel.newSessionDraft(preferredStudentID: currentStudentID)
        draft.id = currentID
        draft.createdAt = currentCreatedAt
        draft.startAt = currentStartAt
        draft.endAt = currentEndAt
        draft.reminderMinutesBefore = currentReminderMinutesBefore
        draft.paymentStatus = currentPaymentStatus
        draft.lessonNotes = currentLessonNotes
        draft.homework = currentHomework
        draft.audioNoteFilename = currentAudioNoteFilename
    }

    private func copySelectedSession() {
        guard let selectedSessionID,
              let copiedDraft = appModel.copiedSessionDraft(from: selectedSessionID) else {
            return
        }

        skipNextSelectionReset = true
        skipNextStudentRateRefresh = true
        self.selectedSessionID = nil
        draft = copiedDraft
    }
}

struct PaymentsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var timeframe: IncomeTimeframe = .monthly

    var body: some View {
        let summary = appModel.paymentSummary(in: timeframe)
        let openSessions = appModel.paymentAttentionSessions(in: timeframe)
        let reports = appModel.studentPaymentReports(in: timeframe)
        let paymentSessions = appModel.sessions(in: timeframe)

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Payments")
                    .font(.system(size: 28, weight: .semibold))

                Picker("Reporting timeframe", selection: $timeframe) {
                    ForEach(IncomeTimeframe.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 18
                ) {
                    MetricCard(
                        title: "Collected",
                        value: AppFormat.currency(summary.collectedAmount),
                        subtitle: "\(summary.paidSessionCount) paid session\(summary.paidSessionCount == 1 ? "" : "s")"
                    )
                    MetricCard(
                        title: "Awaiting",
                        value: AppFormat.currency(summary.unpaidAmount),
                        subtitle: "\(summary.unpaidSessionCount) unpaid session\(summary.unpaidSessionCount == 1 ? "" : "s")"
                    )
                    MetricCard(
                        title: "Partial",
                        value: AppFormat.currency(summary.partiallyPaidSessionValue),
                        subtitle: "\(summary.partiallyPaidSessionCount) session\(summary.partiallyPaidSessionCount == 1 ? "" : "s") marked partial"
                    )
                    MetricCard(
                        title: "Tracked",
                        value: AppFormat.currency(paymentSessions.reduce(0) { $0 + $1.paymentAmount }),
                        subtitle: timeframe.subtitle
                    )
                }

                GroupBox("Student Payment Report") {
                    VStack(alignment: .leading, spacing: 14) {
                        if reports.isEmpty {
                            EmptyStateView(message: "Payment reporting will populate here once your sessions fall into the selected timeframe.")
                        } else {
                            ForEach(reports) { report in
                                StudentPaymentReportRow(report: report)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }

                GroupBox("Sessions Requiring Attention") {
                    VStack(alignment: .leading, spacing: 14) {
                        if openSessions.isEmpty {
                            EmptyStateView(message: "No unpaid or partially paid sessions in the selected timeframe.")
                        } else {
                            ForEach(openSessions) { session in
                                PaymentSessionRow(
                                    session: session,
                                    studentName: appModel.studentName(for: session.studentID)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }

                GroupBox("Payment Activity") {
                    VStack(alignment: .leading, spacing: 14) {
                        if paymentSessions.isEmpty {
                            EmptyStateView(message: "No payment activity for the selected timeframe yet.")
                        } else {
                            ForEach(Array(paymentSessions.prefix(12))) { session in
                                PaymentSessionRow(
                                    session: session,
                                    studentName: appModel.studentName(for: session.studentID)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var defaultSubject = AppSettings.defaultStudentSubjectValue
    @State private var defaultHourlyRate = AppSettings.defaultStudentHourlyRateValue
    @State private var defaultSessionType = AppSettings.defaultSessionTypeValue
    @State private var defaultSessionLocation = AppSettings.defaultSessionLocationValue
    @State private var defaultSessionPaymentMethod = AppSettings.defaultSessionPaymentMethodValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.system(size: 28, weight: .semibold))

                GroupBox("Student Defaults") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("These values prefill new student records, so you do not have to type them each time.")
                            .foregroundStyle(.secondary)

                        TextField("Default subject", text: $defaultSubject)

                        HStack {
                            Text("Default hourly rate")
                            Spacer()
                            TextField(
                                "0.00",
                                value: $defaultHourlyRate,
                                format: .number.precision(.fractionLength(2))
                            )
                            .frame(width: 160)
                        }

                    }
                    .padding(.top, 8)
                }

                GroupBox("Session Defaults") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("These values prefill new sessions. The copy action in the Sessions tab duplicates an existing lesson so you only need to change the dates.")
                            .foregroundStyle(.secondary)

                        TextField("Default session type", text: $defaultSessionType)
                        TextField("Default location", text: $defaultSessionLocation)
                        TextField("Default payment method", text: $defaultSessionPaymentMethod)
                    }
                    .padding(.top, 8)
                }

                HStack {
                    Button("Save All Defaults") {
                        appModel.saveSettings(
                            defaultSubject: defaultSubject,
                            defaultHourlyRate: defaultHourlyRate,
                            defaultSessionType: defaultSessionType,
                            defaultSessionLocation: defaultSessionLocation,
                            defaultSessionPaymentMethod: defaultSessionPaymentMethod
                        )
                    }

                    Button("Reload Saved Values") {
                        syncFromSettings()
                    }
                }

                GroupBox("Workspace & Access") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Reminder access: \(appModel.reminderStatusText)")
                        Text("Global hotkey: \(appModel.activeHotKeyDescription)")
                        Text("The background launcher keeps this shortcut available so it can reopen TutorTable, not just bring it forward.")
                            .foregroundStyle(.secondary)
                        Text("Local data folder: \(appModel.storagePaths.rootDirectory.path)")
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        HStack {
                            Button("Open Data Folder") {
                                appModel.openDataFolder()
                            }

                            Button("Refresh Hotkey Status") {
                                appModel.refreshHotKeyStatus()
                            }

                            Button("Add Sample Data") {
                                appModel.addSampleData()
                            }
                            .disabled(appModel.hasAnyRecords)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            syncFromSettings()
        }
        .onChange(of: appModel.settings) { _ in
            syncFromSettings()
        }
    }

    private func syncFromSettings() {
        defaultSubject = appModel.settings.defaultStudentSubject
        defaultHourlyRate = appModel.settings.defaultStudentHourlyRate
        defaultSessionType = appModel.settings.defaultSessionType
        defaultSessionLocation = appModel.settings.defaultSessionLocation
        defaultSessionPaymentMethod = appModel.settings.defaultSessionPaymentMethod
    }
}

struct BannerView: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.system(size: 15.5, weight: .medium))
                .lineLimit(2)
            Spacer()
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.12))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct IncomeMetricCard: View {
    @Binding var timeframe: IncomeTimeframe
    let total: Double
    let paidSessions: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INCOME EARNED")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker("Income timeframe", selection: $timeframe) {
                ForEach(IncomeTimeframe.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Text(AppFormat.currency(total))
                .font(.system(size: 30, weight: .semibold))

            Text("\(timeframe.subtitle) • \(paidSessions) paid session\(paidSessions == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SessionSummaryRow: View {
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(trailing)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }
}

struct StudentPaymentReportRow: View {
    let report: StudentPaymentReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(report.studentName)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(report.paidSessionCount) paid • \(report.openSessionCount) open")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                PaymentMiniMetric(title: "Collected", value: AppFormat.currency(report.collectedAmount))
                PaymentMiniMetric(title: "Awaiting", value: AppFormat.currency(report.unpaidAmount))
                PaymentMiniMetric(title: "Partial", value: AppFormat.currency(report.partiallyPaidSessionValue))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct PaymentSessionRow: View {
    let session: LessonSession
    let studentName: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title)
                    .font(.title3.weight(.semibold))
                Text("\(studentName) • \(AppFormat.dateTimeFormatter.string(from: session.startAt))")
                    .foregroundStyle(.secondary)
                if !session.paymentMethod.isEmpty {
                    Text("Method: \(session.paymentMethod)")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(AppFormat.currency(session.paymentAmount))
                    .font(.headline)
                Text(session.paymentStatus.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(paymentStatusColor(session.paymentStatus))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func paymentStatusColor(_ status: PaymentStatus) -> Color {
        switch status {
        case .paid:
            return .green
        case .partiallyPaid:
            return .orange
        case .unpaid:
            return .red
        }
    }
}

struct PaymentMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
