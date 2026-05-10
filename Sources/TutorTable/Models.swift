import Foundation

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case unpaid
    case creditCovered
    case paid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unpaid:
            return "Unpaid"
        case .creditCovered:
            return "Credit Covered"
        case .paid:
            return "Paid"
        }
    }

    static var manualCases: [PaymentStatus] {
        [.unpaid, .paid]
    }

    var isPaid: Bool {
        self != .unpaid
    }

    var needsAttention: Bool {
        self == .unpaid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.unpaid.rawValue:
            self = .unpaid
        case Self.creditCovered.rawValue:
            self = .creditCovered
        case Self.paid.rawValue:
            self = .paid
        case "partiallyPaid":
            // Legacy partial states now require manual follow-up or credit coverage.
            self = .unpaid
        default:
            self = .unpaid
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct AppSettings: Codable, Equatable {
    static let defaultStudentSubjectValue = "Electric Guitar"
    static let defaultStudentHourlyRateValue = 0.0
    static let defaultSessionTypeValue = "Electric Guitar Lesson"
    static let defaultSessionLocationValue = ""
    static let defaultSessionPaymentMethodValue = ""
    static let fiveHourCreditDiscountValue = 0.0
    static let tenHourCreditDiscountValue = 0.0
    static let appleCalendarSyncEnabledValue = false
    static let appleCalendarIdentifierValue = ""

    var defaultStudentSubject: String = defaultStudentSubjectValue
    var defaultStudentHourlyRate: Double = defaultStudentHourlyRateValue
    var defaultSessionType: String = defaultSessionTypeValue
    var defaultSessionLocation: String = defaultSessionLocationValue
    var defaultSessionPaymentMethod: String = defaultSessionPaymentMethodValue
    var fiveHourCreditDiscount: Double = fiveHourCreditDiscountValue
    var tenHourCreditDiscount: Double = tenHourCreditDiscountValue
    var appleCalendarSyncEnabled: Bool = appleCalendarSyncEnabledValue
    var appleCalendarIdentifier: String = appleCalendarIdentifierValue

    private enum CodingKeys: String, CodingKey {
        case defaultStudentSubject
        case defaultStudentHourlyRate
        case defaultSessionType
        case defaultSessionLocation
        case defaultSessionPaymentMethod
        case fiveHourCreditDiscount
        case tenHourCreditDiscount
        case appleCalendarSyncEnabled
        case appleCalendarIdentifier
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultStudentSubject = try container.decodeIfPresent(String.self, forKey: .defaultStudentSubject) ?? Self.defaultStudentSubjectValue
        defaultStudentHourlyRate = try container.decodeIfPresent(Double.self, forKey: .defaultStudentHourlyRate) ?? Self.defaultStudentHourlyRateValue
        defaultSessionType = try container.decodeIfPresent(String.self, forKey: .defaultSessionType) ?? Self.defaultSessionTypeValue
        defaultSessionLocation = try container.decodeIfPresent(String.self, forKey: .defaultSessionLocation) ?? Self.defaultSessionLocationValue
        defaultSessionPaymentMethod = try container.decodeIfPresent(String.self, forKey: .defaultSessionPaymentMethod) ?? Self.defaultSessionPaymentMethodValue
        fiveHourCreditDiscount = try container.decodeIfPresent(Double.self, forKey: .fiveHourCreditDiscount) ?? Self.fiveHourCreditDiscountValue
        tenHourCreditDiscount = try container.decodeIfPresent(Double.self, forKey: .tenHourCreditDiscount) ?? Self.tenHourCreditDiscountValue
        appleCalendarSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .appleCalendarSyncEnabled) ?? Self.appleCalendarSyncEnabledValue
        appleCalendarIdentifier = try container.decodeIfPresent(String.self, forKey: .appleCalendarIdentifier) ?? Self.appleCalendarIdentifierValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultStudentSubject, forKey: .defaultStudentSubject)
        try container.encode(defaultStudentHourlyRate, forKey: .defaultStudentHourlyRate)
        try container.encode(defaultSessionType, forKey: .defaultSessionType)
        try container.encode(defaultSessionLocation, forKey: .defaultSessionLocation)
        try container.encode(defaultSessionPaymentMethod, forKey: .defaultSessionPaymentMethod)
        try container.encode(fiveHourCreditDiscount, forKey: .fiveHourCreditDiscount)
        try container.encode(tenHourCreditDiscount, forKey: .tenHourCreditDiscount)
        try container.encode(appleCalendarSyncEnabled, forKey: .appleCalendarSyncEnabled)
        try container.encode(appleCalendarIdentifier, forKey: .appleCalendarIdentifier)
    }
}

struct Student: Identifiable, Codable, Equatable {
    let id: UUID
    var fullName: String
    var subject: String
    var phoneNumber: String
    var email: String
    var hourlyRate: Double
    var notes: String
    var createdAt: Date

    init(
        id: UUID,
        fullName: String,
        subject: String,
        phoneNumber: String,
        email: String,
        hourlyRate: Double,
        notes: String,
        createdAt: Date
    ) {
        self.id = id
        self.fullName = fullName
        self.subject = subject
        self.phoneNumber = phoneNumber
        self.email = email
        self.hourlyRate = hourlyRate
        self.notes = notes
        self.createdAt = createdAt
    }

    var contactSummary: String {
        [phoneNumber, email]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullName
        case subject
        case phoneNumber
        case email
        case hourlyRate
        case notes
        case createdAt
        case contactInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContact = try container.decodeIfPresent(String.self, forKey: .contactInfo)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? AppSettings.defaultStudentSubjectValue
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? Self.inferPhone(from: legacyContact)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? Self.inferEmail(from: legacyContact)
        hourlyRate = try container.decodeIfPresent(Double.self, forKey: .hourlyRate) ?? AppSettings.defaultStudentHourlyRateValue
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(subject, forKey: .subject)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(email, forKey: .email)
        try container.encode(hourlyRate, forKey: .hourlyRate)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
    }

    private static func inferEmail(from legacyContact: String?) -> String {
        guard let legacyContact, legacyContact.contains("@") else {
            return ""
        }
        return legacyContact
    }

    private static func inferPhone(from legacyContact: String?) -> String {
        guard let legacyContact else {
            return ""
        }

        if legacyContact.contains("@") {
            return ""
        }

        return legacyContact
    }
}

struct LessonSession: Identifiable, Codable, Equatable {
    let id: UUID
    var studentID: UUID
    var title: String
    var location: String
    var startAt: Date
    var endAt: Date
    var reminderMinutesBefore: Int
    var paymentAmount: Double
    var paymentStatus: PaymentStatus
    var paymentMethod: String
    var lessonNotes: String
    var homework: String
    var appleCalendarItemIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    var durationHours: Double {
        max(0, endAt.timeIntervalSince(startAt)) / 3_600
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case studentID
        case title
        case location
        case startAt
        case endAt
        case reminderMinutesBefore
        case paymentAmount
        case paymentStatus
        case paymentMethod
        case lessonNotes
        case homework
        case appleCalendarItemIdentifier
        case createdAt
        case updatedAt
    }

    init(
        id: UUID,
        studentID: UUID,
        title: String,
        location: String,
        startAt: Date,
        endAt: Date,
        reminderMinutesBefore: Int,
        paymentAmount: Double,
        paymentStatus: PaymentStatus,
        paymentMethod: String,
        lessonNotes: String,
        homework: String,
        appleCalendarItemIdentifier: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.studentID = studentID
        self.title = title
        self.location = location
        self.startAt = startAt
        self.endAt = endAt
        self.reminderMinutesBefore = reminderMinutesBefore
        self.paymentAmount = paymentAmount
        self.paymentStatus = paymentStatus
        self.paymentMethod = paymentMethod
        self.lessonNotes = lessonNotes
        self.homework = homework
        self.appleCalendarItemIdentifier = appleCalendarItemIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        studentID = try container.decode(UUID.self, forKey: .studentID)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        startAt = try container.decodeIfPresent(Date.self, forKey: .startAt) ?? Date()
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt) ?? startAt
        reminderMinutesBefore = try container.decodeIfPresent(Int.self, forKey: .reminderMinutesBefore) ?? 30
        paymentAmount = try container.decodeIfPresent(Double.self, forKey: .paymentAmount) ?? 0
        paymentStatus = try container.decodeIfPresent(PaymentStatus.self, forKey: .paymentStatus) ?? .unpaid
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod) ?? ""
        lessonNotes = try container.decodeIfPresent(String.self, forKey: .lessonNotes) ?? ""
        homework = try container.decodeIfPresent(String.self, forKey: .homework) ?? ""
        appleCalendarItemIdentifier = try container.decodeIfPresent(String.self, forKey: .appleCalendarItemIdentifier)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(studentID, forKey: .studentID)
        try container.encode(title, forKey: .title)
        try container.encode(location, forKey: .location)
        try container.encode(startAt, forKey: .startAt)
        try container.encode(endAt, forKey: .endAt)
        try container.encode(reminderMinutesBefore, forKey: .reminderMinutesBefore)
        try container.encode(paymentAmount, forKey: .paymentAmount)
        try container.encode(paymentStatus, forKey: .paymentStatus)
        try container.encode(paymentMethod, forKey: .paymentMethod)
        try container.encode(lessonNotes, forKey: .lessonNotes)
        try container.encode(homework, forKey: .homework)
        try container.encodeIfPresent(appleCalendarItemIdentifier, forKey: .appleCalendarItemIdentifier)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct TimeOffEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var startAt: Date
    var endAt: Date
    var isAllDay: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Time Off" : trimmedTitle
    }
}

struct AppSnapshot: Codable {
    var settings: AppSettings = AppSettings()
    var students: [Student] = []
    var sessions: [LessonSession] = []
    var creditPurchases: [StudentCreditPurchase] = []
    var timeOffEntries: [TimeOffEntry] = []

    init(
        settings: AppSettings = AppSettings(),
        students: [Student] = [],
        sessions: [LessonSession] = [],
        creditPurchases: [StudentCreditPurchase] = [],
        timeOffEntries: [TimeOffEntry] = []
    ) {
        self.settings = settings
        self.students = students
        self.sessions = sessions
        self.creditPurchases = creditPurchases
        self.timeOffEntries = timeOffEntries
    }

    private enum CodingKeys: String, CodingKey {
        case settings
        case students
        case sessions
        case creditPurchases
        case timeOffEntries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        students = try container.decodeIfPresent([Student].self, forKey: .students) ?? []
        sessions = try container.decodeIfPresent([LessonSession].self, forKey: .sessions) ?? []
        creditPurchases = try container.decodeIfPresent([StudentCreditPurchase].self, forKey: .creditPurchases) ?? []
        timeOffEntries = try container.decodeIfPresent([TimeOffEntry].self, forKey: .timeOffEntries) ?? []
    }
}

struct StudentCreditPurchase: Identifiable, Codable, Equatable {
    let id: UUID
    var studentID: UUID
    var purchasedAt: Date
    var purchasedHours: Double
    var discountAmount: Double
    var amountPaid: Double
    var note: String
    var createdAt: Date
    var updatedAt: Date
}

struct StudentDraft {
    var id: UUID?
    var fullName: String = ""
    var subject: String = AppSettings.defaultStudentSubjectValue
    var phoneNumber: String = ""
    var email: String = ""
    var hourlyRate: Double = AppSettings.defaultStudentHourlyRateValue
    var notes: String = ""
    var createdAt: Date?

    init(defaults: AppSettings = AppSettings()) {
        subject = defaults.defaultStudentSubject
        hourlyRate = defaults.defaultStudentHourlyRate
    }

    init(student: Student) {
        id = student.id
        fullName = student.fullName
        subject = student.subject
        phoneNumber = student.phoneNumber
        email = student.email
        hourlyRate = student.hourlyRate
        notes = student.notes
        createdAt = student.createdAt
    }

    var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeStudent() -> Student {
        Student(
            id: id ?? UUID(),
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            hourlyRate: hourlyRate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt ?? Date()
        )
    }
}

struct SessionDraft {
    var id: UUID?
    var studentID: UUID?
    var title: String = ""
    var location: String = ""
    var startAt: Date = Date()
    var endAt: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    var reminderMinutesBefore: Int = 30
    var paymentAmount: Double = 0
    var paymentStatus: PaymentStatus = .unpaid
    var paymentMethod: String = ""
    var lessonNotes: String = ""
    var homework: String = ""
    var appleCalendarItemIdentifier: String?
    var createdAt: Date?

    init() {}

    init(defaults: AppSettings = AppSettings(), student: Student? = nil) {
        studentID = student?.id
        title = defaults.defaultSessionType
        location = defaults.defaultSessionLocation
        paymentAmount = student?.hourlyRate ?? 0
        paymentMethod = defaults.defaultSessionPaymentMethod
    }

    init(session: LessonSession) {
        id = session.id
        studentID = session.studentID
        title = session.title
        location = session.location
        startAt = session.startAt
        endAt = session.endAt
        reminderMinutesBefore = session.reminderMinutesBefore
        paymentAmount = session.paymentAmount
        paymentStatus = session.paymentStatus
        paymentMethod = session.paymentMethod
        lessonNotes = session.lessonNotes
        homework = session.homework
        appleCalendarItemIdentifier = session.appleCalendarItemIdentifier
        createdAt = session.createdAt
    }

    init(copying session: LessonSession) {
        studentID = session.studentID
        title = session.title
        location = session.location
        startAt = session.startAt
        endAt = session.endAt
        reminderMinutesBefore = session.reminderMinutesBefore
        paymentAmount = session.paymentAmount
        paymentStatus = .unpaid
        paymentMethod = session.paymentMethod
    }

    var isValid: Bool {
        studentID != nil && endAt > startAt
    }

    func makeSession() -> LessonSession {
        LessonSession(
            id: id ?? UUID(),
            studentID: studentID ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tutoring Session" : title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            startAt: startAt,
            endAt: endAt,
            reminderMinutesBefore: reminderMinutesBefore,
            paymentAmount: paymentAmount,
            paymentStatus: paymentStatus,
            paymentMethod: paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines),
            lessonNotes: lessonNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            homework: homework.trimmingCharacters(in: .whitespacesAndNewlines),
            appleCalendarItemIdentifier: appleCalendarItemIdentifier,
            createdAt: createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

struct TimeOffDraft {
    var id: UUID?
    var title: String = "Time Off"
    var startAt: Date = Calendar.current.startOfDay(for: Date())
    var endAt: Date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    var isAllDay: Bool = true
    var notes: String = ""
    var createdAt: Date?

    init() {}

    init(on date: Date) {
        let dayStart = Calendar.current.startOfDay(for: date)
        startAt = dayStart
        endAt = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
    }

    init(entry: TimeOffEntry) {
        id = entry.id
        title = entry.displayTitle
        startAt = entry.startAt
        endAt = entry.endAt
        isAllDay = entry.isAllDay
        notes = entry.notes
        createdAt = entry.createdAt
    }

    var isValid: Bool {
        normalizedEndAt > normalizedStartAt
    }

    var normalizedStartAt: Date {
        if isAllDay {
            return Calendar.current.startOfDay(for: startAt)
        }
        return startAt
    }

    var normalizedEndAt: Date {
        if isAllDay {
            let dayStart = Calendar.current.startOfDay(for: endAt)
            if dayStart > Calendar.current.startOfDay(for: startAt) {
                return dayStart
            }
            return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: startAt)) ?? startAt.addingTimeInterval(86_400)
        }
        return endAt
    }

    func makeEntry() -> TimeOffEntry {
        TimeOffEntry(
            id: id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Time Off" : title.trimmingCharacters(in: .whitespacesAndNewlines),
            startAt: normalizedStartAt,
            endAt: normalizedEndAt,
            isAllDay: isAllDay,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

struct CreditPurchaseDraft {
    var id: UUID?
    var studentID: UUID?
    var purchasedAt: Date = Date()
    var purchasedHours: Double = 0
    var discountAmount: Double = 0
    var amountPaid: Double = 0
    var note: String = ""
    var createdAt: Date?

    init() {}

    init(student: Student? = nil) {
        studentID = student?.id
    }

    init(purchase: StudentCreditPurchase) {
        id = purchase.id
        studentID = purchase.studentID
        purchasedAt = purchase.purchasedAt
        purchasedHours = purchase.purchasedHours
        discountAmount = purchase.discountAmount
        amountPaid = purchase.amountPaid
        note = purchase.note
        createdAt = purchase.createdAt
    }

    var isValid: Bool {
        studentID != nil && purchasedHours > 0 && amountPaid >= 0 && discountAmount >= 0
    }

    func standardValue(for student: Student?) -> Double {
        (student?.hourlyRate ?? 0) * purchasedHours
    }

    func impliedDiscount(for student: Student?) -> Double {
        max(0, standardValue(for: student) - amountPaid)
    }

    func makePurchase(for student: Student?) -> StudentCreditPurchase {
        StudentCreditPurchase(
            id: id ?? UUID(),
            studentID: studentID ?? UUID(),
            purchasedAt: purchasedAt,
            purchasedHours: purchasedHours,
            discountAmount: impliedDiscount(for: student),
            amountPaid: amountPaid,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

enum SessionFilter: String, CaseIterable, Identifiable {
    case upcoming
    case unpaid
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .unpaid:
            return "Needs Payment"
        case .all:
            return "All"
        }
    }
}

enum IncomeTimeframe: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }

    var subtitle: String {
        switch self {
        case .weekly:
            return "This week"
        case .monthly:
            return "This month"
        case .yearly:
            return "This year"
        }
    }

    func contains(_ date: Date, referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        let interval: DateInterval?
        switch self {
        case .weekly:
            interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        case .monthly:
            interval = calendar.dateInterval(of: .month, for: referenceDate)
        case .yearly:
            interval = calendar.dateInterval(of: .year, for: referenceDate)
        }

        return interval?.contains(date) ?? false
    }
}

enum AppFormat {
    static var currencyCode: String {
        Locale.autoupdatingCurrent.currency?.identifier ?? "GBP"
    }

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = .autoupdatingCurrent
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func currency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    static func number(_ value: Double) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func hours(_ value: Double) -> String {
        "\(number(value)) hour\(abs(value - 1) < 0.01 ? "" : "s")"
    }
}

struct PaymentSummary {
    var collectedAmount: Double = 0
    var creditReceivedAmount: Double = 0
    var unpaidAmount: Double = 0
    var creditCoveredAmount: Double = 0
    var paidSessionCount: Int = 0
    var unpaidSessionCount: Int = 0
    var creditCoveredSessionCount: Int = 0
    var creditPurchaseCount: Int = 0

    var totalEarnedAmount: Double {
        collectedAmount + creditCoveredAmount
    }
}

struct StudentPaymentReport: Identifiable {
    let studentID: UUID
    let studentName: String
    let collectedAmount: Double
    let unpaidAmount: Double
    let creditCoveredAmount: Double
    let paidSessionCount: Int
    let creditCoveredSessionCount: Int
    let openSessionCount: Int

    var id: UUID { studentID }

    var totalEarnedAmount: Double {
        collectedAmount + creditCoveredAmount
    }
}

struct CreditPurchaseUsage: Identifiable {
    let purchase: StudentCreditPurchase
    let usedHours: Double
    let remainingHours: Double
    let coveredSessionIDs: [UUID]

    var id: UUID { purchase.id }
}

struct StudentCreditStatus: Identifiable {
    let studentID: UUID
    let studentName: String
    let totalPurchasedHours: Double
    let usedHours: Double
    let remainingHours: Double
    let totalAmountPaid: Double
    let totalDiscountAmount: Double
    let coveredSessions: [LessonSession]
    let uncoveredSessions: [LessonSession]
    let purchases: [CreditPurchaseUsage]

    var id: UUID { studentID }

    var coveredSessionCount: Int {
        coveredSessions.count
    }

    var nextUncoveredSession: LessonSession? {
        uncoveredSessions.sorted { $0.startAt < $1.startAt }.first
    }

    var lastCoveredSession: LessonSession? {
        coveredSessions.sorted { $0.startAt < $1.startAt }.last
    }
}
