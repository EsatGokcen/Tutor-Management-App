import SwiftUI

struct LessonsCalendarView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedSession: LessonSession?

    private let calendar = Calendar.current

    private var monthDays: [LessonsCalendarDay] {
        let sessionsByDay = Dictionary(grouping: appModel.sessions) { session in
            calendar.startOfDay(for: session.startAt)
        }

        return calendar.monthGridDates(for: displayedMonth).map { date in
            LessonsCalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                sessions: (sessionsByDay[calendar.startOfDay(for: date)] ?? []).sorted { $0.startAt < $1.startAt }
            )
        }
    }

    private var monthSessions: [LessonSession] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        return appModel.sessions
            .filter { monthInterval.contains($0.startAt) }
            .sorted { $0.startAt < $1.startAt }
    }

    private var selectedDaySessions: [LessonSession] {
        appModel.sessions
            .filter { calendar.isDate($0.startAt, inSameDayAs: selectedDate) }
            .sorted { $0.startAt < $1.startAt }
    }

    private var displayedMonthTitle: String {
        LessonsCalendarFormatters.monthTitle.string(from: displayedMonth)
    }

    private var selectedDateTitle: String {
        LessonsCalendarFormatters.selectedDayTitle.string(from: selectedDate)
    }

    private var lessonsThisMonthCount: Int {
        monthSessions.count
    }

    private var bookedHoursThisMonth: Double {
        monthSessions.reduce(0) { partial, session in
            partial + session.durationHours
        }
    }

    private var paidThisMonth: Double {
        monthSessions
            .filter { $0.paymentStatus.isPaid }
            .reduce(0) { $0 + $1.paymentAmount }
    }

    private var selectedDayHours: Double {
        selectedDaySessions.reduce(0) { partial, session in
            partial + session.durationHours
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calendar")
                            .font(.system(size: 28, weight: .semibold))
                        Text("A live view of every lesson on your schedule. New and existing sessions appear here automatically.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button("Today") {
                            jumpToToday()
                        }

                        Button {
                            changeDisplayedMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            changeDisplayedMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Text(displayedMonthTitle)
                        .font(.system(size: 24, weight: .semibold))
                    Spacer()
                    Text("\(lessonsThisMonthCount) lesson\(lessonsThisMonthCount == 1 ? "" : "s") in view")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 18
                ) {
                    MetricCard(
                        title: "Lessons This Month",
                        value: "\(lessonsThisMonthCount)",
                        subtitle: displayedMonthTitle
                    )
                    MetricCard(
                        title: "Booked Hours",
                        value: LessonsCalendarFormatters.hourSummary(bookedHoursThisMonth),
                        subtitle: "Across all scheduled lessons"
                    )
                    MetricCard(
                        title: "Paid This Month",
                        value: AppFormat.currency(paidThisMonth),
                        subtitle: "Collected from paid sessions"
                    )
                    MetricCard(
                        title: "Selected Day",
                        value: "\(selectedDaySessions.count)",
                        subtitle: "\(selectedDateTitle) • \(LessonsCalendarFormatters.hourSummary(selectedDayHours))"
                    )
                }

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        LessonsCalendarWeekdayHeader(calendar: calendar)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7),
                            spacing: 10
                        ) {
                            ForEach(monthDays) { day in
                                LessonsCalendarDayCell(
                                    day: day,
                                    studentNameProvider: appModel.studentName,
                                    isToday: calendar.isDateInToday(day.date),
                                    isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                                    onSelectDay: {
                                        selectDay(day.date)
                                    },
                                    onOpenSession: { session in
                                        selectDay(day.date)
                                        selectedSession = session
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    LessonsCalendarSidebar(
                        selectedDateTitle: selectedDateTitle,
                        selectedDaySessions: selectedDaySessions,
                        studentNameProvider: appModel.studentName,
                        onOpenSession: { session in
                            selectedSession = session
                        }
                    )
                    .frame(width: 320)
                }
            }
            .padding(.bottom, 20)
        }
        .sheet(item: $selectedSession) { session in
            LessonsCalendarSessionDetailSheet(session: session)
                .environmentObject(appModel)
        }
    }

    private func selectDay(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = calendar.startOfMonth(for: date)
        }
    }

    private func jumpToToday() {
        let today = Date()
        displayedMonth = calendar.startOfMonth(for: today)
        selectedDate = calendar.startOfDay(for: today)
    }

    private func changeDisplayedMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }

        displayedMonth = calendar.startOfMonth(for: nextMonth)
        selectedDate = calendar.startOfDay(for: displayedMonth)
    }
}

private struct LessonsCalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    let sessions: [LessonSession]

    var id: Date { date }
}

private struct LessonsCalendarWeekdayHeader: View {
    let calendar: Calendar

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7),
            spacing: 10
        ) {
            ForEach(calendar.orderedVeryShortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct LessonsCalendarDayCell: View {
    let day: LessonsCalendarDay
    let studentNameProvider: (UUID) -> String
    let isToday: Bool
    let isSelected: Bool
    let onSelectDay: () -> Void
    let onOpenSession: (LessonSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(LessonsCalendarFormatters.dayNumber.string(from: day.date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(dayNumberColor)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(dayNumberBackground)
                    )

                Spacer()

                if day.sessions.count > 0 {
                    Text("\(day.sessions.count)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(day.sessions.prefix(3))) { session in
                    Button {
                        onOpenSession(session)
                    } label: {
                        LessonsCalendarEventChip(
                            session: session,
                            studentName: studentNameProvider(session.studentID)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if day.sessions.count > 3 {
                    Text("+ \(day.sessions.count - 3) more")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cellBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cellBorder, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            onSelectDay()
        }
    }

    private var dayNumberColor: Color {
        if isSelected {
            return .white
        }
        if !day.isInDisplayedMonth {
            return .secondary
        }
        return .primary
    }

    private var dayNumberBackground: Color {
        if isSelected {
            return .accentColor
        }
        if isToday {
            return Color.accentColor.opacity(0.18)
        }
        return .clear
    }

    private var cellBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.08)
        }
        if day.isInDisplayedMonth {
            return Color(nsColor: .underPageBackgroundColor)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.55)
    }

    private var cellBorder: Color {
        if isSelected {
            return .accentColor.opacity(0.7)
        }
        if isToday {
            return .accentColor.opacity(0.28)
        }
        return Color.primary.opacity(0.06)
    }
}

private struct LessonsCalendarEventChip: View {
    let session: LessonSession
    let studentName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.title)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
            Text("\(LessonsCalendarFormatters.time.string(from: session.startAt)) • \(studentName)")
                .font(.system(size: 10.5))
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(chipFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(chipStrokeColor, lineWidth: 1)
        )
    }

    private var chipFillColor: Color {
        switch session.paymentStatus {
        case .paid:
            return .green.opacity(0.12)
        case .creditCovered:
            return .blue.opacity(0.14)
        case .unpaid:
            return .accentColor.opacity(0.12)
        }
    }

    private var chipStrokeColor: Color {
        switch session.paymentStatus {
        case .paid:
            return .green.opacity(0.24)
        case .creditCovered:
            return .blue.opacity(0.28)
        case .unpaid:
            return .accentColor.opacity(0.25)
        }
    }
}

private struct LessonsCalendarSidebar: View {
    let selectedDateTitle: String
    let selectedDaySessions: [LessonSession]
    let studentNameProvider: (UUID) -> String
    let onOpenSession: (LessonSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Selected Day")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(selectedDateTitle)
                    .font(.system(size: 24, weight: .semibold))
                Text("\(selectedDaySessions.count) lesson\(selectedDaySessions.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }

            Divider()

            if selectedDaySessions.isEmpty {
                EmptyStateView(message: "No lessons scheduled for this day.")
            } else {
                ForEach(selectedDaySessions) { session in
                    Button {
                        onOpenSession(session)
                    } label: {
                        LessonsCalendarSidebarRow(
                            session: session,
                            studentName: studentNameProvider(session.studentID)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LessonsCalendarSidebarRow: View {
    let session: LessonSession
    let studentName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(studentName)
                    .foregroundStyle(.secondary)
                Text("\(LessonsCalendarFormatters.time.string(from: session.startAt)) to \(LessonsCalendarFormatters.time.string(from: session.endAt))")
                    .foregroundStyle(.secondary)
                if !session.location.isEmpty {
                    Text(session.location)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(session.paymentStatus.title)
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(statusBadgeColor.opacity(0.14))
                )
                .foregroundStyle(statusBadgeColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var statusBadgeColor: Color {
        switch session.paymentStatus {
        case .paid:
            return .green
        case .creditCovered:
            return .blue
        case .unpaid:
            return .accentColor
        }
    }
}

private struct LessonsCalendarSessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let session: LessonSession

    @State private var isShowingEditSheet = false
    @State private var isShowingDeleteConfirmation = false

    private var currentSession: LessonSession {
        appModel.sessions.first(where: { $0.id == session.id }) ?? session
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentSession.title)
                            .font(.system(size: 28, weight: .semibold))
                        Text(appModel.studentName(for: currentSession.studentID))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                }

                GroupBox("Schedule") {
                    VStack(alignment: .leading, spacing: 12) {
                        LessonsCalendarDetailRow(
                            label: "Date",
                            value: LessonsCalendarFormatters.selectedDayTitle.string(from: currentSession.startAt)
                        )
                        LessonsCalendarDetailRow(
                            label: "Time",
                            value: "\(LessonsCalendarFormatters.time.string(from: currentSession.startAt)) to \(LessonsCalendarFormatters.time.string(from: currentSession.endAt))"
                        )
                        LessonsCalendarDetailRow(
                            label: "Location",
                            value: currentSession.location.isEmpty ? "Not set" : currentSession.location
                        )
                        LessonsCalendarDetailRow(
                            label: "Reminder",
                            value: currentSession.reminderMinutesBefore == 0 ? "No reminder" : "\(currentSession.reminderMinutesBefore) minutes before"
                        )
                    }
                    .padding(.top, 8)
                }

                GroupBox("Payment") {
                    VStack(alignment: .leading, spacing: 12) {
                        LessonsCalendarDetailRow(label: "Amount", value: AppFormat.currency(currentSession.paymentAmount))
                        LessonsCalendarDetailRow(label: "Status", value: currentSession.paymentStatus.title)
                        LessonsCalendarDetailRow(
                            label: "Method",
                            value: currentSession.paymentMethod.isEmpty ? "Not set" : currentSession.paymentMethod
                        )
                    }
                    .padding(.top, 8)
                }

                GroupBox("Lesson Memory") {
                    VStack(alignment: .leading, spacing: 14) {
                        if currentSession.lessonNotes.isEmpty && currentSession.homework.isEmpty {
                            EmptyStateView(message: "No lesson notes or homework attached yet.")
                        } else {
                            if !currentSession.lessonNotes.isEmpty {
                                LessonsCalendarTextBlock(title: "Lesson Notes", text: currentSession.lessonNotes)
                            }
                            if !currentSession.homework.isEmpty {
                                LessonsCalendarTextBlock(title: "Homework", text: currentSession.homework)
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    Button("Edit Session") {
                        isShowingEditSheet = true
                    }

                    Button("Delete Session", role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }

                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 620)
        .sheet(isPresented: $isShowingEditSheet) {
            LessonsCalendarSessionEditSheet(session: currentSession)
                .environmentObject(appModel)
        }
        .alert("Delete This Session?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                appModel.deleteSession(id: currentSession.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the session from TutorTable and from the calendar.")
        }
    }
}

private struct LessonsCalendarSessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let session: LessonSession

    @State private var draft: SessionDraft

    init(session: LessonSession) {
        self.session = session
        _draft = State(initialValue: SessionDraft(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit Session")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Update the lesson directly from the calendar.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                }

                GroupBox("Session Details") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Student", selection: Binding(
                            get: { draft.studentID ?? session.studentID },
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

                        Stepper(
                            "Reminder: \(draft.reminderMinutesBefore) minutes before",
                            value: $draft.reminderMinutesBefore,
                            in: 0...1_440,
                            step: 5
                        )

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
                            Text("This session is currently covered by advance credit. If you mark it as paid manually, that credit stays available for another lesson.")
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

                HStack {
                    Spacer()

                    Button("Save Changes") {
                        guard appModel.saveSession(draft) != nil else {
                            return
                        }
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 700)
    }
}

private struct LessonsCalendarDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LessonsCalendarTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum LessonsCalendarFormatters {
    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()

    static let selectedDayTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func hourSummary(_ hours: Double) -> String {
        guard hours > 0 else {
            return "0h"
        }

        if hours == floor(hours) {
            return "\(Int(hours))h"
        }

        return String(format: "%.1fh", hours)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }

    func monthGridDates(for date: Date) -> [Date] {
        guard let monthInterval = self.dateInterval(of: .month, for: date) else {
            return []
        }

        let firstMonthDay = startOfDay(for: monthInterval.start)
        let weekday = component(.weekday, from: firstMonthDay)
        let leadingOffset = (weekday - firstWeekday + 7) % 7
        guard let gridStart = self.date(byAdding: .day, value: -leadingOffset, to: firstMonthDay) else {
            return []
        }

        return (0..<42).compactMap { offset in
            self.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    var orderedVeryShortWeekdaySymbols: [String] {
        let symbols = veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, min(symbols.count - 1, firstWeekday - 1))
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }
}
