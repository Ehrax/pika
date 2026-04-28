import Foundation

struct WorkspaceSnapshot: Codable, Equatable {
    static let empty = WorkspaceSnapshot(
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

    var businessProfile: BusinessProfileProjection
    var clients: [WorkspaceClient]
    var projects: [WorkspaceProject]
    var activity: [WorkspaceActivity]

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

    func dashboardSummary(on date: Date = .now) -> DashboardSummary {
        let invoices = projects.flatMap(\.invoices)
        let paidInvoices = invoices.filter { $0.status == .paid }
        let unpaidInvoices = invoices.filter { $0.status == .finalized || $0.status == .sent }
        let readyBuckets = projects.flatMap { project in
            project.buckets
                .filter { $0.status == .ready }
                .map { bucket in
                    (project: project, bucket: bucket)
                }
        }

        let overdueInvoices = projects.flatMap { project in
            project.invoices
                .filter { $0.status.isOverdue(dueDate: $0.dueDate, on: date) }
                .map { invoice in
                    DashboardAttentionItem(
                        id: "overdue-invoice-\(invoice.id.uuidString)",
                        target: .invoice(invoice.id),
                        title: "\(invoice.clientName) invoice overdue",
                        detail: "\(invoice.number) due \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))",
                        amountMinorUnits: invoice.totalMinorUnits,
                        tone: .danger
                    )
                }
        }

        let readyItems = readyBuckets
            .sorted { left, right in
                if left.project.name == right.project.name {
                    return left.bucket.name < right.bucket.name
                }

                return left.project.name > right.project.name
            }
            .map { project, bucket in
                DashboardAttentionItem(
                    id: "ready-bucket-\(bucket.id.uuidString)",
                    target: .bucket(projectID: project.id, bucketID: bucket.id),
                    title: readyAttentionTitle(for: project),
                    detail: "\(bucket.name) has \(bucket.billableHoursLabel) billable",
                    amountMinorUnits: bucket.effectiveTotalMinorUnits,
                    tone: .success
                )
            }

        return DashboardSummary(
            outstandingMinorUnits: unpaidInvoices.map(\.totalMinorUnits).reduce(0, +),
            overdueMinorUnits: overdueInvoices.map(\.amountMinorUnits).reduce(0, +),
            readyToInvoiceMinorUnits: readyBuckets.map(\.bucket.effectiveTotalMinorUnits).reduce(0, +),
            thisMonthMinorUnits: paidInvoices
                .filter { Calendar.pikaGregorian.isDate($0.issueDate, equalTo: date, toGranularity: .month) }
                .map(\.totalMinorUnits)
                .reduce(0, +),
            activeProjectCount: activeProjects.count,
            clientCount: clients.count,
            needsAttention: overdueInvoices + readyItems,
            revenueHistory: paidInvoices
                .sorted { left, right in
                    if left.issueDate == right.issueDate {
                        return left.number < right.number
                    }

                    return left.issueDate < right.issueDate
                }
                .map { invoice in
                    RevenuePoint(
                        date: invoice.issueDate,
                        label: invoice.number,
                        amountMinorUnits: invoice.totalMinorUnits
                    )
                }
        )
    }

    func project(named name: String) -> WorkspaceProject? {
        projects.first { $0.name == name }
    }

    func projectOverviewSummary(for projects: [WorkspaceProject], on date: Date) -> ProjectOverviewSummary {
        let overdueInvoices = projects.flatMap(\.invoices)
            .filter { $0.status.isOverdue(dueDate: $0.dueDate, on: date) }

        return ProjectOverviewSummary(
            projectCount: projects.count,
            openMinorUnits: projects.map(\.openBucketMinorUnits).reduce(0, +),
            readyMinorUnits: projects.map(\.readyToInvoiceMinorUnits).reduce(0, +),
            overdueMinorUnits: overdueInvoices.map(\.totalMinorUnits).reduce(0, +)
        )
    }

    private func readyAttentionTitle(for project: WorkspaceProject) -> String {
        "\(project.clientName) \(project.name.lowercased()) ready to invoice"
    }

}

extension Date {
    static func pikaDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.pikaGregorian.date(from: DateComponents(year: year, month: month, day: day))!
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

    func detailProjection(
        selectedBucketID: WorkspaceBucket.ID? = nil,
        formatter: MoneyFormatting,
        on date: Date = .now
    ) -> WorkspaceBucketDetailProjection? {
        guard let selectedBucket = bucket(matching: selectedBucketID) ?? buckets.first else {
            return nil
        }

        return WorkspaceBucketDetailProjection(
            project: self,
            selectedBucket: selectedBucket,
            bucketRows: buckets.map { bucket in
                WorkspaceBucketRowProjection(
                    bucket: bucket,
                    linkedInvoice: latestInvoice(for: bucket),
                    formatter: formatter,
                    on: date
                )
            },
            formatter: formatter
        )
    }

    func normalizedBucketID(_ id: WorkspaceBucket.ID?) -> WorkspaceBucket.ID? {
        (bucket(matching: id) ?? buckets.first)?.id
    }

    private func bucket(matching id: WorkspaceBucket.ID?) -> WorkspaceBucket? {
        guard let id else { return nil }
        return buckets.first { $0.id == id }
    }

    private func latestInvoice(for bucket: WorkspaceBucket) -> WorkspaceInvoice? {
        invoices
            .filter { invoice in
                let invoiceProjectName = invoice.projectName.isEmpty ? name : invoice.projectName
                return invoiceProjectName == name && invoice.bucketName == bucket.name
            }
            .sorted { left, right in
                if left.issueDate == right.issueDate {
                    return left.number > right.number
                }

                return left.issueDate > right.issueDate
            }
            .first
    }
}

struct WorkspaceBucket: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var status: BucketStatus
    var totalMinorUnits: Int
    var billableMinutes: Int
    var fixedCostMinorUnits: Int
    var nonBillableMinutes: Int = 0
    var defaultHourlyRateMinorUnits: Int? = nil
    var timeEntries: [WorkspaceTimeEntry] = []
    var fixedCostEntries: [WorkspaceFixedCostEntry] = []

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
    var clientName: String
    var projectName: String = ""
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
        case clientName
        case projectName
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
        clientName: String,
        projectName: String = "",
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
        self.clientName = clientName
        self.projectName = projectName
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
        clientName = try container.decode(String.self, forKey: .clientName)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? ""
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

struct DashboardSummary: Equatable {
    var outstandingMinorUnits: Int
    var overdueMinorUnits: Int
    var readyToInvoiceMinorUnits: Int
    var thisMonthMinorUnits: Int
    var activeProjectCount: Int
    var clientCount: Int
    var needsAttention: [DashboardAttentionItem]
    var revenueHistory: [RevenuePoint]
}

struct ProjectOverviewSummary: Equatable {
    var projectCount: Int
    var openMinorUnits: Int
    var readyMinorUnits: Int
    var overdueMinorUnits: Int
}

enum DashboardAttentionTarget: Equatable {
    case invoice(WorkspaceInvoice.ID)
    case bucket(projectID: WorkspaceProject.ID, bucketID: WorkspaceBucket.ID)
}

struct DashboardAttentionItem: Equatable, Identifiable {
    var id: String
    var target: DashboardAttentionTarget
    var title: String
    var detail: String
    var amountMinorUnits: Int
    var tone: PikaStatusTone

    init(
        id: String,
        target: DashboardAttentionTarget,
        title: String,
        detail: String,
        amountMinorUnits: Int,
        tone: PikaStatusTone
    ) {
        self.id = id
        self.target = target
        self.title = title
        self.detail = detail
        self.amountMinorUnits = amountMinorUnits
        self.tone = tone
    }
}

struct RevenuePoint: Equatable, Identifiable {
    var date: Date
    var label: String
    var amountMinorUnits: Int

    init(date: Date = .distantPast, label: String, amountMinorUnits: Int) {
        self.date = date
        self.label = label
        self.amountMinorUnits = amountMinorUnits
    }

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(label)"
    }
}

struct WorkspaceBucketRowProjection: Equatable, Identifiable {
    let id: WorkspaceBucket.ID
    let name: String
    let meta: String
    let status: BucketStatus
    let statusTitle: String?
    let statusTone: PikaStatusTone

    init(
        bucket: WorkspaceBucket,
        linkedInvoice: WorkspaceInvoice? = nil,
        formatter: MoneyFormatting,
        on date: Date = .now
    ) {
        id = bucket.id
        name = bucket.name
        status = bucket.status

        let amount = formatter.string(fromMinorUnits: bucket.effectiveTotalMinorUnits)
        if bucket.effectiveFixedCostMinorUnits > 0 {
            let fixedCost = formatter.string(fromMinorUnits: bucket.effectiveFixedCostMinorUnits)
            meta = "\(bucket.billableHoursLabel) · \(amount) · \(fixedCost) fixed"
        } else {
            meta = "\(bucket.billableHoursLabel) · \(amount)"
        }

        if let linkedInvoice {
            statusTitle = linkedInvoice.status.displayTitle(dueDate: linkedInvoice.dueDate, on: date)
            statusTone = linkedInvoice.status.displayTone(dueDate: linkedInvoice.dueDate, on: date)
        } else {
            statusTitle = bucket.status == .open ? nil : bucket.status.rawValue.capitalized
            statusTone = bucket.status.displayTone
        }
    }
}

private extension InvoiceStatus {
    func displayTitle(dueDate: Date, on date: Date) -> String {
        isOverdue(dueDate: dueDate, on: date) ? "Overdue" : rawValue.capitalized
    }

    func displayTone(dueDate: Date, on date: Date) -> PikaStatusTone {
        if isOverdue(dueDate: dueDate, on: date) { return .danger }

        switch self {
        case .finalized:
            return .warning
        case .sent:
            return .neutral
        case .paid:
            return .success
        case .cancelled:
            return .neutral
        }
    }
}

private extension BucketStatus {
    var displayTone: PikaStatusTone {
        switch self {
        case .open:
            return .neutral
        case .ready:
            return .success
        case .finalized:
            return .warning
        case .archived:
            return .neutral
        }
    }
}

struct WorkspaceBucketDetailProjection: Equatable {
    let selectedBucket: WorkspaceBucket
    let bucketRows: [WorkspaceBucketRowProjection]
    let title: String
    let projectName: String
    let clientName: String
    let currencyCode: String
    let totalLabel: String
    let billableSummary: String
    let nonBillableSummary: String
    let fixedCostLabel: String
    let rateLabel: String
    let entryRows: [WorkspaceBucketEntryRowProjection]
    let lineItems: [WorkspaceBucketLineItemProjection]

    init(
        project: WorkspaceProject,
        selectedBucket: WorkspaceBucket,
        bucketRows: [WorkspaceBucketRowProjection],
        formatter: MoneyFormatting
    ) {
        self.selectedBucket = selectedBucket
        self.bucketRows = bucketRows
        title = selectedBucket.name
        projectName = project.name
        clientName = project.clientName
        currencyCode = project.currencyCode
        totalLabel = formatter.string(fromMinorUnits: selectedBucket.effectiveTotalMinorUnits)
        billableSummary = "\(selectedBucket.billableHoursLabel) billable"
        nonBillableSummary = "\(selectedBucket.nonBillableHoursLabel) non-billable"
        fixedCostLabel = "\(formatter.string(fromMinorUnits: selectedBucket.effectiveFixedCostMinorUnits)) fixed"
        rateLabel = selectedBucket.hourlyRateMinorUnits.map { "\(formatter.string(fromMinorUnits: $0))/h" } ?? "n/b"
        entryRows = selectedBucket.entryRows(formatter: formatter)
        lineItems = [
            WorkspaceBucketLineItemProjection(
                description: selectedBucket.name,
                quantity: selectedBucket.billableHoursLabel,
                amountLabel: formatter.string(fromMinorUnits: selectedBucket.billableTimeMinorUnits),
                isBillable: true
            ),
            WorkspaceBucketLineItemProjection(
                description: selectedBucket.fixedCostLineItemDescription,
                quantity: selectedBucket.effectiveFixedCostMinorUnits > 0 ? max(selectedBucket.fixedCostEntries.count, 1).formattedItemCount : "0 items",
                amountLabel: formatter.string(fromMinorUnits: selectedBucket.effectiveFixedCostMinorUnits),
                isBillable: selectedBucket.effectiveFixedCostMinorUnits > 0
            ),
        ].filter { $0.isBillable }
    }
}

private extension Int {
    var formattedItemCount: String {
        self == 1 ? "1 item" : "\(self) items"
    }
}

private extension WorkspaceBucket {
    var fixedCostLineItemDescription: String {
        guard fixedCostEntries.count == 1,
              let description = fixedCostEntries.first?.description.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty
        else {
            return "Fixed costs"
        }

        return description
    }
}

struct WorkspaceBucketLineItemProjection: Equatable, Identifiable {
    var id: String {
        description
    }

    let description: String
    let quantity: String
    let amountLabel: String
    let isBillable: Bool
}

struct WorkspaceInvoicePreviewProjection: Equatable {
    let selectedInvoice: WorkspaceInvoice
    let selectedRow: WorkspaceInvoiceRowProjection
    let rows: [WorkspaceInvoiceRowProjection]
}

struct WorkspaceInvoiceRowProjection: Equatable, Identifiable {
    let id: WorkspaceInvoice.ID
    let number: String
    let businessProfile: BusinessProfileProjection?
    let clientName: String
    let projectName: String
    let bucketName: String
    let template: InvoiceTemplate
    let issueDate: Date
    let dueDate: Date
    let servicePeriod: String
    let status: InvoiceStatus
    let statusTitle: String
    let isOverdue: Bool
    let totalLabel: String
    let billingAddress: String
    let lineItems: [WorkspaceInvoiceLineItemProjection]
    let invoice: WorkspaceInvoice

    init(
        invoice: WorkspaceInvoice,
        projectName: String,
        billingAddress: String,
        on date: Date,
        formatter: MoneyFormatting
    ) {
        id = invoice.id
        number = invoice.number
        businessProfile = invoice.businessSnapshot
        clientName = invoice.clientSnapshot?.name ?? invoice.clientName
        self.projectName = invoice.projectName.isEmpty ? projectName : invoice.projectName
        bucketName = invoice.bucketName.isEmpty ? "Project services" : invoice.bucketName
        template = invoice.template
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        servicePeriod = invoice.servicePeriod
        status = invoice.status
        isOverdue = invoice.status.isOverdue(dueDate: invoice.dueDate, on: date)
        statusTitle = isOverdue ? "Overdue" : invoice.status.rawValue.capitalized
        totalLabel = formatter.string(fromMinorUnits: invoice.totalMinorUnits)
        self.billingAddress = invoice.clientSnapshot?.billingAddress ?? billingAddress
        lineItems = Self.lineItems(for: invoice, formatter: formatter)
        self.invoice = invoice
    }

    private static func lineItems(
        for invoice: WorkspaceInvoice,
        formatter: MoneyFormatting
    ) -> [WorkspaceInvoiceLineItemProjection] {
        let snapshots = invoice.lineItems.isEmpty
            ? [
                WorkspaceInvoiceLineItemSnapshot(
                    id: invoice.id,
                    description: "Services rendered",
                    quantityLabel: "1 item",
                    amountMinorUnits: invoice.totalMinorUnits
                ),
            ]
            : invoice.lineItems

        return snapshots.map { item in
            WorkspaceInvoiceLineItemProjection(
                id: item.id,
                description: item.description,
                quantityLabel: item.quantityLabel,
                amountMinorUnits: item.amountMinorUnits,
                formatter: formatter,
                amountLabel: formatter.string(fromMinorUnits: item.amountMinorUnits)
            )
        }
    }
}

struct WorkspaceInvoiceLineItemProjection: Equatable, Identifiable {
    let id: UUID
    let description: String
    let quantityLabel: String
    let quantityValueLabel: String
    let unitLabel: String
    let unitPriceLabel: String
    let amountLabel: String

    init(
        id: UUID,
        description: String,
        quantityLabel: String,
        amountMinorUnits: Int,
        formatter: MoneyFormatting,
        amountLabel: String
    ) {
        self.id = id
        self.description = description
        self.quantityLabel = quantityLabel
        self.amountLabel = amountLabel

        let quantityUnit = Self.quantityUnit(from: quantityLabel)
        quantityValueLabel = quantityUnit.quantity
        unitLabel = quantityUnit.unit
        unitPriceLabel = Self.unitPriceLabel(
            quantity: quantityUnit.numericQuantity,
            amountMinorUnits: amountMinorUnits,
            formatter: formatter
        )
    }

    private static func quantityUnit(from label: String) -> (quantity: String, numericQuantity: Double?, unit: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasSuffix("h") {
            let value = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return (localizedDecimal(value), numericQuantity(from: value), "Stunden")
        }

        if lowercased.hasSuffix("hours") || lowercased.hasSuffix("hour") {
            let parts = trimmed.split(separator: " ")
            let value = parts.first.map(String.init) ?? trimmed
            return (localizedDecimal(value), numericQuantity(from: value), "Stunden")
        }

        if lowercased.hasSuffix("items") || lowercased.hasSuffix("item") {
            let parts = trimmed.split(separator: " ")
            let value = parts.first.map(String.init) ?? trimmed
            return (localizedDecimal(value), numericQuantity(from: value), "Stück")
        }

        return (trimmed, numericQuantity(from: trimmed), "")
    }

    private static func localizedDecimal(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: ",")
    }

    private static func numericQuantity(from value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private static func unitPriceLabel(
        quantity: Double?,
        amountMinorUnits: Int,
        formatter: MoneyFormatting
    ) -> String {
        guard let quantity, quantity > 0 else { return "" }

        let unitAmount = Int((Double(amountMinorUnits) / quantity).rounded())
        return formatter.string(fromMinorUnits: unitAmount)
    }
}

extension WorkspaceSnapshot {
    func invoicePreviewProjection(
        selectedInvoiceID: WorkspaceInvoice.ID? = nil,
        on date: Date,
        formatter: MoneyFormatting
    ) -> WorkspaceInvoicePreviewProjection? {
        let rows = projects
            .flatMap { project in
                project.invoices.map { invoice in
                    (projectName: project.name, invoice: invoice)
                }
            }
            .sorted { left, right in
                if left.invoice.issueDate == right.invoice.issueDate {
                    return left.invoice.number > right.invoice.number
                }

                return left.invoice.issueDate > right.invoice.issueDate
            }
            .map { projectName, invoice in
                WorkspaceInvoiceRowProjection(
                    invoice: invoice,
                    projectName: projectName,
                    billingAddress: clients.first { $0.name == invoice.clientName }?.billingAddress ?? "",
                    on: date,
                    formatter: formatter
                )
            }

        guard let selectedRow = rows.first(where: { $0.id == selectedInvoiceID }) ?? rows.first else {
            return nil
        }

        return WorkspaceInvoicePreviewProjection(
            selectedInvoice: selectedRow.invoice,
            selectedRow: selectedRow,
            rows: rows
        )
    }
}

extension Calendar {
    static let pikaGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}
