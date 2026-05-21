import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedSection: AppSection = .overview
    @AppStorage("sidebarCollapsed") private var isSidebarCollapsed = false

    var body: some View {
        GeometryReader { proxy in
            let isCompactShell = proxy.size.width < 1240
            let expandedSidebarWidth: CGFloat = isCompactShell ? 242 : 280
            let collapsedSidebarWidth: CGFloat = 92
            let sidebarWidth: CGFloat = isSidebarCollapsed ? collapsedSidebarWidth : expandedSidebarWidth
            let outerPadding: CGFloat = isCompactShell ? 12 : 18
            let contentPadding: CGFloat = isCompactShell ? 18 : 28

            ZStack {
                AppTheme.appBackground.ignoresSafeArea()

                LinearGradient(
                    colors: [AppTheme.accent.opacity(0.14), .clear, AppTheme.accentSecondary.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                HStack(spacing: 0) {
                    AppSidebar(
                        selectedSection: $selectedSection,
                        isCollapsed: $isSidebarCollapsed
                    )
                        .frame(width: sidebarWidth)

                    VStack(spacing: 0) {
                        if let bannerMessage = appModel.bannerMessage {
                            BannerView(message: bannerMessage) {
                                appModel.dismissBanner()
                            }
                        }

                        Group {
                            switch selectedSection {
                            case .overview:
                                OverviewView()
                            case .calendar:
                                LessonsCalendarView()
                            case .payments:
                                PaymentsView()
                            case .students:
                                StudentsView()
                            case .sessions:
                                SessionsView()
                            case .settings:
                                SettingsView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(contentPadding)
                        .background(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .fill(AppTheme.contentBackground.opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .padding(outerPadding)
                    }
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: isSidebarCollapsed)
            }
        }
        .font(.system(size: 15.5))
        .controlSize(.large)
        .tint(AppTheme.accent)
        .foregroundStyle(.white)
        .groupBoxStyle(TutorTablePanelGroupBoxStyle())
        .preferredColorScheme(.dark)
        .frame(minWidth: 1080, minHeight: 760)
    }
}

struct OverviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var incomeTimeframe: IncomeTimeframe = .monthly

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 1120

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OverviewHeroView(
                        upcomingCount: appModel.upcomingSessions.count,
                        studentCount: appModel.students.count,
                        outstandingBalance: appModel.outstandingBalance,
                        incomeTimeframe: $incomeTimeframe,
                        incomeTotal: appModel.incomeEarned(in: incomeTimeframe),
                        paidSessions: appModel.paidSessionCount(in: incomeTimeframe)
                    )

                    if !appModel.hasAnyRecords {
                        GroupBox("Getting Started") {
                            Text("TutorTable is ready. Add your first student or visit Settings to load sample data and adjust your default lesson subject and rate.")
                                .foregroundStyle(AppTheme.mutedText)
                                .padding(.top, 8)
                        }
                    }

                    if isCompact {
                        VStack(alignment: .leading, spacing: 22) {
                            overviewVoiceSection
                            recentLessonMemorySection
                            upcomingSessionsSection
                        }
                    } else {
                        HStack(alignment: .top, spacing: 22) {
                            VStack(alignment: .leading, spacing: 22) {
                                overviewVoiceSection
                                upcomingSessionsSection
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            recentLessonMemorySection
                                .frame(width: 350, alignment: .top)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    private var overviewVoiceSection: some View {
        VoiceCommandPanelView(
            voiceCommandManager: appModel.voiceCommandManager,
            mode: .compact
        )
        .environmentObject(appModel)
    }

    private var upcomingSessionsSection: some View {
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
    }

    private var recentLessonMemorySection: some View {
        GroupBox("Recent Lesson Memory") {
            VStack(alignment: .leading, spacing: 14) {
                if appModel.recentLessons.isEmpty {
                    EmptyStateView(message: "Past lessons with notes or homework will appear here.")
                } else {
                    ForEach(Array(appModel.recentLessons.prefix(8))) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(appModel.studentName(for: session.studentID)) • \(AppFormat.shortDateFormatter.string(from: session.startAt))")
                                .font(.title3.weight(.semibold))
                            if !session.lessonNotes.isEmpty {
                                Text(session.lessonNotes)
                                    .foregroundStyle(AppTheme.mutedText)
                                    .lineLimit(3)
                            }
                            if !session.homework.isEmpty {
                                Text("Homework: \(session.homework)")
                                    .foregroundStyle(AppTheme.mutedText)
                                    .lineLimit(2)
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
                    .appInteractiveButton()
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
                .scrollContentBackground(.hidden)
                .listStyle(.inset(alternatesRowBackgrounds: false))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.panelBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.panelBorder, lineWidth: 1)
                )
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

                            ViewThatFits(in: .horizontal) {
                                HStack {
                                    studentEditorButtons
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    studentEditorButtons
                                }
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
                    .appInteractiveButton()
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
                    .scrollContentBackground(.hidden)
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(AppTheme.panelBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.panelBorder, lineWidth: 1)
                    )
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

                            if draft.paymentStatus == .creditCovered {
                                Text("This session is currently covered by advance credit. If you mark it as paid manually, that credit will stay available for another lesson.")
                                    .foregroundStyle(.secondary)
                            }

                            Picker(
                                "Payment status",
                                selection: Binding(
                                    get: { draft.paymentStatus == .paid ? .paid : .unpaid },
                                    set: { draft.paymentStatus = $0 }
                                )
                            ) {
                                ForEach(PaymentStatus.manualCases) { status in
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

                    ViewThatFits(in: .horizontal) {
                        HStack {
                            sessionEditorButtons
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sessionEditorButtons
                        }
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

    @ViewBuilder
    private var sessionEditorButtons: some View {
        Button("Save Session") {
            if let savedSession = appModel.saveSession(draft) {
                selectedSessionID = savedSession.id
                draft = SessionDraft(session: savedSession)
            }
        }
        .disabled(appModel.students.isEmpty || !draft.isValid)
        .appInteractiveButton()

        Button("Use Saved Defaults") {
            applySavedSessionDefaults()
        }
        .disabled(appModel.students.isEmpty)
        .appInteractiveButton()

        Button("Copy Session") {
            copySelectedSession()
        }
        .disabled(selectedSessionID == nil)
        .appInteractiveButton()

        Button("Delete Session") {
            guard let selectedSessionID else {
                return
            }
            appModel.deleteSession(id: selectedSessionID)
            self.selectedSessionID = nil
            draft = appModel.newSessionDraft()
        }
        .disabled(selectedSessionID == nil)
        .appInteractiveButton()
    }
}

private extension StudentsView {
    @ViewBuilder
    var studentEditorButtons: some View {
        Button("Save Student") {
            if let savedStudent = appModel.saveStudent(draft) {
                selectedStudentID = savedStudent.id
                draft = StudentDraft(student: savedStudent)
            }
        }
        .disabled(!draft.isValid)
        .appInteractiveButton()

        Button("Use Saved Defaults") {
            let previousName = draft.fullName
            draft = appModel.newStudentDraft()
            draft.fullName = previousName
        }
        .appInteractiveButton()

        Button("Delete Student") {
            guard let selectedStudentID else {
                return
            }
            appModel.deleteStudent(id: selectedStudentID)
            self.selectedStudentID = nil
            draft = appModel.newStudentDraft()
        }
        .disabled(selectedStudentID == nil)
        .appInteractiveButton()
    }
}

struct PaymentsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var timeframe: IncomeTimeframe = .monthly
    @State private var selectedCreditPurchaseID: UUID?
    @State private var creditDraft = CreditPurchaseDraft()

    var body: some View {
        let summary = appModel.paymentSummary(in: timeframe)
        let openSessions = appModel.paymentAttentionSessions(in: timeframe)
        let reports = appModel.studentPaymentReports(in: timeframe)
        let paymentSessions = appModel.sessions(in: timeframe)
        let creditPurchases = appModel.creditPurchases(in: timeframe)
        let creditStatuses = appModel.creditStatuses()
        let activeCreditHours = creditStatuses.reduce(0) { $0 + $1.remainingHours }
        let studentsWithCredit = creditStatuses.filter { $0.remainingHours > 0 }.count
        let selectedStudent = creditDraft.studentID.flatMap { appModel.student(for: $0) }
        let standardValue = creditDraft.standardValue(for: selectedStudent)
        let impliedDiscount = creditDraft.impliedDiscount(for: selectedStudent)
        let effectiveHourlyRate = creditDraft.purchasedHours > 0 ? (creditDraft.amountPaid / creditDraft.purchasedHours) : 0

        return GeometryReader { proxy in
            let isCompact = proxy.size.width < 1180

            ScrollView {
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
                        columns: [GridItem(.adaptive(minimum: 230, maximum: 340), spacing: 18)],
                        spacing: 18
                    ) {
                        MetricCard(
                            title: "Total Earned",
                            value: AppFormat.currency(summary.totalEarnedAmount),
                            subtitle: "\(summary.paidSessionCount + summary.creditCoveredSessionCount) earned session\(summary.paidSessionCount + summary.creditCoveredSessionCount == 1 ? "" : "s")"
                        )
                        MetricCard(
                            title: "Directly Paid",
                            value: AppFormat.currency(summary.collectedAmount),
                            subtitle: "\(summary.paidSessionCount) paid session\(summary.paidSessionCount == 1 ? "" : "s")"
                        )
                        MetricCard(
                            title: "Credit Received",
                            value: AppFormat.currency(summary.creditReceivedAmount),
                            subtitle: "\(summary.creditPurchaseCount) advance payment\(summary.creditPurchaseCount == 1 ? "" : "s")"
                        )
                        MetricCard(
                            title: "Credit Covered",
                            value: AppFormat.currency(summary.creditCoveredAmount),
                            subtitle: "\(summary.creditCoveredSessionCount) session\(summary.creditCoveredSessionCount == 1 ? "" : "s") covered"
                        )
                        MetricCard(
                            title: "Awaiting",
                            value: AppFormat.currency(summary.unpaidAmount),
                            subtitle: "\(summary.unpaidSessionCount) unpaid session\(summary.unpaidSessionCount == 1 ? "" : "s")"
                        )
                        MetricCard(
                            title: "Active Credit",
                            value: AppFormat.hours(activeCreditHours),
                            subtitle: studentsWithCredit == 0 ? "No student has remaining credit" : "\(studentsWithCredit) student balance\(studentsWithCredit == 1 ? "" : "s") still active"
                        )
                    }

                    Group {
                        if isCompact {
                            VStack(alignment: .leading, spacing: 18) {
                                creditEditorCard(
                                    selectedStudent: selectedStudent,
                                    standardValue: standardValue,
                                    impliedDiscount: impliedDiscount,
                                    effectiveHourlyRate: effectiveHourlyRate,
                                    stackInternals: true
                                )
                                creditActivityCard(creditPurchases: creditPurchases)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 18) {
                                creditEditorCard(
                                    selectedStudent: selectedStudent,
                                    standardValue: standardValue,
                                    impliedDiscount: impliedDiscount,
                                    effectiveHourlyRate: effectiveHourlyRate,
                                    stackInternals: false
                                )
                                creditActivityCard(creditPurchases: creditPurchases)
                            }
                        }
                    }

                    GroupBox("Student Credit Balances") {
                        VStack(alignment: .leading, spacing: 14) {
                            if creditStatuses.isEmpty {
                                EmptyStateView(message: "Student credit balances will appear here after you log an advance payment.")
                            } else {
                                ForEach(creditStatuses) { status in
                                    StudentCreditStatusRow(status: status)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
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
                                EmptyStateView(message: "No unpaid sessions in the selected timeframe.")
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

                    GroupBox("Session Payment Activity") {
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
        .onAppear {
            if appModel.students.isEmpty {
                creditDraft = CreditPurchaseDraft()
            } else if let selectedCreditPurchaseID,
                      let purchase = appModel.creditPurchases.first(where: { $0.id == selectedCreditPurchaseID }) {
                creditDraft = CreditPurchaseDraft(purchase: purchase)
            } else {
                creditDraft = appModel.newCreditPurchaseDraft()
            }
        }
        .onChange(of: appModel.students.count) { _ in
            guard selectedCreditPurchaseID == nil else {
                return
            }

            if appModel.students.isEmpty {
                creditDraft = CreditPurchaseDraft()
            } else if creditDraft.studentID == nil {
                creditDraft = appModel.newCreditPurchaseDraft()
            }
        }
        .onChange(of: selectedCreditPurchaseID) { newValue in
            guard let newValue,
                  let purchase = appModel.creditPurchases.first(where: { $0.id == newValue }) else {
                return
            }

            creditDraft = CreditPurchaseDraft(purchase: purchase)
        }
        .onChange(of: creditDraft.purchasedAt) { newValue in
            guard let expirationDate = creditDraft.expirationDate else {
                return
            }

            let purchaseDay = Calendar.current.startOfDay(for: newValue)
            let expirationDay = Calendar.current.startOfDay(for: expirationDate)
            if expirationDay < purchaseDay {
                creditDraft.expirationDate = purchaseDay
            }
        }
    }

    @ViewBuilder
    private func creditEditorCard(
        selectedStudent: Student?,
        standardValue: Double,
        impliedDiscount: Double,
        effectiveHourlyRate: Double,
        stackInternals: Bool
    ) -> some View {
        GroupBox("Add Or Edit Advance Credit") {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent.opacity(0.92), AppTheme.accentSecondary.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 54)

                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Advance Credit")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Log prepaid hours, optional expiry rules, and payment details in one place. TutorTable will keep credit coverage and reporting in step automatically.")
                            .foregroundStyle(AppTheme.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                if appModel.students.isEmpty {
                    EmptyStateView(message: "Create a student before logging advance credit.")
                } else {
                    if stackInternals {
                        stackedCreditEditorLayout(
                            selectedStudent: selectedStudent,
                            standardValue: standardValue,
                            impliedDiscount: impliedDiscount,
                            effectiveHourlyRate: effectiveHourlyRate
                        )
                    } else {
                        ViewThatFits(in: .horizontal) {
                            wideCreditEditorLayout(
                                selectedStudent: selectedStudent,
                                standardValue: standardValue,
                                impliedDiscount: impliedDiscount,
                                effectiveHourlyRate: effectiveHourlyRate
                            )

                            stackedCreditEditorLayout(
                                selectedStudent: selectedStudent,
                                standardValue: standardValue,
                                impliedDiscount: impliedDiscount,
                                effectiveHourlyRate: effectiveHourlyRate
                            )
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func wideCreditEditorLayout(
        selectedStudent: Student?,
        standardValue: Double,
        impliedDiscount: Double,
        effectiveHourlyRate: Double
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            creditEditorFields(standardValue: standardValue)
                .frame(maxWidth: .infinity, alignment: .leading)

            creditSnapshotCard(
                selectedStudent: selectedStudent,
                standardValue: standardValue,
                impliedDiscount: impliedDiscount,
                effectiveHourlyRate: effectiveHourlyRate
            )
            .frame(width: 320, alignment: .top)
        }
    }

    @ViewBuilder
    private func stackedCreditEditorLayout(
        selectedStudent: Student?,
        standardValue: Double,
        impliedDiscount: Double,
        effectiveHourlyRate: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            creditEditorFields(standardValue: standardValue)
            creditSnapshotCard(
                selectedStudent: selectedStudent,
                standardValue: standardValue,
                impliedDiscount: impliedDiscount,
                effectiveHourlyRate: effectiveHourlyRate
            )
        }
    }

    private func creditEditorFields(standardValue: Double) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            PaymentFieldCard(title: "Student") {
                Picker("Student", selection: Binding(
                    get: { creditDraft.studentID ?? appModel.studentsSorted.first?.id ?? UUID() },
                    set: { creditDraft.studentID = $0 }
                )) {
                    ForEach(appModel.studentsSorted) { student in
                        Text(student.fullName).tag(student.id)
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 360), spacing: 14)],
                spacing: 14
            ) {
                PaymentFieldCard(title: "Payment Date", minHeight: 112) {
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker(
                            "Payment date",
                            selection: $creditDraft.purchasedAt,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                }

                PaymentFieldCard(title: "Expiration", minHeight: 112) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set expiration date", isOn: expirationToggleBinding)

                        if creditDraft.hasExpiration {
                            DatePicker(
                                "Expiration date",
                                selection: expirationDateBinding,
                                in: Calendar.current.startOfDay(for: creditDraft.purchasedAt)...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        } else {
                            Text("No expiration")
                                .foregroundStyle(AppTheme.mutedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                }

                PaymentFieldCard(title: "Hours Bought", minHeight: 112) {
                    TextField(
                        "0.00",
                        value: $creditDraft.purchasedHours,
                        format: .number.precision(.fractionLength(2))
                    )
                    .textFieldStyle(.roundedBorder)
                }

                PaymentFieldCard(title: "Amount Paid", minHeight: 112) {
                    TextField(
                        "0.00",
                        value: $creditDraft.amountPaid,
                        format: .number.precision(.fractionLength(2))
                    )
                    .textFieldStyle(.roundedBorder)
                }
            }

            PaymentFieldCard(title: "Payment Note") {
                TextEditor(text: $creditDraft.note)
                    .frame(minHeight: 118)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.panelBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.panelBorder, lineWidth: 1)
                    )
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                paymentActionButton("Set Standard Price", systemImage: "equal.circle", style: .secondary) {
                    creditDraft.amountPaid = standardValue
                }
                .disabled(creditDraft.studentID == nil || creditDraft.purchasedHours <= 0)

                paymentActionButton("New Credit Entry", systemImage: "plus.circle", style: .secondary) {
                    selectedCreditPurchaseID = nil
                    creditDraft = appModel.newCreditPurchaseDraft()
                }
                .disabled(appModel.students.isEmpty)

                paymentActionButton("Delete Credit Entry", systemImage: "trash", style: .destructive) {
                    guard let selectedCreditPurchaseID else {
                        return
                    }
                    appModel.deleteCreditPurchase(id: selectedCreditPurchaseID)
                    self.selectedCreditPurchaseID = nil
                    creditDraft = appModel.newCreditPurchaseDraft()
                }
                .disabled(selectedCreditPurchaseID == nil)

                paymentActionButton("Save Credit Entry", systemImage: "checkmark.circle.fill", style: .accent) {
                    if let savedPurchase = appModel.saveCreditPurchase(creditDraft) {
                        selectedCreditPurchaseID = savedPurchase.id
                        creditDraft = CreditPurchaseDraft(purchase: savedPurchase)
                    }
                }
                .disabled(appModel.students.isEmpty || !creditDraft.isValid)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditSnapshotCard(
        selectedStudent: Student?,
        standardValue: Double,
        impliedDiscount: Double,
        effectiveHourlyRate: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Payment Snapshot")
                    .font(.system(size: 18, weight: .semibold))

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(AppFormat.currency(creditDraft.amountPaid))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Spacer()
                    Text(AppFormat.hours(creditDraft.purchasedHours))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText)
                }

                Text(creditDraft.expirationDate.map { "Expires \(AppFormat.shortDateFormatter.string(from: $0))" } ?? "No expiration date")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(creditDraft.expirationDate == nil ? AppTheme.mutedText : AppTheme.accent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.20), AppTheme.panelBackgroundSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                CreditSnapshotMetricCard(
                    title: "Standard",
                    value: AppFormat.currency(standardValue)
                )
                CreditSnapshotMetricCard(
                    title: "Discount",
                    value: AppFormat.currency(impliedDiscount)
                )
                CreditSnapshotMetricCard(
                    title: "Hourly",
                    value: creditDraft.purchasedHours > 0 ? AppFormat.currency(effectiveHourlyRate) : "Not set"
                )
                CreditSnapshotMetricCard(
                    title: "Student Rate",
                    value: selectedStudent.map { AppFormat.currency($0.hourlyRate) } ?? "Not set"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                PaymentInfoRow(
                    label: "Coverage rule",
                    value: creditDraft.expirationDate == nil ? "Stays active until used" : "Stops after the expiry date"
                )
                PaymentInfoRow(
                    label: "Best for",
                    value: creditDraft.expirationDate == nil ? "Open-ended prepaid credit" : "Monthly or annual packages"
                )
            }

            Text("TutorTable will apply this credit to eligible sessions automatically. If an expiration date is set, future lessons after that day will no longer use this balance.")
                .foregroundStyle(AppTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.panelBackgroundSoft.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func creditActivityCard(creditPurchases: [StudentCreditPurchase]) -> some View {
        GroupBox("Credit Purchase Activity") {
            VStack(alignment: .leading, spacing: 14) {
                if creditPurchases.isEmpty {
                    EmptyStateView(message: "Advance payments in the selected timeframe will appear here.")
                } else {
                    ForEach(creditPurchases) { purchase in
                        Button {
                            selectedCreditPurchaseID = purchase.id
                            creditDraft = CreditPurchaseDraft(purchase: purchase)
                        } label: {
                            CreditPurchaseRow(
                                purchase: purchase,
                                studentName: appModel.studentName(for: purchase.studentID),
                                isSelected: purchase.id == selectedCreditPurchaseID
                            )
                        }
                        .buttonStyle(.plain)
                        .appInteractiveButton()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var expirationToggleBinding: Binding<Bool> {
        Binding(
            get: { creditDraft.hasExpiration },
            set: { shouldEnable in
                if shouldEnable {
                    creditDraft.expirationDate = defaultCreditExpirationDate()
                } else {
                    creditDraft.expirationDate = nil
                }
            }
        )
    }

    private var expirationDateBinding: Binding<Date> {
        Binding(
            get: { creditDraft.expirationDate ?? defaultCreditExpirationDate() },
            set: { creditDraft.expirationDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private func defaultCreditExpirationDate() -> Date {
        let baseDate = Calendar.current.startOfDay(for: creditDraft.purchasedAt)
        return Calendar.current.date(byAdding: .month, value: 1, to: baseDate) ?? baseDate
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

                GroupBox("Apple Calendar Integration") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("TutorTable can sync sessions into a calendar that is already signed into Apple Calendar on this Mac. Once connected, new sessions, updates, and deletes stay in step automatically.")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Status")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(appModel.appleCalendarStatusText)
                                .font(.title3.weight(.semibold))
                            Text(appModel.appleCalendarDetailText)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !appModel.availableAppleCalendars.isEmpty {
                            Picker(
                                "Sync calendar",
                                selection: Binding(
                                    get: {
                                        let currentIdentifier = appModel.selectedAppleCalendarIdentifier
                                        if currentIdentifier.isEmpty {
                                            return appModel.availableAppleCalendars.first?.id ?? ""
                                        }
                                        return currentIdentifier
                                    },
                                    set: { newValue in
                                        appModel.setAppleCalendar(identifier: newValue)
                                    }
                                )
                            ) {
                                ForEach(appModel.availableAppleCalendars) { calendar in
                                    Text(calendar.displayName).tag(calendar.id)
                                }
                            }
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack {
                                appleCalendarButtons
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                appleCalendarButtons
                            }
                        }
                    }
                    .padding(.top, 8)
                }

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

                ViewThatFits(in: .horizontal) {
                    HStack {
                        settingsPrimaryButtons
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        settingsPrimaryButtons
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

                        ViewThatFits(in: .horizontal) {
                            HStack {
                                settingsUtilityButtons
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                settingsUtilityButtons
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            syncFromSettings()
            appModel.refreshAppleCalendarIntegration()
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

    @ViewBuilder
    private var appleCalendarButtons: some View {
        Button(appModel.isAppleCalendarSyncEnabled ? "Sync Existing Sessions Now" : "Connect Apple Calendar") {
            if appModel.isAppleCalendarSyncEnabled {
                appModel.syncAllSessionsToAppleCalendar(showSuccessBanner: true)
            } else {
                Task {
                    await appModel.requestAppleCalendarAccess()
                }
            }
        }
        .appInteractiveButton()

        Button("Refresh Calendars") {
            appModel.refreshAppleCalendarIntegration()
        }
        .appInteractiveButton()

        Button("Turn Off Sync") {
            appModel.disableAppleCalendarSync()
        }
        .disabled(!appModel.isAppleCalendarSyncEnabled)
        .appInteractiveButton()
    }

    @ViewBuilder
    private var settingsPrimaryButtons: some View {
        Button("Save All Defaults") {
            appModel.saveSettings(
                defaultSubject: defaultSubject,
                defaultHourlyRate: defaultHourlyRate,
                defaultSessionType: defaultSessionType,
                defaultSessionLocation: defaultSessionLocation,
                defaultSessionPaymentMethod: defaultSessionPaymentMethod
            )
        }
        .appInteractiveButton()

        Button("Reload Saved Values") {
            syncFromSettings()
        }
        .appInteractiveButton()
    }

    @ViewBuilder
    private var settingsUtilityButtons: some View {
        Button("Open Data Folder") {
            appModel.openDataFolder()
        }
        .appInteractiveButton()

        Button("Refresh Hotkey Status") {
            appModel.refreshHotKeyStatus()
        }
        .appInteractiveButton()

        Button("Add Sample Data") {
            appModel.addSampleData()
        }
        .disabled(appModel.hasAnyRecords)
        .appInteractiveButton()
    }
}

struct OverviewHeroView: View {
    let upcomingCount: Int
    let studentCount: Int
    let outstandingBalance: Double
    @Binding var incomeTimeframe: IncomeTimeframe
    let incomeTotal: Double
    let paidSessions: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Overview")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("A clearer command center for your tutoring week, built around the pages you actually use most.")
                    .font(.system(size: 16.5))
                    .foregroundStyle(AppTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 340), spacing: 18)],
                spacing: 18
            ) {
                MiniHeroMetric(title: "Students", value: "\(studentCount)", subtitle: "Active records")
                MiniHeroMetric(title: "Upcoming", value: "\(upcomingCount)", subtitle: "Scheduled lessons")
                MiniHeroMetric(title: "Outstanding", value: AppFormat.currency(outstandingBalance), subtitle: "Still awaiting payment")
                IncomeMetricCard(
                    timeframe: $incomeTimeframe,
                    total: incomeTotal,
                    paidSessions: paidSessions
                )
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.panelBackgroundSoft,
                            AppTheme.panelBackground,
                            AppTheme.accentSecondary.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
        )
    }
}

struct MiniHeroMetric: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.42))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .foregroundStyle(AppTheme.mutedText)
                .font(.system(size: 13.5))
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct OverviewShortcutButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.panelBackgroundSoft)
                        .frame(width: 42, height: 42)

                    Image(systemName: systemImage)
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(Color.white.opacity(0.52))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.panelBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.panelBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .appInteractiveButton()
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
                .foregroundStyle(.white)
            Spacer()
            Button("Dismiss") {
                dismiss()
            }
            .appInteractiveButton()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.26), AppTheme.accentSecondary.opacity(0.18)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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
                .foregroundStyle(Color.white.opacity(0.46))
            Text(value)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .foregroundStyle(AppTheme.mutedText)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.panelBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
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
                .foregroundStyle(Color.white.opacity(0.46))

            HStack(spacing: 8) {
                ForEach(IncomeTimeframe.allCases) { item in
                    Button {
                        timeframe = item
                    } label: {
                        Text(timeframeLabel(for: item))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(timeframe == item ? .black : .white.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(timeframe == item ? AppTheme.accent : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        timeframe == item ? AppTheme.accent.opacity(0.88) : Color.white.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .appInteractiveButton(scaleAmount: 1.01)
                }
            }

            Text(AppFormat.currency(total))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("\(timeframe.subtitle) • \(paidSessions) paid session\(paidSessions == 1 ? "" : "s")")
                .foregroundStyle(AppTheme.mutedText)
                .font(.system(size: 13.5))
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func timeframeLabel(for timeframe: IncomeTimeframe) -> String {
        switch timeframe {
        case .weekly:
            return "Week"
        case .monthly:
            return "Month"
        case .yearly:
            return "Year"
        }
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
                    .foregroundStyle(.white)
                Text(subtitle)
                    .foregroundStyle(AppTheme.mutedText)
            }
            Spacer()
            Text(trailing)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(AppTheme.accent.opacity(0.16)))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(AppTheme.mutedText)
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
                Text("\(report.paidSessionCount) paid • \(report.creditCoveredSessionCount) credit covered • \(report.openSessionCount) open")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                PaymentMiniMetric(title: "Total Earned", value: AppFormat.currency(report.totalEarnedAmount))
                PaymentMiniMetric(title: "Collected", value: AppFormat.currency(report.collectedAmount))
                PaymentMiniMetric(title: "Credit Covered", value: AppFormat.currency(report.creditCoveredAmount))
                PaymentMiniMetric(title: "Awaiting", value: AppFormat.currency(report.unpaidAmount))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct CreditPurchaseRow: View {
    let purchase: StudentCreditPurchase
    let studentName: String
    let isSelected: Bool

    private var expirationSummary: String? {
        guard let expirationDate = purchase.expirationDate else {
            return nil
        }

        let formattedDate = AppFormat.shortDateFormatter.string(from: expirationDate)
        if purchase.isExpired() {
            return "Expired \(formattedDate)"
        }
        return "Expires \(formattedDate)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(studentName)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(AppFormat.shortDateFormatter.string(from: purchase.purchasedAt))
                    .foregroundStyle(.secondary)
            }

            Text("\(AppFormat.hours(purchase.purchasedHours)) • Paid \(AppFormat.currency(purchase.amountPaid))")
                .foregroundStyle(.secondary)

            if purchase.discountAmount > 0 {
                Text("Discount: \(AppFormat.currency(purchase.discountAmount))")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            if let expirationSummary {
                Text(expirationSummary)
                    .foregroundStyle(purchase.isExpired() ? .orange : .secondary)
                    .font(.subheadline)
            }

            if !purchase.note.isEmpty {
                Text(purchase.note)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct StudentCreditStatusRow: View {
    let status: StudentCreditStatus

    private var futureCoveredSessions: [LessonSession] {
        status.coveredSessions
            .filter { $0.endAt >= Date() }
            .sorted { $0.startAt < $1.startAt }
    }

    private var futureUncoveredSession: LessonSession? {
        status.uncoveredSessions
            .filter { $0.endAt >= Date() }
            .sorted { $0.startAt < $1.startAt }
            .first
    }

    private var nextCreditExpirationText: String? {
        guard let nextCreditExpirationDate = status.nextCreditExpirationDate else {
            return nil
        }

        return "Next credit expiry: \(AppFormat.shortDateFormatter.string(from: nextCreditExpirationDate))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(status.studentName)
                        .font(.title3.weight(.semibold))
                    if let futureUncoveredSession {
                        Text("Credit runs out before \(AppFormat.dateTimeFormatter.string(from: futureUncoveredSession.startAt)).")
                            .foregroundStyle(.secondary)
                    } else if let lastCovered = futureCoveredSessions.last {
                        Text("Current credit covers lessons through \(AppFormat.dateTimeFormatter.string(from: lastCovered.endAt)).")
                            .foregroundStyle(.secondary)
                    } else if status.remainingHours > 0 {
                        Text("No uncovered future lessons yet. \(AppFormat.hours(status.remainingHours)) still available.")
                            .foregroundStyle(.secondary)
                    } else if status.expiredRemainingHours > 0 {
                        Text("No active credit remaining.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No advance credit remaining.")
                            .foregroundStyle(.secondary)
                    }

                    if let nextCreditExpirationText {
                        Text(nextCreditExpirationText)
                            .foregroundStyle(.secondary)
                    }

                    if status.expiredRemainingHours > 0 {
                        Text("\(AppFormat.hours(status.expiredRemainingHours)) expired unused.")
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Text(AppFormat.hours(status.remainingHours))
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }

            HStack(spacing: 18) {
                PaymentMiniMetric(title: "Bought", value: AppFormat.hours(status.totalPurchasedHours))
                PaymentMiniMetric(title: "Used", value: AppFormat.hours(status.usedHours))
                PaymentMiniMetric(title: "Paid", value: AppFormat.currency(status.totalAmountPaid))
                PaymentMiniMetric(title: "Discount", value: AppFormat.currency(status.totalDiscountAmount))
            }

            if !futureCoveredSessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Covered Lessons")
                        .font(.headline)

                    ForEach(futureCoveredSessions) { session in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(session.title) • \(AppFormat.dateTimeFormatter.string(from: session.startAt))")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(AppFormat.hours(session.durationHours)) • \(AppFormat.currency(session.paymentAmount))")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(session.paymentStatus.title)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.green.opacity(0.12)))
                                .foregroundStyle(.green)
                        }
                    }
                }
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
        case .creditCovered:
            return .green
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

struct CreditSnapshotMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.46))
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
        )
    }
}

struct PaymentFieldCard<Content: View>: View {
    let title: String
    let minHeight: CGFloat?
    let content: Content

    init(title: String, minHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            content
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.panelBackgroundSoft.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
        )
    }
}

struct PaymentInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

private extension PaymentsView {
    enum PaymentActionStyle {
        case secondary
        case accent
        case destructive
    }

    func paymentActionButton(
        _ title: String,
        systemImage: String,
        style: PaymentActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(buttonForegroundColor(for: style))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(buttonBackground(for: style))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(buttonBorder(for: style), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .appInteractiveButton()
    }

    private func buttonBackground(for style: PaymentActionStyle) -> Color {
        switch style {
        case .secondary:
            return AppTheme.panelBackgroundSoft
        case .accent:
            return AppTheme.accent.opacity(0.92)
        case .destructive:
            return Color.red.opacity(0.18)
        }
    }

    private func buttonBorder(for style: PaymentActionStyle) -> Color {
        switch style {
        case .secondary:
            return AppTheme.panelBorder
        case .accent:
            return AppTheme.accent.opacity(0.95)
        case .destructive:
            return Color.red.opacity(0.34)
        }
    }

    private func buttonForegroundColor(for style: PaymentActionStyle) -> Color {
        switch style {
        case .secondary, .accent, .destructive:
            return .white
        }
    }
}
