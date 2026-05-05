import Foundation

enum WorkspaceBucketEntryKind: Equatable {
    case time
    case fixedCost
}

struct WorkspaceBucketEntryRowProjection: Equatable, Identifiable {
    let id: UUID
    let kind: WorkspaceBucketEntryKind
    let date: Date?
    let dateLabel: String
    let timeLabel: String
    let description: String
    let hoursLabel: String
    let amountLabel: String
    let isBillable: Bool
}

struct WorkspaceInlineEntryDraftProjection: Equatable {
    let timeInput: String
    let description: String
    let isBillable: Bool
    let hourlyRateMinorUnits: Int
    let durationMinutes: Int?
    let hoursLabel: String
    let amountLabel: String

    init(
        timeInput: String,
        description: String,
        isBillable: Bool,
        hourlyRateMinorUnits: Int,
        formatter: MoneyFormatting
    ) {
        self.timeInput = timeInput
        self.description = description
        self.isBillable = isBillable
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
        durationMinutes = WorkspaceEntryDurationParser.minutes(from: timeInput)

        if let durationMinutes {
            hoursLabel = Self.hoursLabel(minutes: durationMinutes)
            if isBillable {
                amountLabel = formatter.string(fromMinorUnits: durationMinutes * hourlyRateMinorUnits / 60)
            } else {
                amountLabel = "n/b"
            }
        } else {
            hoursLabel = "-"
            amountLabel = isBillable ? formatter.string(fromMinorUnits: 0) : "n/b"
        }
    }

    private static func hoursLabel(minutes: Int) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(minutes) / 60)
    }
}

extension WorkspaceBucket {
    func entryRows(formatter: MoneyFormatting) -> [WorkspaceBucketEntryRowProjection] {
        if hasRowLevelEntries {
            return rowLevelEntryRows(formatter: formatter)
        }

        return legacyEntryRows(formatter: formatter)
    }

    private func rowLevelEntryRows(formatter: MoneyFormatting) -> [WorkspaceBucketEntryRowProjection] {
        let timeRows = timeEntries.map { entry in
            WorkspaceBucketEntryRowSortingCandidate(
                date: entry.date,
                timeSortKey: entry.timeRangeLabel,
                row: WorkspaceBucketEntryRowProjection(
                    id: entry.id,
                    kind: .time,
                    date: entry.date,
                    dateLabel: Self.dateFormatter.string(from: entry.date),
                    timeLabel: entry.timeRangeLabel,
                    description: entry.description,
                    hoursLabel: Self.hoursLabel(minutes: entry.durationMinutes),
                    amountLabel: entry.isBillable ? formatter.string(fromMinorUnits: entry.billableAmountMinorUnits) : "n/b",
                    isBillable: entry.isBillable
                )
            )
        }

        let fixedRows = fixedCostEntries.map { entry in
            WorkspaceBucketEntryRowSortingCandidate(
                date: entry.date,
                timeSortKey: "99:fixed-cost",
                row: WorkspaceBucketEntryRowProjection(
                    id: entry.id,
                    kind: .fixedCost,
                    date: entry.date,
                    dateLabel: Self.dateFormatter.string(from: entry.date),
                    timeLabel: "Fixed cost",
                    description: entry.description,
                    hoursLabel: "-",
                    amountLabel: formatter.string(fromMinorUnits: entry.amountMinorUnits),
                    isBillable: entry.amountMinorUnits > 0
                )
            )
        }

        return (timeRows + fixedRows).sorted { left, right in
            if left.date == right.date {
                return left.timeSortKey < right.timeSortKey
            }

            return left.date < right.date
        }.map(\.row)
    }

    private func legacyEntryRows(formatter: MoneyFormatting) -> [WorkspaceBucketEntryRowProjection] {
        var rows: [WorkspaceBucketEntryRowProjection] = []

        if billableMinutes > 0 || billableTimeMinorUnits > 0 {
            rows.append(WorkspaceBucketEntryRowProjection(
                id: id,
                kind: .time,
                date: nil,
                dateLabel: "-",
                timeLabel: "Billable",
                description: "Billable time",
                hoursLabel: Self.hoursLabel(minutes: billableMinutes),
                amountLabel: formatter.string(fromMinorUnits: billableTimeMinorUnits),
                isBillable: true
            ))
        }

        if fixedCostMinorUnits > 0 {
            let suffix = id.uuidString.replacingOccurrences(of: "-", with: "").suffix(12)
            rows.append(WorkspaceBucketEntryRowProjection(
                id: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? id,
                kind: .fixedCost,
                date: nil,
                dateLabel: "-",
                timeLabel: "Fixed cost",
                description: "Fixed costs",
                hoursLabel: "-",
                amountLabel: formatter.string(fromMinorUnits: fixedCostMinorUnits),
                isBillable: true
            ))
        }

        if nonBillableMinutes > 0 {
            let suffix = id.uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
            rows.append(WorkspaceBucketEntryRowProjection(
                id: UUID(uuidString: "11111111-1111-1111-1111-\(suffix)") ?? id,
                kind: .time,
                date: nil,
                dateLabel: "-",
                timeLabel: "Non-billable",
                description: "Non-billable time",
                hoursLabel: Self.hoursLabel(minutes: nonBillableMinutes),
                amountLabel: "n/b",
                isBillable: false
            ))
        }

        return rows
    }

    private static func hoursLabel(minutes: Int) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(minutes) / 60)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

private struct WorkspaceBucketEntryRowSortingCandidate {
    let date: Date
    let timeSortKey: String
    let row: WorkspaceBucketEntryRowProjection
}

enum WorkspaceProjectBucketProjections {
    static func detail(
        for project: WorkspaceProject,
        selectedBucketID: WorkspaceBucket.ID? = nil,
        formatter: MoneyFormatting,
        on date: Date = .now
    ) -> WorkspaceBucketDetailProjection? {
        guard let selectedBucket = bucket(in: project, matching: selectedBucketID) ?? project.buckets.first else {
            return nil
        }

        return WorkspaceBucketDetailProjection(
            project: project,
            selectedBucket: selectedBucket,
            bucketRows: project.buckets.map { bucket in
                WorkspaceBucketRowProjection(
                    bucket: bucket,
                    linkedInvoice: latestInvoice(for: bucket, in: project),
                    formatter: formatter,
                    on: date
                )
            },
            formatter: formatter
        )
    }

    static func normalizedBucketID(
        for project: WorkspaceProject,
        selectedBucketID: WorkspaceBucket.ID?
    ) -> WorkspaceBucket.ID? {
        (bucket(in: project, matching: selectedBucketID) ?? project.buckets.first)?.id
    }

    private static func bucket(in project: WorkspaceProject, matching id: WorkspaceBucket.ID?) -> WorkspaceBucket? {
        guard let id else { return nil }
        return project.buckets.first { $0.id == id }
    }

    private static func latestInvoice(
        for bucket: WorkspaceBucket,
        in project: WorkspaceProject
    ) -> WorkspaceInvoice? {
        project.invoices
            .filter { $0.matches(projectID: project.id, projectName: project.name, bucketID: bucket.id, bucketName: bucket.name) }
            .sorted { left, right in
                if left.issueDate == right.issueDate {
                    return left.number > right.number
                }

                return left.issueDate > right.issueDate
            }
            .first
    }
}

extension WorkspaceProject {
    func detailProjection(
        selectedBucketID: WorkspaceBucket.ID? = nil,
        formatter: MoneyFormatting,
        on date: Date = .now
    ) -> WorkspaceBucketDetailProjection? {
        WorkspaceProjectBucketProjections.detail(
            for: self,
            selectedBucketID: selectedBucketID,
            formatter: formatter,
            on: date
        )
    }

    func normalizedBucketID(_ id: WorkspaceBucket.ID?) -> WorkspaceBucket.ID? {
        WorkspaceProjectBucketProjections.normalizedBucketID(for: self, selectedBucketID: id)
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
        InvoiceWorkflowPolicy.statusTitle(status: self, isOverdue: isOverdue(dueDate: dueDate, on: date))
    }

    func displayTone(dueDate: Date, on date: Date) -> PikaStatusTone {
        InvoiceWorkflowPolicy.statusTone(status: self, isOverdue: isOverdue(dueDate: dueDate, on: date))
    }
}

private extension BucketStatus {
    var displayTone: PikaStatusTone {
        switch self {
        case .open:
            .neutral
        case .ready:
            .success
        case .finalized:
            .warning
        case .archived:
            .neutral
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
                quantity: selectedBucket.effectiveFixedCostMinorUnits > 0
                    ? max(selectedBucket.fixedCostEntries.count, 1).formattedItemCount
                    : "0 items",
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
