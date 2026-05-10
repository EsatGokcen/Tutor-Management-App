import SwiftUI

struct LessonsCalendarView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedSession: LessonSession?
    @State private var selectedTimeOff: TimeOffEntry?
    @State private var newSessionRequest: LessonsCalendarNewSessionRequest?
    @State private var newTimeOffRequest: LessonsCalendarNewTimeOffRequest?

    private let calendar = Calendar.current

    private var monthDays: [LessonsCalendarDay] {
        let sessionsByDay = Dictionary(grouping: appModel.sessions) { session in
            calendar.startOfDay(for: session.startAt)
        }

        return calendar.monthGridDates(for: displayedMonth).map { date in
            LessonsCalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                sessions: (sessionsByDay[calendar.startOfDay(for: date)] ?? []).sorted { $0.startAt < $1.startAt },
                timeOffEntries: appModel.timeOffEntriesForDay(date)
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

    private var selectedDayTimeOffEntries: [TimeOffEntry] {
        appModel.timeOffEntriesForDay(selectedDate)
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
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 1180

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .bottom) {
                            calendarHeaderCopy
                            Spacer()
                            calendarHeaderControls
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            calendarHeaderCopy
                            calendarHeaderControls
                        }
                    }

                    HStack {
                        Text(displayedMonthTitle)
                            .font(.system(size: 24, weight: .semibold))
                        Spacer()
                        Text("\(lessonsThisMonthCount) lesson\(lessonsThisMonthCount == 1 ? "" : "s") in view")
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 18)],
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

                    Group {
                        if isCompact {
                            VStack(alignment: .leading, spacing: 20) {
                                calendarBoard
                                calendarSidebar
                            }
                        } else {
                            HStack(alignment: .top, spacing: 20) {
                                calendarBoard
                                calendarSidebar
                                    .frame(width: 320)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $selectedSession) { session in
            LessonsCalendarSessionDetailSheet(session: session)
                .environmentObject(appModel)
        }
        .sheet(item: $selectedTimeOff) { entry in
            LessonsCalendarTimeOffSheet(
                selectedDate: calendar.startOfDay(for: entry.startAt),
                initialDraft: TimeOffDraft(entry: entry)
            )
            .environmentObject(appModel)
        }
        .sheet(item: $newSessionRequest) { request in
            LessonsCalendarNewSessionSheet(
                selectedDate: request.date,
                initialDraft: appModel.newSessionDraft(on: request.date)
            )
            .environmentObject(appModel)
        }
        .sheet(item: $newTimeOffRequest) { request in
            LessonsCalendarTimeOffSheet(
                selectedDate: request.date,
                initialDraft: appModel.newTimeOffDraft(on: request.date)
            )
            .environmentObject(appModel)
        }
    }

    private var calendarBoard: some View {
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
                        },
                        onOpenTimeOff: { entry in
                            selectDay(day.date)
                            selectedTimeOff = entry
                        },
                        onCreateSession: {
                            beginNewSession(on: day.date)
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
        )
    }

    private var calendarSidebar: some View {
        LessonsCalendarSidebar(
            selectedDateTitle: selectedDateTitle,
            selectedDaySessions: selectedDaySessions,
            selectedDayTimeOffEntries: selectedDayTimeOffEntries,
            studentNameProvider: appModel.studentName,
            onOpenSession: { session in
                selectedSession = session
            },
            onOpenTimeOff: { entry in
                selectedTimeOff = entry
            },
            onCreateTimeOff: {
                beginNewTimeOff(on: selectedDate)
            }
        )
    }

    private var calendarHeaderCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calendar")
                .font(.system(size: 28, weight: .semibold))
            Text("A live view of every lesson on your schedule. New and existing sessions appear here automatically.")
                .foregroundStyle(AppTheme.mutedText)
        }
    }

    private var calendarHeaderControls: some View {
        HStack(spacing: 10) {
            Button {
                beginNewTimeOff(on: selectedDate)
            } label: {
                Label("Book Time Off", systemImage: "calendar.badge.minus")
            }
            .appInteractiveButton()

            Button("Today") {
                jumpToToday()
            }
            .appInteractiveButton()

            Button {
                changeDisplayedMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .appInteractiveButton()

            Button {
                changeDisplayedMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .appInteractiveButton()
        }
        .buttonStyle(.bordered)
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

    private func beginNewSession(on date: Date) {
        selectDay(date)
        newSessionRequest = LessonsCalendarNewSessionRequest(date: calendar.startOfDay(for: date))
    }

    private func beginNewTimeOff(on date: Date) {
        selectDay(date)
        newTimeOffRequest = LessonsCalendarNewTimeOffRequest(date: calendar.startOfDay(for: date))
    }
}

private struct LessonsCalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    let sessions: [LessonSession]
    let timeOffEntries: [TimeOffEntry]

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
    let onOpenTimeOff: (TimeOffEntry) -> Void
    let onCreateSession: () -> Void
    @State private var suppressNextCellTap = false

    private var visibleTimeOffEntries: [TimeOffEntry] {
        Array(day.timeOffEntries.prefix(2))
    }

    private var visibleSessions: [LessonSession] {
        let remainingSlots = max(0, 3 - visibleTimeOffEntries.count)
        return Array(day.sessions.prefix(remainingSlots))
    }

    private var hiddenItemCount: Int {
        max(0, day.timeOffEntries.count - visibleTimeOffEntries.count) +
        max(0, day.sessions.count - visibleSessions.count)
    }

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

                HStack(spacing: 6) {
                    if !day.timeOffEntries.isEmpty {
                        Text(day.timeOffEntries.count == 1 ? "Off" : "\(day.timeOffEntries.count) Off")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.16))
                            )
                    }

                    if day.sessions.count > 0 {
                        Text("\(day.sessions.count)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(visibleTimeOffEntries) { entry in
                    Button {
                        suppressNextCellTap = true
                        onOpenTimeOff(entry)
                    } label: {
                        LessonsCalendarTimeOffChip(entry: entry, referenceDate: day.date)
                    }
                    .buttonStyle(.plain)
                    .appInteractiveButton(scaleAmount: 1.01)
                }

                ForEach(visibleSessions) { session in
                    Button {
                        suppressNextCellTap = true
                        onOpenSession(session)
                    } label: {
                        LessonsCalendarEventChip(
                            session: session,
                            studentName: studentNameProvider(session.studentID)
                        )
                    }
                    .buttonStyle(.plain)
                    .appInteractiveButton(scaleAmount: 1.01)
                }

                if hiddenItemCount > 0 {
                    Text("+ \(hiddenItemCount) more")
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
            if suppressNextCellTap {
                suppressNextCellTap = false
                return
            }
            onSelectDay()
            onCreateSession()
        }
        .appInteractiveButton(scaleAmount: 1.005)
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
            return Color.accentColor.opacity(0.10)
        }
        if day.isInDisplayedMonth {
            return AppTheme.panelBackgroundSoft
        }
        return AppTheme.panelBackgroundSoft.opacity(0.58)
    }

    private var cellBorder: Color {
        if isSelected {
            return .accentColor.opacity(0.7)
        }
        if isToday {
            return .accentColor.opacity(0.28)
        }
        return AppTheme.panelBorder
    }
}

private struct LessonsCalendarNewSessionRequest: Identifiable {
    let date: Date

    var id: Date { date }
}

private struct LessonsCalendarNewTimeOffRequest: Identifiable {
    let date: Date

    var id: Date { date }
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
            return .green.opacity(0.12)
        case .unpaid:
            return .accentColor.opacity(0.12)
        }
    }

    private var chipStrokeColor: Color {
        switch session.paymentStatus {
        case .paid:
            return .green.opacity(0.24)
        case .creditCovered:
            return .green.opacity(0.24)
        case .unpaid:
            return .accentColor.opacity(0.25)
        }
    }
}

private struct LessonsCalendarTimeOffChip: View {
    let entry: TimeOffEntry
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.displayTitle)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
            Text(LessonsCalendarFormatters.timeOffChipSubtitle(for: entry, referenceDate: referenceDate))
                .font(.system(size: 10.5))
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct LessonsCalendarSidebar: View {
    let selectedDateTitle: String
    let selectedDaySessions: [LessonSession]
    let selectedDayTimeOffEntries: [TimeOffEntry]
    let studentNameProvider: (UUID) -> String
    let onOpenSession: (LessonSession) -> Void
    let onOpenTimeOff: (TimeOffEntry) -> Void
    let onCreateTimeOff: () -> Void

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
                if !selectedDayTimeOffEntries.isEmpty {
                    Text("\(selectedDayTimeOffEntries.count) unavailable block\(selectedDayTimeOffEntries.count == 1 ? "" : "s")")
                        .foregroundStyle(.orange)
                }
            }

            Button {
                onCreateTimeOff()
            } label: {
                Label("Book Time Off", systemImage: "calendar.badge.minus")
                    .frame(maxWidth: .infinity)
            }
            .appInteractiveButton()

            Divider()

            if !selectedDayTimeOffEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Unavailable")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(selectedDayTimeOffEntries) { entry in
                        Button {
                            onOpenTimeOff(entry)
                        } label: {
                            LessonsCalendarTimeOffSidebarRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .appInteractiveButton(scaleAmount: 1.01)
                    }
                }
            }

            if !selectedDaySessions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if !selectedDayTimeOffEntries.isEmpty {
                        Text("Lessons")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

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
                        .appInteractiveButton(scaleAmount: 1.01)
                    }
                }
            }

            if selectedDaySessions.isEmpty && selectedDayTimeOffEntries.isEmpty {
                EmptyStateView(message: "No lessons or unavailable time scheduled for this day.")
            }

            Spacer(minLength: 0)
        }
        .padding(18)
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

private struct LessonsCalendarTimeOffSidebarRow: View {
    let entry: TimeOffEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.displayTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(LessonsCalendarFormatters.timeOffDetailSummary(for: entry))
                    .foregroundStyle(.secondary)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("Unavailable")
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.14))
                )
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
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
                .fill(AppTheme.panelBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
        )
    }

    private var statusBadgeColor: Color {
        switch session.paymentStatus {
        case .paid:
            return .green
        case .creditCovered:
            return .green
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
                    .appInteractiveButton()
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
                    .appInteractiveButton()

                    Button("Delete Session", role: .destructive) {
                        isShowingDeleteConfirmation = true
                    }
                    .appInteractiveButton()

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
                    .appInteractiveButton()
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
                    .appInteractiveButton()
                }
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 700)
    }
}

private struct LessonsCalendarNewSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let selectedDate: Date
    @State private var draft: SessionDraft

    init(selectedDate: Date, initialDraft: SessionDraft) {
        self.selectedDate = selectedDate
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add Session")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Create a new lesson for \(LessonsCalendarFormatters.selectedDayTitle.string(from: selectedDate)).")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .appInteractiveButton()
                }

                GroupBox("Session Details") {
                    VStack(alignment: .leading, spacing: 14) {
                        if appModel.studentsSorted.isEmpty {
                            EmptyStateView(message: "Create at least one student before adding a session from the calendar.")
                        } else {
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
                    }
                    .padding(.top, 8)
                }

                ViewThatFits(in: .horizontal) {
                    HStack {
                        Spacer()
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        actionButtons
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 700)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Use Saved Defaults") {
            let preservedStudentID = draft.studentID
            let preservedStartAt = draft.startAt
            let preservedEndAt = draft.endAt
            let preservedCreatedAt = draft.createdAt
            let preservedID = draft.id
            let preservedPaymentStatus = draft.paymentStatus
            let preservedLessonNotes = draft.lessonNotes
            let preservedHomework = draft.homework

            draft = appModel.newSessionDraft(on: selectedDate, preferredStudentID: preservedStudentID)
            draft.id = preservedID
            draft.createdAt = preservedCreatedAt
            draft.startAt = preservedStartAt
            draft.endAt = preservedEndAt
            draft.paymentStatus = preservedPaymentStatus
            draft.lessonNotes = preservedLessonNotes
            draft.homework = preservedHomework
        }
        .disabled(appModel.studentsSorted.isEmpty)
        .appInteractiveButton()

        Button("Save Session") {
            guard appModel.saveSession(draft) != nil else {
                return
            }
            dismiss()
        }
        .disabled(appModel.studentsSorted.isEmpty || !draft.isValid)
        .appInteractiveButton()
    }
}

private struct LessonsCalendarTimeOffSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let selectedDate: Date
    @State private var draft: TimeOffDraft
    @State private var isShowingDeleteConfirmation = false

    private let calendar = Calendar.current

    init(selectedDate: Date, initialDraft: TimeOffDraft) {
        self.selectedDate = selectedDate
        _draft = State(initialValue: initialDraft)
    }

    private var isEditingExistingEntry: Bool {
        draft.id != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEditingExistingEntry ? "Edit Time Off" : "Book Time Off")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Mark unavailable time from the calendar so TutorTable can block overlapping session bookings.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .appInteractiveButton()
                }

                GroupBox("Unavailable Details") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Title", text: $draft.title)

                        Toggle("All day", isOn: $draft.isAllDay)

                        if draft.isAllDay {
                            DatePicker("Starts", selection: allDayStartBinding, displayedComponents: .date)
                            DatePicker("Ends", selection: allDayEndBinding, in: calendar.startOfDay(for: draft.startAt)..., displayedComponents: .date)
                            Text("TutorTable will block every session from the start of the first day until the end of the last day.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        } else {
                            DatePicker("Starts", selection: $draft.startAt)
                            DatePicker("Ends", selection: $draft.endAt, in: draft.startAt...)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                            TextEditor(text: $draft.notes)
                                .frame(minHeight: 120)
                        }
                    }
                    .padding(.top, 8)
                }

                ViewThatFits(in: .horizontal) {
                    HStack {
                        if isEditingExistingEntry {
                            Button("Delete Time Off", role: .destructive) {
                                isShowingDeleteConfirmation = true
                            }
                            .appInteractiveButton()
                        }

                        Spacer()

                        Button(isEditingExistingEntry ? "Save Changes" : "Save Time Off") {
                            guard appModel.saveTimeOffEntry(draft) != nil else {
                                return
                            }
                            dismiss()
                        }
                        .disabled(!draft.isValid)
                        .appInteractiveButton()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if isEditingExistingEntry {
                            Button("Delete Time Off", role: .destructive) {
                                isShowingDeleteConfirmation = true
                            }
                            .appInteractiveButton()
                        }

                        Button(isEditingExistingEntry ? "Save Changes" : "Save Time Off") {
                            guard appModel.saveTimeOffEntry(draft) != nil else {
                                return
                            }
                            dismiss()
                        }
                        .disabled(!draft.isValid)
                        .appInteractiveButton()
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 560)
        .onChange(of: draft.isAllDay) { _ in
            normalizeDraftTimes()
        }
        .alert("Delete This Time Off?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let id = draft.id {
                    appModel.deleteTimeOffEntry(id: id)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the unavailable time block from the calendar.")
        }
    }

    private var allDayStartBinding: Binding<Date> {
        Binding(
            get: {
                calendar.startOfDay(for: draft.startAt)
            },
            set: { newValue in
                let durationDays = max(1, allDayDurationDays)
                let newStart = calendar.startOfDay(for: newValue)
                draft.startAt = newStart
                draft.endAt = calendar.date(byAdding: .day, value: durationDays, to: newStart) ?? newStart.addingTimeInterval(Double(durationDays) * 86_400)
            }
        )
    }

    private var allDayEndBinding: Binding<Date> {
        Binding(
            get: {
                let exclusiveEnd = calendar.startOfDay(for: draft.normalizedEndAt)
                return calendar.date(byAdding: .day, value: -1, to: exclusiveEnd) ?? calendar.startOfDay(for: selectedDate)
            },
            set: { newValue in
                let startDay = calendar.startOfDay(for: draft.startAt)
                let proposedEndDay = calendar.startOfDay(for: newValue)
                let clampedEndDay = proposedEndDay < startDay ? startDay : proposedEndDay
                draft.endAt = calendar.date(byAdding: .day, value: 1, to: clampedEndDay) ?? clampedEndDay.addingTimeInterval(86_400)
            }
        )
    }

    private var allDayDurationDays: Int {
        let duration = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: draft.startAt),
            to: calendar.startOfDay(for: draft.normalizedEndAt)
        ).day ?? 1

        return max(1, duration)
    }

    private func normalizeDraftTimes() {
        if draft.isAllDay {
            let normalizedStart = calendar.startOfDay(for: draft.startAt)
            let normalizedEndCandidate = calendar.startOfDay(for: draft.endAt)
            draft.startAt = normalizedStart
            if normalizedEndCandidate > normalizedStart {
                draft.endAt = normalizedEndCandidate
            } else {
                draft.endAt = calendar.date(byAdding: .day, value: 1, to: normalizedStart) ?? normalizedStart.addingTimeInterval(86_400)
            }
        } else if draft.endAt <= draft.startAt {
            draft.endAt = calendar.date(byAdding: .hour, value: 1, to: draft.startAt) ?? draft.startAt.addingTimeInterval(3_600)
        }
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

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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

    static func timeOffChipSubtitle(for entry: TimeOffEntry, referenceDate: Date, calendar: Calendar = .current) -> String {
        if entry.isAllDay {
            if calendar.isDate(entry.startAt, inSameDayAs: entry.endAt.addingTimeInterval(-1)) {
                return "Unavailable all day"
            }

            if calendar.isDate(referenceDate, inSameDayAs: entry.startAt) {
                return "Starts today"
            }

            if calendar.isDate(referenceDate, inSameDayAs: entry.endAt.addingTimeInterval(-1)) {
                return "Ends today"
            }

            return "Unavailable"
        }

        if calendar.isDate(entry.startAt, inSameDayAs: referenceDate) {
            return "\(time.string(from: entry.startAt)) to \(time.string(from: entry.endAt))"
        }

        return shortDate.string(from: entry.startAt)
    }

    static func timeOffDetailSummary(for entry: TimeOffEntry, calendar: Calendar = .current) -> String {
        if entry.isAllDay {
            let lastUnavailableDay = calendar.date(byAdding: .day, value: -1, to: entry.endAt) ?? entry.startAt
            if calendar.isDate(entry.startAt, inSameDayAs: lastUnavailableDay) {
                return "\(selectedDayTitle.string(from: entry.startAt)) • All day"
            }

            return "\(shortDate.string(from: entry.startAt)) to \(shortDate.string(from: lastUnavailableDay)) • All day"
        }

        if calendar.isDate(entry.startAt, inSameDayAs: entry.endAt) {
            return "\(selectedDayTitle.string(from: entry.startAt)) • \(time.string(from: entry.startAt)) to \(time.string(from: entry.endAt))"
        }

        return "\(AppFormat.dateTimeFormatter.string(from: entry.startAt)) to \(AppFormat.dateTimeFormatter.string(from: entry.endAt))"
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
