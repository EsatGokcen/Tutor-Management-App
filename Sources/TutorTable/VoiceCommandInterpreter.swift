import Foundation

enum VoiceCommandIntent {
    case createSession(VoiceCreateSessionIntent)
    case updateSessionPayment(VoiceUpdateSessionPaymentIntent)
}

struct VoiceCreateSessionIntent {
    let studentID: UUID
    let startAt: Date
    let endAt: Date
    let title: String?
    let location: String?
    let paymentAmount: Double?
    let paymentStatus: PaymentStatus
    let paymentMethod: String?
}

struct VoiceUpdateSessionPaymentIntent {
    let sessionID: UUID
    let paymentStatus: PaymentStatus
    let paymentMethod: String?
}

enum VoiceCommandInterpreterError: LocalizedError {
    case missingStudent
    case ambiguousStudent
    case missingSchedule
    case missingTime
    case missingExistingSession
    case ambiguousExistingSession(studentName: String, day: String)
    case unsupportedCommand

    var errorDescription: String? {
        switch self {
        case .missingStudent:
            return "I couldn't match that command to one of your students. Say the student's name as it appears in TutorTable."
        case .ambiguousStudent:
            return "I found more than one student that could match that command. Please say the full student name."
        case .missingSchedule:
            return "I could not find a date for that session. Try saying the day and time more clearly."
        case .missingTime:
            return "I could not find a time for that session. Try saying something like 3pm or 15:30."
        case .missingExistingSession:
            return "I couldn't find an existing session that matches that update."
        case .ambiguousExistingSession(let studentName, let day):
            return "I found multiple sessions for \(studentName) on \(day). Please mention the session time too."
        case .unsupportedCommand:
            return "I understood the words, but not the action. Try creating a session or saying that a student paid for one."
        }
    }
}

struct VoiceCommandContext {
    let students: [Student]
    let sessions: [LessonSession]
    let settings: AppSettings
    let now: Date
    let calendar: Calendar
}

enum VoiceCommandInterpreter {
    static func interpret(transcript: String, context: VoiceCommandContext) throws -> VoiceCommandIntent {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTranscript = normalize(trimmedTranscript)

        guard !normalizedTranscript.isEmpty else {
            throw VoiceCommandInterpreterError.unsupportedCommand
        }

        let student = try matchStudent(in: normalizedTranscript, students: context.students)

        if isPaymentUpdateCommand(normalizedTranscript) {
            return .updateSessionPayment(try buildPaymentUpdateIntent(
                transcript: trimmedTranscript,
                normalizedTranscript: normalizedTranscript,
                student: student,
                context: context
            ))
        }

        if isCreateSessionCommand(normalizedTranscript) {
            return .createSession(try buildCreateSessionIntent(
                transcript: trimmedTranscript,
                normalizedTranscript: normalizedTranscript,
                student: student,
                context: context
            ))
        }

        throw VoiceCommandInterpreterError.unsupportedCommand
    }

    private static func buildCreateSessionIntent(
        transcript: String,
        normalizedTranscript: String,
        student: Student,
        context: VoiceCommandContext
    ) throws -> VoiceCreateSessionIntent {
        guard let schedule = parseCreateSchedule(from: transcript, now: context.now, calendar: context.calendar) else {
            throw VoiceCommandInterpreterError.missingSchedule
        }

        guard schedule.hasExplicitTime else {
            throw VoiceCommandInterpreterError.missingTime
        }

        let durationHours = parseDurationHours(in: normalizedTranscript) ?? 1
        let endAt = schedule.startAt.addingTimeInterval(durationHours * 3_600)

        let paymentStatus = parsePaymentStatus(in: normalizedTranscript) ?? .unpaid
        let paymentMethod = parsePaymentMethod(in: normalizedTranscript)
        let location = parseLocation(in: normalizedTranscript)
        let paymentAmount = parsePaymentAmount(
            in: normalizedTranscript,
            student: student,
            durationHours: durationHours
        )

        return VoiceCreateSessionIntent(
            studentID: student.id,
            startAt: schedule.startAt,
            endAt: endAt,
            title: parseSessionType(in: normalizedTranscript),
            location: location,
            paymentAmount: paymentAmount,
            paymentStatus: paymentStatus,
            paymentMethod: paymentMethod
        )
    }

    private static func buildPaymentUpdateIntent(
        transcript: String,
        normalizedTranscript: String,
        student: Student,
        context: VoiceCommandContext
    ) throws -> VoiceUpdateSessionPaymentIntent {
        let targetStatus = parsePaymentStatus(in: normalizedTranscript) ?? .paid
        let targetDay = parseTargetDayForExistingSession(
            from: transcript,
            normalizedTranscript: normalizedTranscript,
            now: context.now,
            calendar: context.calendar
        )
        let targetTime = parseExplicitTime(from: transcript)
        let paymentMethod = parsePaymentMethod(in: normalizedTranscript)

        var candidates = context.sessions
            .filter { $0.studentID == student.id }
            .sorted { $0.startAt > $1.startAt }

        if let targetDay {
            candidates = candidates.filter { context.calendar.isDate($0.startAt, inSameDayAs: targetDay) }
        }

        if let targetTime {
            candidates = candidates.filter { session in
                let sessionComponents = context.calendar.dateComponents([.hour, .minute], from: session.startAt)
                return sessionComponents.hour == targetTime.hour && sessionComponents.minute == targetTime.minute
            }
        }

        if normalizedTranscript.contains("happened today")
            || normalizedTranscript.contains("earlier today")
            || normalizedTranscript.contains("already happened") {
            candidates = candidates.filter { $0.endAt <= context.now }
        }

        if targetStatus == .paid {
            let unpaidCandidates = candidates.filter { $0.paymentStatus != .paid }
            if !unpaidCandidates.isEmpty {
                candidates = unpaidCandidates
            }
        }

        guard !candidates.isEmpty else {
            throw VoiceCommandInterpreterError.missingExistingSession
        }

        if candidates.count > 1 {
            let resolvedDay = targetDay ?? candidates[0].startAt
            let sameMomentCount = Set(candidates.map(\.startAt)).count
            if sameMomentCount > 1 {
                throw VoiceCommandInterpreterError.ambiguousExistingSession(
                    studentName: student.fullName,
                    day: AppFormat.shortDateFormatter.string(from: resolvedDay)
                )
            }
        }

        guard let chosenSession = candidates.first else {
            throw VoiceCommandInterpreterError.missingExistingSession
        }

        return VoiceUpdateSessionPaymentIntent(
            sessionID: chosenSession.id,
            paymentStatus: targetStatus,
            paymentMethod: paymentMethod
        )
    }

    private static func matchStudent(in normalizedTranscript: String, students: [Student]) throws -> Student {
        let candidates = students.compactMap { student -> (student: Student, score: Int)? in
            let normalizedName = normalize(student.fullName)
            var score = 0

            if normalizedTranscript.contains(normalizedName) {
                score = normalizedName.count + 100
            }

            for component in normalizedName.split(separator: " ") where component.count >= 3 {
                if normalizedTranscript.contains(String(component)) {
                    score = max(score, component.count)
                }
            }

            return score > 0 ? (student, score) : nil
        }
        .sorted {
            if $0.score == $1.score {
                return $0.student.fullName < $1.student.fullName
            }
            return $0.score > $1.score
        }

        guard let first = candidates.first else {
            throw VoiceCommandInterpreterError.missingStudent
        }

        if candidates.count > 1, candidates[1].score == first.score {
            throw VoiceCommandInterpreterError.ambiguousStudent
        }

        return first.student
    }

    private static func isCreateSessionCommand(_ normalizedTranscript: String) -> Bool {
        let createSignals = [
            "i have a session",
            "i have lesson",
            "new session",
            "schedule a session",
            "book a session",
            "book session",
            "add a session",
            "add session",
            "session with",
            "lesson with"
        ]

        if createSignals.contains(where: normalizedTranscript.contains) {
            return true
        }

        return normalizedTranscript.contains("next week") || normalizedTranscript.contains("tomorrow")
    }

    private static func isPaymentUpdateCommand(_ normalizedTranscript: String) -> Bool {
        let updateSignals = [
            "just paid",
            "paid for",
            "has paid",
            "now paid",
            "payment came through",
            "mark as paid",
            "mark it paid",
            "mark paid"
        ]

        return updateSignals.contains(where: normalizedTranscript.contains)
    }

    private static func parseCreateSchedule(from transcript: String, now: Date, calendar: Calendar) -> ParsedCreateSchedule? {
        let matches = dateDetector.matches(in: transcript, range: NSRange(location: 0, length: (transcript as NSString).length))
        let parsedMatches = matches.compactMap { match -> ParsedDateMatch? in
            guard let date = match.date else {
                return nil
            }

            let text = (transcript as NSString).substring(with: match.range)
            return ParsedDateMatch(date: date, text: text)
        }

        let dayMatch = parsedMatches.first { !$0.isExplicitTime }
        let timeMatch = parsedMatches.first { $0.isExplicitTime }

        guard let dayMatch else {
            return nil
        }

        if let timeMatch {
            return ParsedCreateSchedule(
                startAt: combine(day: dayMatch.date, time: timeMatch.date, calendar: calendar),
                hasExplicitTime: true
            )
        }

        if dayMatch.hasEmbeddedTime {
            return ParsedCreateSchedule(startAt: dayMatch.date, hasExplicitTime: true)
        }

        if containsRelativeDayWord(normalize(transcript)) {
            return ParsedCreateSchedule(
                startAt: combine(day: dayMatch.date, time: now, calendar: calendar),
                hasExplicitTime: false
            )
        }

        return ParsedCreateSchedule(startAt: dayMatch.date, hasExplicitTime: false)
    }

    private static func parseTargetDayForExistingSession(
        from transcript: String,
        normalizedTranscript: String,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        if normalizedTranscript.contains("today") {
            return calendar.startOfDay(for: now)
        }

        if normalizedTranscript.contains("yesterday"),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            return calendar.startOfDay(for: yesterday)
        }

        let matches = dateDetector.matches(in: transcript, range: NSRange(location: 0, length: (transcript as NSString).length))
        for match in matches {
            guard let date = match.date else {
                continue
            }

            let text = (transcript as NSString).substring(with: match.range)
            if !ParsedDateMatch(date: date, text: text).isExplicitTime {
                return calendar.startOfDay(for: date)
            }
        }

        return nil
    }

    private static func parseExplicitTime(from transcript: String) -> DateComponents? {
        let matches = dateDetector.matches(in: transcript, range: NSRange(location: 0, length: (transcript as NSString).length))
        for match in matches {
            guard let date = match.date else {
                continue
            }

            let text = (transcript as NSString).substring(with: match.range)
            if ParsedDateMatch(date: date, text: text).isExplicitTime {
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                return DateComponents(hour: components.hour, minute: components.minute)
            }
        }

        return nil
    }

    private static func parseDurationHours(in normalizedTranscript: String) -> Double? {
        if normalizedTranscript.contains("half an hour") || normalizedTranscript.contains("half hour") {
            return 0.5
        }

        if normalizedTranscript.contains("an hour") || normalizedTranscript.contains("a hour") || normalizedTranscript.contains("one hour") {
            return 1
        }

        if let match = firstMatch(in: normalizedTranscript, pattern: #"(\d+(?:\.\d+)?)\s+hours?"#),
           let value = Double(match) {
            return value
        }

        if let match = firstMatch(in: normalizedTranscript, pattern: #"(\d+)\s+minutes?"#),
           let value = Double(match) {
            return value / 60
        }

        if let match = firstMatch(in: normalizedTranscript, pattern: #"(\d+)\s*min\b"#),
           let value = Double(match) {
            return value / 60
        }

        return nil
    }

    private static func parsePaymentStatus(in normalizedTranscript: String) -> PaymentStatus? {
        let unpaidSignals = [
            "hasn't paid",
            "hasnt paid",
            "has not paid",
            "not paid yet",
            "still unpaid",
            "unpaid"
        ]
        if unpaidSignals.contains(where: normalizedTranscript.contains) {
            return .unpaid
        }

        let creditSignals = [
            "covered by credit",
            "covered by advance payment",
            "paid in advance",
            "advance payment",
            "using credit"
        ]
        if creditSignals.contains(where: normalizedTranscript.contains) {
            return .creditCovered
        }

        let paidSignals = [
            "just paid",
            "paid for",
            "has paid",
            "now paid",
            "already paid",
            "is paid",
            "payment came through",
            "mark as paid",
            "mark paid"
        ]
        if paidSignals.contains(where: normalizedTranscript.contains) {
            return .paid
        }

        return nil
    }

    private static func parsePaymentMethod(in normalizedTranscript: String) -> String? {
        let methods: [(String, String)] = [
            ("bank transfer", "Bank transfer"),
            ("cash", "Cash"),
            ("card reader", "Card reader"),
            ("card", "Card"),
            ("apple pay", "Apple Pay"),
            ("paypal", "PayPal"),
            ("venmo", "Venmo"),
            ("transfer", "Bank transfer")
        ]

        return methods.first(where: { normalizedTranscript.contains($0.0) })?.1
    }

    private static func parseLocation(in normalizedTranscript: String) -> String? {
        let locations: [(String, String)] = [
            ("zoom", "Zoom"),
            ("online", "Online"),
            ("teams", "Microsoft Teams"),
            ("home visit", "Home visit"),
            ("studio", "Studio"),
            ("library", "Library"),
            ("school", "School")
        ]

        return locations.first(where: { normalizedTranscript.contains($0.0) })?.1
    }

    private static func parseSessionType(in normalizedTranscript: String) -> String? {
        let mappings: [(String, String)] = [
            ("theory lesson", "Theory Lesson"),
            ("exam prep", "Exam Prep"),
            ("practice session", "Practice Session"),
            ("guitar lesson", "Guitar Lesson"),
            ("make up lesson", "Make-Up Lesson"),
            ("makeup lesson", "Make-Up Lesson")
        ]

        return mappings.first(where: { normalizedTranscript.contains($0.0) })?.1
    }

    private static func parsePaymentAmount(in normalizedTranscript: String, student: Student, durationHours: Double) -> Double? {
        if let explicitTotal = parseExplicitCurrencyAmount(in: normalizedTranscript) {
            return explicitTotal
        }

        if let explicitHourlyRate = parseExplicitHourlyRate(in: normalizedTranscript) {
            return explicitHourlyRate * durationHours
        }

        if normalizedTranscript.contains("standard rate")
            || normalizedTranscript.contains("usual rate")
            || normalizedTranscript.contains("default rate")
            || student.hourlyRate > 0 {
            return student.hourlyRate * durationHours
        }

        return nil
    }

    private static func parseExplicitCurrencyAmount(in normalizedTranscript: String) -> Double? {
        if let match = firstMatch(in: normalizedTranscript, pattern: #"£\s*(\d+(?:\.\d{1,2})?)"#),
           let amount = Double(match) {
            return amount
        }

        if let match = firstMatch(in: normalizedTranscript, pattern: #"(\d+(?:\.\d{1,2})?)\s*(?:pounds?|gbp)\b"#),
           let amount = Double(match) {
            return amount
        }

        return nil
    }

    private static func parseExplicitHourlyRate(in normalizedTranscript: String) -> Double? {
        if let match = firstMatch(in: normalizedTranscript, pattern: #"(\d+(?:\.\d{1,2})?)\s*(?:an hour|a hour|per hour|hourly)"#),
           let amount = Double(match) {
            return amount
        }

        return nil
    }

    private static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = 0
        return calendar.date(from: merged) ?? day
    }

    private static func containsRelativeDayWord(_ normalizedTranscript: String) -> Bool {
        [
            "today",
            "tomorrow",
            "yesterday",
            "next week",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday"
        ].contains(where: normalizedTranscript.contains)
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .autoupdatingCurrent)
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "[^a-z0-9: ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 1 else {
            return nil
        }

        return nsText.substring(with: match.range(at: 1))
    }

    private static let dateDetector: NSDataDetector = {
        try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }()
}

private struct ParsedCreateSchedule {
    let startAt: Date
    let hasExplicitTime: Bool
}

private struct ParsedDateMatch {
    let date: Date
    let text: String

    var isExplicitTime: Bool {
        hasEmbeddedTime && !isMostlyDayReference
    }

    var hasEmbeddedTime: Bool {
        let lowered = text.lowercased()
        if lowered.contains("am") || lowered.contains("pm") || lowered.contains(":") || lowered.contains("noon") || lowered.contains("midnight") {
            return true
        }

        return false
    }

    private var isMostlyDayReference: Bool {
        let lowered = text.lowercased()
        let dayWords = [
            "today",
            "tomorrow",
            "yesterday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday",
            "next week"
        ]
        return dayWords.contains(where: lowered.contains)
    }
}
