import Foundation

struct WorkspaceSnapshot: Equatable {
    static let sampleToday = Date.pikaDate(year: 2026, month: 4, day: 27)

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

    var recentActivity: [WorkspaceActivity] {
        activity.sorted { left, right in
            if left.occurredAt == right.occurredAt {
                return left.message < right.message
            }

            return left.occurredAt > right.occurredAt
        }
    }

    static let sample = WorkspaceSnapshot(
        businessProfile: BusinessProfileProjection(
            businessName: "Ehrax Studio",
            email: "hello@ehrax.dev",
            address: "Lisbon, Portugal",
            invoicePrefix: "EHX",
            nextInvoiceNumber: 5,
            currencyCode: "EUR",
            paymentDetails: "IBAN PT50 0000 0000 0000 0000 0000 0",
            taxNote: "VAT reverse charge where applicable.",
            defaultTermsDays: 14
        ),
        clients: [
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "Happ.ines",
                email: "billing@happines.example",
                billingAddress: "Rua da Alegria 42, Porto",
                defaultTermsDays: 14
            ),
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "Northstar Labs",
                email: "accounts@northstar.example",
                billingAddress: "12 Polaris Yard, Berlin",
                defaultTermsDays: 14
            ),
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "Acme Studio",
                email: "finance@acme.example",
                billingAddress: "5 Market Street, Dublin",
                defaultTermsDays: 30
            ),
        ],
        projects: [
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                name: "Launch sprint",
                clientName: "Happ.ines",
                currencyCode: "EUR",
                isArchived: false,
                buckets: [
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                        name: "April sprint",
                        status: .ready,
                        totalMinorUnits: 250_000,
                        billableMinutes: 1_200,
                        fixedCostMinorUnits: 50_000
                    ),
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
                        name: "Discovery notes",
                        status: .open,
                        totalMinorUnits: 65_000,
                        billableMinutes: 390,
                        fixedCostMinorUnits: 0
                    ),
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
                        name: "Internal planning",
                        status: .open,
                        totalMinorUnits: 0,
                        billableMinutes: 0,
                        fixedCostMinorUnits: 0
                    ),
                ],
                invoices: []
            ),
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                name: "Mobile QA",
                clientName: "Northstar Labs",
                currencyCode: "EUR",
                isArchived: false,
                buckets: [
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000004")!,
                        name: "Regression pass",
                        status: .ready,
                        totalMinorUnits: 157_500,
                        billableMinutes: 630,
                        fixedCostMinorUnits: 0
                    ),
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000005")!,
                        name: "Follow-up checks",
                        status: .open,
                        totalMinorUnits: 30_000,
                        billableMinutes: 120,
                        fixedCostMinorUnits: 0
                    ),
                ],
                invoices: [
                    WorkspaceInvoice(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                        number: "EHX-2026-004",
                        clientName: "Northstar Labs",
                        projectName: "Mobile QA",
                        bucketName: "Regression pass",
                        issueDate: Date.pikaDate(year: 2026, month: 4, day: 20),
                        dueDate: Date.pikaDate(year: 2026, month: 5, day: 4),
                        status: .finalized,
                        totalMinorUnits: 120_000,
                        lineItems: [
                            WorkspaceInvoiceLineItemSnapshot(
                                description: "Regression pass QA",
                                quantityLabel: "8h",
                                amountMinorUnits: 120_000
                            ),
                        ]
                    ),
                ]
            ),
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                name: "Brand refresh",
                clientName: "Acme Studio",
                currencyCode: "EUR",
                isArchived: true,
                buckets: [
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000006")!,
                        name: "Visual language",
                        status: .finalized,
                        totalMinorUnits: 125_000,
                        billableMinutes: 600,
                        fixedCostMinorUnits: 25_000
                    ),
                ],
                invoices: [
                    WorkspaceInvoice(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
                        number: "EHX-2026-003",
                        clientName: "Acme Studio",
                        projectName: "Brand refresh",
                        bucketName: "Visual language",
                        issueDate: Date.pikaDate(year: 2026, month: 3, day: 16),
                        dueDate: Date.pikaDate(year: 2026, month: 4, day: 10),
                        status: .sent,
                        totalMinorUnits: 125_000,
                        lineItems: [
                            WorkspaceInvoiceLineItemSnapshot(
                                description: "Billable design time",
                                quantityLabel: "10h",
                                amountMinorUnits: 100_000
                            ),
                            WorkspaceInvoiceLineItemSnapshot(
                                description: "Fixed costs",
                                quantityLabel: "1 item",
                                amountMinorUnits: 25_000
                            ),
                        ]
                    ),
                ]
            ),
        ],
        activity: [
            WorkspaceActivity(message: "EHX-2026-004 finalized", detail: "Northstar Labs", occurredAt: Date.pikaDate(year: 2026, month: 4, day: 20)),
            WorkspaceActivity(message: "Regression pass marked ready", detail: "Mobile QA", occurredAt: Date.pikaDate(year: 2026, month: 4, day: 18)),
            WorkspaceActivity(message: "April sprint marked ready", detail: "Launch sprint", occurredAt: Date.pikaDate(year: 2026, month: 4, day: 17)),
        ]
    )

    func dashboardSummary(on date: Date = .now) -> DashboardSummary {
        let invoices = projects.flatMap(\.invoices)
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
                    title: readyAttentionTitle(for: project),
                    detail: "\(bucket.name) has \(bucket.billableHoursLabel) billable",
                    amountMinorUnits: bucket.totalMinorUnits,
                    tone: .success
                )
            }

        return DashboardSummary(
            outstandingMinorUnits: unpaidInvoices.map(\.totalMinorUnits).reduce(0, +),
            overdueMinorUnits: overdueInvoices.map(\.amountMinorUnits).reduce(0, +),
            readyToInvoiceMinorUnits: readyBuckets.map(\.bucket.totalMinorUnits).reduce(0, +),
            thisMonthMinorUnits: invoices
                .filter { Calendar.pikaGregorian.isDate($0.issueDate, equalTo: date, toGranularity: .month) }
                .map(\.totalMinorUnits)
                .reduce(0, +),
            activeProjectCount: activeProjects.count,
            clientCount: clients.count,
            needsAttention: overdueInvoices + readyItems,
            revenueHistory: [
                RevenuePoint(label: "May 25", amountMinorUnits: 208_000),
                RevenuePoint(label: "Jun", amountMinorUnits: 246_000),
                RevenuePoint(label: "Jul", amountMinorUnits: 218_000),
                RevenuePoint(label: "Aug", amountMinorUnits: 272_000),
                RevenuePoint(label: "Sep", amountMinorUnits: 248_000),
                RevenuePoint(label: "Oct", amountMinorUnits: 304_000),
                RevenuePoint(label: "Nov", amountMinorUnits: 284_000),
                RevenuePoint(label: "Dec", amountMinorUnits: 342_000),
                RevenuePoint(label: "Jan", amountMinorUnits: 90_000),
                RevenuePoint(label: "Feb", amountMinorUnits: 140_000),
                RevenuePoint(label: "Mar", amountMinorUnits: 125_000),
                RevenuePoint(label: "Apr 26", amountMinorUnits: 120_000),
            ]
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

struct BusinessProfileProjection: Equatable {
    var businessName: String
    var email: String
    var address: String
    var invoicePrefix: String
    var nextInvoiceNumber: Int
    var currencyCode: String
    var paymentDetails: String
    var taxNote: String
    var defaultTermsDays: Int
}

struct WorkspaceClient: Equatable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var billingAddress: String
    var defaultTermsDays: Int
}

struct WorkspaceProject: Equatable, Identifiable {
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
        buckets.map(\.totalMinorUnits).reduce(0, +)
    }

    var openBucketMinorUnits: Int {
        buckets
            .filter { $0.status == .open }
            .map(\.totalMinorUnits)
            .reduce(0, +)
    }

    var readyToInvoiceMinorUnits: Int {
        buckets
            .filter { $0.status == .ready }
            .map(\.totalMinorUnits)
            .reduce(0, +)
    }

    func overdueInvoiceCount(on date: Date) -> Int {
        invoices.filter { $0.status.isOverdue(dueDate: $0.dueDate, on: date) }.count
    }

    func detailProjection(
        selectedBucketID: WorkspaceBucket.ID? = nil,
        formatter: MoneyFormatting
    ) -> WorkspaceBucketDetailProjection? {
        guard let selectedBucket = bucket(matching: selectedBucketID) ?? buckets.first else {
            return nil
        }

        return WorkspaceBucketDetailProjection(
            project: self,
            selectedBucket: selectedBucket,
            bucketRows: buckets.map { bucket in
                WorkspaceBucketRowProjection(bucket: bucket, formatter: formatter)
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
}

struct WorkspaceBucket: Equatable, Identifiable {
    let id: UUID
    var name: String
    var status: BucketStatus
    var totalMinorUnits: Int
    var billableMinutes: Int
    var fixedCostMinorUnits: Int
    var nonBillableMinutes: Int = 0

    var billableHoursLabel: String {
        let hours = Double(billableMinutes) / 60
        return hours.formatted(.number.precision(.fractionLength(0...1))) + "h"
    }

    var nonBillableHoursLabel: String {
        let hours = Double(nonBillableMinutes) / 60
        return hours.formatted(.number.precision(.fractionLength(0...1))) + "h"
    }

    var billableTimeMinorUnits: Int {
        max(totalMinorUnits - fixedCostMinorUnits, 0)
    }
}

struct WorkspaceInvoice: Equatable, Identifiable {
    let id: UUID
    var number: String
    var businessSnapshot: BusinessProfileProjection? = nil
    var clientSnapshot: WorkspaceClient? = nil
    var clientName: String
    var projectName: String = ""
    var bucketName: String = ""
    var issueDate: Date
    var dueDate: Date
    var status: InvoiceStatus
    var totalMinorUnits: Int
    var lineItems: [WorkspaceInvoiceLineItemSnapshot] = []
    var currencyCode: String = ""
    var note: String? = nil
}

struct WorkspaceActivity: Equatable, Identifiable {
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

struct WorkspaceInvoiceLineItemSnapshot: Equatable, Identifiable {
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

struct DashboardAttentionItem: Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var amountMinorUnits: Int
    var tone: PikaStatusTone

    init(
        id: String,
        title: String,
        detail: String,
        amountMinorUnits: Int,
        tone: PikaStatusTone
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.amountMinorUnits = amountMinorUnits
        self.tone = tone
    }
}

struct RevenuePoint: Equatable, Identifiable {
    var label: String
    var amountMinorUnits: Int

    var id: String {
        label
    }
}

struct WorkspaceBucketRowProjection: Equatable, Identifiable {
    let id: WorkspaceBucket.ID
    let name: String
    let meta: String
    let status: BucketStatus
    let statusTitle: String?

    init(bucket: WorkspaceBucket, formatter: MoneyFormatting) {
        id = bucket.id
        name = bucket.name
        status = bucket.status

        let amount = formatter.string(fromMinorUnits: bucket.totalMinorUnits)
        if bucket.fixedCostMinorUnits > 0 {
            let fixedCost = formatter.string(fromMinorUnits: bucket.fixedCostMinorUnits)
            meta = "\(bucket.billableHoursLabel) · \(amount) · \(fixedCost) fixed"
        } else {
            meta = "\(bucket.billableHoursLabel) · \(amount)"
        }

        statusTitle = bucket.status == .open ? nil : bucket.status.rawValue.capitalized
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
        totalLabel = formatter.string(fromMinorUnits: selectedBucket.totalMinorUnits)
        billableSummary = "\(selectedBucket.billableHoursLabel) billable"
        nonBillableSummary = "\(selectedBucket.nonBillableHoursLabel) non-billable"
        fixedCostLabel = "\(formatter.string(fromMinorUnits: selectedBucket.fixedCostMinorUnits)) fixed"
        lineItems = [
            WorkspaceBucketLineItemProjection(
                description: "Billable time",
                quantity: selectedBucket.billableHoursLabel,
                amountLabel: formatter.string(fromMinorUnits: selectedBucket.billableTimeMinorUnits),
                isBillable: true
            ),
            WorkspaceBucketLineItemProjection(
                description: "Fixed costs",
                quantity: selectedBucket.fixedCostMinorUnits > 0 ? "1 item" : "0 items",
                amountLabel: formatter.string(fromMinorUnits: selectedBucket.fixedCostMinorUnits),
                isBillable: selectedBucket.fixedCostMinorUnits > 0
            ),
            WorkspaceBucketLineItemProjection(
                description: "Non-billable time",
                quantity: selectedBucket.nonBillableHoursLabel,
                amountLabel: "n/b",
                isBillable: false
            ),
        ]
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
    let issueDate: Date
    let dueDate: Date
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
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
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
                amountLabel: formatter.string(fromMinorUnits: item.amountMinorUnits)
            )
        }
    }
}

struct WorkspaceInvoiceLineItemProjection: Equatable, Identifiable {
    let id: UUID
    let description: String
    let quantityLabel: String
    let amountLabel: String
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

private extension Calendar {
    static let pikaGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}

private extension Date {
    static func pikaDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.pikaGregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
