import Foundation

struct WorkspaceSnapshot: Codable, Equatable {
    static let empty = WorkspaceSnapshot(
        onboardingCompleted: false,
        businessProfile: BusinessProfileProjection(
            businessName: "",
            email: "",
            phone: "",
            address: "",
            invoicePrefix: "INV",
            nextInvoiceNumber: 1,
            currencyCode: "EUR",
            paymentDetails: "",
            taxNote: "",
            defaultTermsDays: 14
        ),
        clients: [],
        projects: [],
        activity: []
    )

    var onboardingCompleted: Bool
    var businessProfile: BusinessProfileProjection
    var clients: [WorkspaceClient]
    var projects: [WorkspaceProject]
    var activity: [WorkspaceActivity]

    private enum CodingKeys: String, CodingKey {
        case onboardingCompleted
        case businessProfile
        case clients
        case projects
        case activity
    }

    init(
        onboardingCompleted: Bool = false,
        businessProfile: BusinessProfileProjection,
        clients: [WorkspaceClient],
        projects: [WorkspaceProject],
        activity: [WorkspaceActivity]
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.businessProfile = businessProfile
        self.clients = clients
        self.projects = projects
        self.activity = activity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        businessProfile = try container.decode(BusinessProfileProjection.self, forKey: .businessProfile)
        clients = try container.decode([WorkspaceClient].self, forKey: .clients)
        projects = try container.decode([WorkspaceProject].self, forKey: .projects)
        activity = try container.decode([WorkspaceActivity].self, forKey: .activity)
    }

    var activeProjects: [WorkspaceProject] {
        projects.filter { !$0.isArchived }
    }

    var archivedProjects: [WorkspaceProject] {
        projects.filter(\.isArchived)
    }

    mutating func normalizeMissingHourlyRates(defaultRateMinorUnits: Int = 8_000) {
        for projectIndex in projects.indices {
            let fallbackRate = projects[projectIndex].defaultHourlyRateMinorUnits ?? defaultRateMinorUnits

            for bucketIndex in projects[projectIndex].buckets.indices {
                let bucketRate = projects[projectIndex].buckets[bucketIndex].hourlyRateMinorUnits
                if projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits.map({ $0 <= 0 }) == true {
                    projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = bucketRate ?? fallbackRate
                } else if bucketRate == nil {
                    projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = fallbackRate
                }

                for entryIndex in projects[projectIndex].buckets[bucketIndex].timeEntries.indices {
                    let entry = projects[projectIndex].buckets[bucketIndex].timeEntries[entryIndex]
                    if entry.isBillable && entry.hourlyRateMinorUnits <= 0 {
                        projects[projectIndex].buckets[bucketIndex].timeEntries[entryIndex].hourlyRateMinorUnits = fallbackRate
                    }
                }
            }
        }
    }

    var recentActivity: [WorkspaceActivity] {
        activity.sorted { left, right in
            if left.occurredAt == right.occurredAt {
                return left.message < right.message
            }

            return left.occurredAt > right.occurredAt
        }
    }

    func project(named name: String) -> WorkspaceProject? {
        projects.first { $0.name == name }
    }

}

extension Date {
    static func billbiDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.billbiGregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

struct BusinessProfileProjection: Codable, Equatable {
    var businessName: String
    var personName: String
    var email: String
    var phone: String
    var address: String
    var taxIdentifier: String
    var economicIdentifier: String
    var invoicePrefix: String
    var nextInvoiceNumber: Int
    var currencyCode: String
    var paymentDetails: String
    var taxNote: String
    var defaultTermsDays: Int

    private enum CodingKeys: String, CodingKey {
        case businessName
        case personName
        case email
        case phone
        case address
        case taxIdentifier
        case economicIdentifier
        case invoicePrefix
        case nextInvoiceNumber
        case currencyCode
        case paymentDetails
        case taxNote
        case defaultTermsDays
    }

    init(
        businessName: String,
        personName: String = "",
        email: String,
        phone: String = "",
        address: String,
        taxIdentifier: String = "",
        economicIdentifier: String = "",
        invoicePrefix: String,
        nextInvoiceNumber: Int,
        currencyCode: String,
        paymentDetails: String,
        taxNote: String,
        defaultTermsDays: Int
    ) {
        self.businessName = businessName
        self.personName = personName
        self.email = email
        self.phone = phone
        self.address = address
        self.taxIdentifier = taxIdentifier
        self.economicIdentifier = economicIdentifier
        self.invoicePrefix = invoicePrefix
        self.nextInvoiceNumber = nextInvoiceNumber
        self.currencyCode = currencyCode
        self.paymentDetails = paymentDetails
        self.taxNote = taxNote
        self.defaultTermsDays = defaultTermsDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        businessName = try container.decode(String.self, forKey: .businessName)
        personName = try container.decodeIfPresent(String.self, forKey: .personName) ?? ""
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        address = try container.decode(String.self, forKey: .address)
        taxIdentifier = try container.decodeIfPresent(String.self, forKey: .taxIdentifier) ?? ""
        economicIdentifier = try container.decodeIfPresent(String.self, forKey: .economicIdentifier) ?? ""
        invoicePrefix = try container.decode(String.self, forKey: .invoicePrefix)
        nextInvoiceNumber = try container.decode(Int.self, forKey: .nextInvoiceNumber)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        paymentDetails = try container.decode(String.self, forKey: .paymentDetails)
        taxNote = try container.decode(String.self, forKey: .taxNote)
        defaultTermsDays = try container.decode(Int.self, forKey: .defaultTermsDays)
    }
}

struct WorkspaceClient: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var billingAddress: String
    var defaultTermsDays: Int
    var isArchived: Bool

    init(
        id: UUID,
        name: String,
        email: String,
        billingAddress: String,
        defaultTermsDays: Int,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.billingAddress = billingAddress
        self.defaultTermsDays = defaultTermsDays
        self.isArchived = isArchived
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case billingAddress
        case defaultTermsDays
        case isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        billingAddress = try container.decode(String.self, forKey: .billingAddress)
        defaultTermsDays = try container.decode(Int.self, forKey: .defaultTermsDays)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

struct WorkspaceProject: Codable, Equatable, Identifiable {
    let id: UUID
    var clientID: UUID? = nil
    var name: String
    var clientName: String
    var currencyCode: String
    var isArchived: Bool
    var buckets: [WorkspaceBucket]
    var invoices: [WorkspaceInvoice]

    var bucketCount: Int {
        buckets.count
    }

    var readyBucketCount: Int {
        buckets.filter { $0.status == .ready }.count
    }

    var openBucketCount: Int {
        buckets.filter { $0.status == .open }.count
    }

    var finalizedBucketCount: Int {
        buckets.filter { $0.status == .finalized }.count
    }

    var totalBucketMinorUnits: Int {
        buckets.map(\.effectiveTotalMinorUnits).reduce(0, +)
    }

    var openBucketMinorUnits: Int {
        buckets
            .filter { $0.status == .open }
            .map(\.effectiveTotalMinorUnits)
            .reduce(0, +)
    }

    var readyToInvoiceMinorUnits: Int {
        buckets
            .filter { $0.status == .ready }
            .map(\.effectiveTotalMinorUnits)
            .reduce(0, +)
    }

    func overdueInvoiceCount(on date: Date) -> Int {
        invoices.filter { $0.status.isOverdue(dueDate: $0.dueDate, on: date) }.count
    }

    var defaultHourlyRateMinorUnits: Int? {
        buckets.lazy.compactMap(\.hourlyRateMinorUnits).first
    }
}

struct WorkspaceBucket: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var status: BucketStatus
    var updatedAt: Date?
    var totalMinorUnits: Int
    var billableMinutes: Int
    var fixedCostMinorUnits: Int
    var nonBillableMinutes: Int = 0
    var defaultHourlyRateMinorUnits: Int? = nil
    var timeEntries: [WorkspaceTimeEntry] = []
    var fixedCostEntries: [WorkspaceFixedCostEntry] = []

    init(
        id: UUID,
        name: String,
        status: BucketStatus,
        updatedAt: Date? = nil,
        totalMinorUnits: Int,
        billableMinutes: Int,
        fixedCostMinorUnits: Int,
        nonBillableMinutes: Int = 0,
        defaultHourlyRateMinorUnits: Int? = nil,
        timeEntries: [WorkspaceTimeEntry] = [],
        fixedCostEntries: [WorkspaceFixedCostEntry] = []
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.updatedAt = updatedAt
        self.totalMinorUnits = totalMinorUnits
        self.billableMinutes = billableMinutes
        self.fixedCostMinorUnits = fixedCostMinorUnits
        self.nonBillableMinutes = nonBillableMinutes
        self.defaultHourlyRateMinorUnits = defaultHourlyRateMinorUnits
        self.timeEntries = timeEntries
        self.fixedCostEntries = fixedCostEntries
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case updatedAt
        case totalMinorUnits
        case billableMinutes
        case fixedCostMinorUnits
        case nonBillableMinutes
        case defaultHourlyRateMinorUnits
        case timeEntries
        case fixedCostEntries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(BucketStatus.self, forKey: .status)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        totalMinorUnits = try container.decode(Int.self, forKey: .totalMinorUnits)
        billableMinutes = try container.decode(Int.self, forKey: .billableMinutes)
        fixedCostMinorUnits = try container.decode(Int.self, forKey: .fixedCostMinorUnits)
        nonBillableMinutes = try container.decodeIfPresent(Int.self, forKey: .nonBillableMinutes) ?? 0
        defaultHourlyRateMinorUnits = try container.decodeIfPresent(Int.self, forKey: .defaultHourlyRateMinorUnits)
        timeEntries = try container.decodeIfPresent([WorkspaceTimeEntry].self, forKey: .timeEntries) ?? []
        fixedCostEntries = try container.decodeIfPresent([WorkspaceFixedCostEntry].self, forKey: .fixedCostEntries) ?? []
    }

    var billableHoursLabel: String {
        Self.hoursLabel(minutes: effectiveBillableMinutes)
    }

    var nonBillableHoursLabel: String {
        Self.hoursLabel(minutes: effectiveNonBillableMinutes)
    }

    var billableTimeMinorUnits: Int {
        effectiveBillableTimeMinorUnits
    }

    var effectiveBillableMinutes: Int {
        guard hasRowLevelEntries else { return billableMinutes }
        return timeEntries
            .filter(\.isBillable)
            .map(\.durationMinutes)
            .reduce(0, +)
    }

    var effectiveNonBillableMinutes: Int {
        guard hasRowLevelEntries else { return nonBillableMinutes }
        return timeEntries
            .filter { !$0.isBillable }
            .map(\.durationMinutes)
            .reduce(0, +)
    }

    var effectiveFixedCostMinorUnits: Int {
        guard hasRowLevelEntries else { return fixedCostMinorUnits }
        return fixedCostEntries.map(\.amountMinorUnits).reduce(0, +)
    }

    var effectiveBillableTimeMinorUnits: Int {
        guard hasRowLevelEntries else {
            return max(totalMinorUnits - fixedCostMinorUnits, 0)
        }

        return timeEntries.map(\.billableAmountMinorUnits).reduce(0, +)
    }

    var effectiveTotalMinorUnits: Int {
        guard hasRowLevelEntries else { return totalMinorUnits }
        return effectiveBillableTimeMinorUnits + effectiveFixedCostMinorUnits
    }

    var hasRowLevelEntries: Bool {
        !timeEntries.isEmpty || !fixedCostEntries.isEmpty
    }

    var hourlyRateMinorUnits: Int? {
        if let rate = timeEntries.first(where: { $0.isBillable && $0.hourlyRateMinorUnits > 0 })?.hourlyRateMinorUnits {
            return rate
        }

        if let defaultHourlyRateMinorUnits, defaultHourlyRateMinorUnits > 0 {
            return defaultHourlyRateMinorUnits
        }

        guard billableMinutes > 0 else { return nil }
        let inferredRate = billableTimeMinorUnits * 60 / billableMinutes
        return inferredRate > 0 ? inferredRate : nil
    }

    private static func hoursLabel(minutes: Int) -> String {
        let hours = Double(minutes) / 60
        if minutes.isMultiple(of: 60) {
            return "\(Int(hours))h"
        }

        return String(format: "%.1fh", locale: Locale(identifier: "en_US_POSIX"), hours)
    }
}

struct WorkspaceTimeEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var date: Date
    var startTime: String
    var endTime: String
    var durationMinutes: Int
    var description: String
    var isBillable: Bool
    var hourlyRateMinorUnits: Int

    init(
        id: UUID = UUID(),
        date: Date,
        startTime: String,
        endTime: String,
        durationMinutes: Int,
        description: String,
        isBillable: Bool = true,
        hourlyRateMinorUnits: Int
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.description = description
        self.isBillable = isBillable
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
    }

    var timeRangeLabel: String {
        guard !endTime.isEmpty else { return startTime }
        return "\(startTime)-\(endTime)"
    }

    var billableAmountMinorUnits: Int {
        guard isBillable else { return 0 }
        return durationMinutes * hourlyRateMinorUnits / 60
    }
}

struct WorkspaceFixedCostEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var date: Date
    var description: String
    var amountMinorUnits: Int

    init(
        id: UUID = UUID(),
        date: Date,
        description: String,
        amountMinorUnits: Int
    ) {
        self.id = id
        self.date = date
        self.description = description
        self.amountMinorUnits = amountMinorUnits
    }
}

struct WorkspaceInvoice: Codable, Equatable, Identifiable {
    let id: UUID
    var number: String
    var businessSnapshot: BusinessProfileProjection? = nil
    var clientSnapshot: WorkspaceClient? = nil
    var clientID: UUID? = nil
    var clientName: String
    var projectID: UUID? = nil
    var projectName: String = ""
    var bucketID: UUID? = nil
    var bucketName: String = ""
    var template: InvoiceTemplate = .kleinunternehmerClassic
    var issueDate: Date
    var dueDate: Date
    var servicePeriod: String = ""
    var status: InvoiceStatus
    var totalMinorUnits: Int
    var lineItems: [WorkspaceInvoiceLineItemSnapshot] = []
    var currencyCode: String = ""
    var note: String? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case businessSnapshot
        case clientSnapshot
        case clientID
        case clientName
        case projectID
        case projectName
        case bucketID
        case bucketName
        case template
        case issueDate
        case dueDate
        case servicePeriod
        case status
        case totalMinorUnits
        case lineItems
        case currencyCode
        case note
    }

    init(
        id: UUID,
        number: String,
        businessSnapshot: BusinessProfileProjection? = nil,
        clientSnapshot: WorkspaceClient? = nil,
        clientID: UUID? = nil,
        clientName: String,
        projectID: UUID? = nil,
        projectName: String = "",
        bucketID: UUID? = nil,
        bucketName: String = "",
        template: InvoiceTemplate = .kleinunternehmerClassic,
        issueDate: Date,
        dueDate: Date,
        servicePeriod: String = "",
        status: InvoiceStatus,
        totalMinorUnits: Int,
        lineItems: [WorkspaceInvoiceLineItemSnapshot] = [],
        currencyCode: String = "",
        note: String? = nil
    ) {
        self.id = id
        self.number = number
        self.businessSnapshot = businessSnapshot
        self.clientSnapshot = clientSnapshot
        self.clientID = clientID
        self.clientName = clientName
        self.projectID = projectID
        self.projectName = projectName
        self.bucketID = bucketID
        self.bucketName = bucketName
        self.template = template
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.servicePeriod = servicePeriod
        self.status = status
        self.totalMinorUnits = totalMinorUnits
        self.lineItems = lineItems
        self.currencyCode = currencyCode
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decode(String.self, forKey: .number)
        businessSnapshot = try container.decodeIfPresent(BusinessProfileProjection.self, forKey: .businessSnapshot)
        clientSnapshot = try container.decodeIfPresent(WorkspaceClient.self, forKey: .clientSnapshot)
        clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        clientName = try container.decode(String.self, forKey: .clientName)
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? ""
        bucketID = try container.decodeIfPresent(UUID.self, forKey: .bucketID)
        bucketName = try container.decodeIfPresent(String.self, forKey: .bucketName) ?? ""
        template = try container.decodeIfPresent(InvoiceTemplate.self, forKey: .template) ?? .kleinunternehmerClassic
        issueDate = try container.decode(Date.self, forKey: .issueDate)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        servicePeriod = try container.decodeIfPresent(String.self, forKey: .servicePeriod) ?? ""
        status = try container.decode(InvoiceStatus.self, forKey: .status)
        totalMinorUnits = try container.decode(Int.self, forKey: .totalMinorUnits)
        lineItems = try container.decodeIfPresent([WorkspaceInvoiceLineItemSnapshot].self, forKey: .lineItems) ?? []
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    func matches(
        projectID expectedProjectID: WorkspaceProject.ID,
        projectName expectedProjectName: String,
        bucketID expectedBucketID: WorkspaceBucket.ID,
        bucketName expectedBucketName: String
    ) -> Bool {
        let invoiceProjectName = projectName.isEmpty ? expectedProjectName : projectName
        let projectMatches = projectID == expectedProjectID || invoiceProjectName == expectedProjectName
        let bucketMatches = bucketID == expectedBucketID || bucketName == expectedBucketName
        return projectMatches && bucketMatches
    }
}

struct WorkspaceActivity: Codable, Equatable, Identifiable {
    let id: UUID
    var message: String
    var detail: String
    var occurredAt: Date

    init(id: UUID = UUID(), message: String, detail: String, occurredAt: Date) {
        self.id = id
        self.message = message
        self.detail = detail
        self.occurredAt = occurredAt
    }
}

struct WorkspaceInvoiceLineItemSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    var description: String
    var quantityLabel: String
    var amountMinorUnits: Int

    init(
        id: UUID = UUID(),
        description: String,
        quantityLabel: String,
        amountMinorUnits: Int
    ) {
        self.id = id
        self.description = description
        self.quantityLabel = quantityLabel
        self.amountMinorUnits = amountMinorUnits
    }
}

struct ProjectOverviewSummary: Equatable {
    var projectCount: Int
    var openMinorUnits: Int
    var readyMinorUnits: Int
    var overdueMinorUnits: Int
}
