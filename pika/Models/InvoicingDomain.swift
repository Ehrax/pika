import Foundation

enum BucketStatus: String, CaseIterable, Equatable {
    case open
    case ready
    case finalized
    case archived

    var isInvoiceLocked: Bool {
        self == .finalized || self == .archived
    }

    var eventLabel: String {
        rawValue
    }
}

enum InvoiceStatus: String, CaseIterable, Equatable {
    case finalized
    case sent
    case paid
    case cancelled

    func isOverdue(dueDate: Date, on date: Date = .now) -> Bool {
        switch self {
        case .finalized, .sent:
            date > dueDate
        case .paid, .cancelled:
            false
        }
    }
}

struct TimeEntry: Equatable, Identifiable {
    let id: UUID
    var date: Date
    var description: String
    var durationMinutes: Int
    var rateMinorUnits: Int
    var isBillable: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        description: String,
        durationMinutes: Int,
        rateMinorUnits: Int,
        isBillable: Bool
    ) {
        self.id = id
        self.date = date
        self.description = description
        self.durationMinutes = durationMinutes
        self.rateMinorUnits = rateMinorUnits
        self.isBillable = isBillable
    }

    var amountMinorUnits: Int {
        guard isBillable else { return 0 }
        return roundedMinorUnits(numerator: durationMinutes * rateMinorUnits, denominator: 60)
    }
}

struct FixedCostEntry: Equatable, Identifiable {
    let id: UUID
    var date: Date
    var description: String
    var quantity: Int
    var unitPriceMinorUnits: Int
    var isBillable: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        description: String,
        quantity: Int,
        unitPriceMinorUnits: Int,
        isBillable: Bool
    ) {
        self.id = id
        self.date = date
        self.description = description
        self.quantity = quantity
        self.unitPriceMinorUnits = unitPriceMinorUnits
        self.isBillable = isBillable
    }

    var amountMinorUnits: Int {
        guard isBillable else { return 0 }
        return quantity * unitPriceMinorUnits
    }
}

struct InvoiceBucket: Equatable, Identifiable {
    let id: UUID
    var name: String
    var status: BucketStatus
    var timeEntries: [TimeEntry]
    var fixedCosts: [FixedCostEntry]

    init(
        id: UUID = UUID(),
        name: String,
        status: BucketStatus,
        timeEntries: [TimeEntry] = [],
        fixedCosts: [FixedCostEntry] = []
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.timeEntries = timeEntries
        self.fixedCosts = fixedCosts
    }

    var totals: BucketTotals {
        BucketTotals(timeEntries: timeEntries, fixedCosts: fixedCosts)
    }

    var canMarkReady: Bool {
        status == .open && totals.totalMinorUnits > 0
    }

    enum MarkReadyError: Error, Equatable {
        case notInvoiceable
        case lockedStatus(BucketStatus)
    }

    struct MarkReadyResult: Equatable {
        let bucket: InvoiceBucket
        let activityEvents: [ActivityEvent]
    }

    func markReady() throws -> MarkReadyResult {
        guard status == .open else {
            throw MarkReadyError.lockedStatus(status)
        }

        guard totals.totalMinorUnits > 0 else {
            throw MarkReadyError.notInvoiceable
        }

        let readyBucket = withStatus(.ready)

        return MarkReadyResult(
            bucket: readyBucket,
            activityEvents: [
                .bucketReady(bucketID: id, bucketName: name),
                .statusChanged(entityID: id, from: status.eventLabel, to: readyBucket.status.eventLabel),
            ]
        )
    }

    func withStatus(_ status: BucketStatus) -> InvoiceBucket {
        var copy = self
        copy.status = status
        return copy
    }
}

struct BucketTotals: Equatable {
    let billableMinutes: Int
    let nonBillableMinutes: Int
    let timeSubtotalMinorUnits: Int
    let fixedSubtotalMinorUnits: Int
    let totalMinorUnits: Int

    init(timeEntries: [TimeEntry], fixedCosts: [FixedCostEntry]) {
        billableMinutes = timeEntries
            .filter(\.isBillable)
            .map(\.durationMinutes)
            .reduce(0, +)
        nonBillableMinutes = timeEntries
            .filter { !$0.isBillable }
            .map(\.durationMinutes)
            .reduce(0, +)
        timeSubtotalMinorUnits = timeEntries
            .map(\.amountMinorUnits)
            .reduce(0, +)
        fixedSubtotalMinorUnits = fixedCosts
            .map(\.amountMinorUnits)
            .reduce(0, +)
        totalMinorUnits = timeSubtotalMinorUnits + fixedSubtotalMinorUnits
    }
}

struct BusinessSnapshot: Equatable {
    var name: String
    var email: String
    var address: String
}

struct ClientSnapshot: Equatable {
    var name: String
    var email: String
    var billingAddress: String
}

struct ProjectSnapshot: Equatable {
    var name: String
    var currencyCode: String
}

enum InvoiceLineQuantity: Equatable {
    case minutes(Int)
    case units(Int)
}

struct InvoiceLineSnapshot: Equatable, Identifiable {
    enum Kind: String, Equatable {
        case time
        case fixedCost
    }

    let id: UUID
    let kind: Kind
    let date: Date
    let description: String
    let quantity: InvoiceLineQuantity
    let unitPriceMinorUnits: Int
    let amountMinorUnits: Int

    init(
        id: UUID = UUID(),
        kind: Kind,
        date: Date,
        description: String,
        quantity: InvoiceLineQuantity,
        unitPriceMinorUnits: Int,
        amountMinorUnits: Int
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.description = description
        self.quantity = quantity
        self.unitPriceMinorUnits = unitPriceMinorUnits
        self.amountMinorUnits = amountMinorUnits
    }
}

struct Invoice: Equatable, Identifiable {
    let id: UUID
    let number: String
    let business: BusinessSnapshot
    let client: ClientSnapshot
    let project: ProjectSnapshot
    let bucketID: UUID
    let bucketName: String
    let issueDate: Date
    let dueDate: Date
    let status: InvoiceStatus
    let lines: [InvoiceLineSnapshot]
    let totalMinorUnits: Int

    enum FinalizationError: Error, Equatable {
        case bucketNotReady
        case emptyInvoice
    }

    struct FinalizationResult: Equatable {
        let invoice: Invoice
        let finalizedBucket: InvoiceBucket
        let activityEvents: [ActivityEvent]
    }

    static func finalize(
        id: UUID = UUID(),
        number: String,
        business: BusinessSnapshot,
        client: ClientSnapshot,
        project: ProjectSnapshot,
        bucket: InvoiceBucket,
        issueDate: Date,
        dueDate: Date
    ) throws -> FinalizationResult {
        guard bucket.status == .ready else {
            throw FinalizationError.bucketNotReady
        }

        let lines = bucket.invoiceLines()
        let totalMinorUnits = lines.map(\.amountMinorUnits).reduce(0, +)

        guard totalMinorUnits > 0 else {
            throw FinalizationError.emptyInvoice
        }

        let invoice = Invoice(
            id: id,
            number: number,
            business: business,
            client: client,
            project: project,
            bucketID: bucket.id,
            bucketName: bucket.name,
            issueDate: issueDate,
            dueDate: dueDate,
            status: .finalized,
            lines: lines,
            totalMinorUnits: totalMinorUnits
        )
        let finalizedBucket = bucket.withStatus(.finalized)

        return FinalizationResult(
            invoice: invoice,
            finalizedBucket: finalizedBucket,
            activityEvents: [
                .invoiceFinalized(invoiceID: invoice.id, invoiceNumber: invoice.number),
                .statusChanged(entityID: bucket.id, from: bucket.status.eventLabel, to: finalizedBucket.status.eventLabel),
            ]
        )
    }
}

extension InvoiceBucket {
    fileprivate func invoiceLines() -> [InvoiceLineSnapshot] {
        let timeLines = timeEntries
            .filter(\.isBillable)
            .map { entry in
                InvoiceLineSnapshot(
                    kind: .time,
                    date: entry.date,
                    description: entry.description,
                    quantity: .minutes(entry.durationMinutes),
                    unitPriceMinorUnits: entry.rateMinorUnits,
                    amountMinorUnits: entry.amountMinorUnits
                )
            }

        let fixedCostLines = fixedCosts
            .filter(\.isBillable)
            .map { cost in
                InvoiceLineSnapshot(
                    kind: .fixedCost,
                    date: cost.date,
                    description: cost.description,
                    quantity: .units(cost.quantity),
                    unitPriceMinorUnits: cost.unitPriceMinorUnits,
                    amountMinorUnits: cost.amountMinorUnits
                )
            }

        return (timeLines + fixedCostLines).sorted { left, right in
            if left.date == right.date {
                return left.description < right.description
            }

            return left.date < right.date
        }
    }
}

struct InvoiceNumberFormatter: Equatable {
    var prefix: String
    var minimumSequenceDigits: Int

    init(prefix: String, minimumSequenceDigits: Int = 3) {
        self.prefix = prefix
        self.minimumSequenceDigits = minimumSequenceDigits
    }

    func string(year: Int, sequence: Int) -> String {
        let paddedSequence = String(format: "%0\(minimumSequenceDigits)d", sequence)
        return "\(prefix)-\(year)-\(paddedSequence)"
    }
}

enum ActivityCategory: String, Equatable {
    case workflow
    case status
}

enum ActivityEvent: Equatable {
    case bucketReady(bucketID: UUID, bucketName: String)
    case invoiceFinalized(invoiceID: UUID, invoiceNumber: String)
    case statusChanged(entityID: UUID, from: String, to: String)

    var eventName: String {
        switch self {
        case .bucketReady:
            "bucket.ready"
        case .invoiceFinalized:
            "invoice.finalized"
        case .statusChanged:
            "status.changed"
        }
    }

    var category: ActivityCategory {
        switch self {
        case .bucketReady, .invoiceFinalized:
            .workflow
        case .statusChanged:
            .status
        }
    }

    var message: String {
        switch self {
        case .bucketReady(_, let bucketName):
            "\(bucketName) marked ready"
        case .invoiceFinalized(_, let invoiceNumber):
            "Invoice \(invoiceNumber) finalized"
        case .statusChanged(_, let previousStatus, let newStatus):
            "Status changed from \(previousStatus) to \(newStatus)"
        }
    }
}

private func roundedMinorUnits(numerator: Int, denominator: Int) -> Int {
    guard denominator != 0 else { return 0 }

    if numerator >= 0 {
        return (numerator + denominator / 2) / denominator
    }

    return (numerator - denominator / 2) / denominator
}
