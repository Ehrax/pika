import Foundation
import SwiftData

private protocol NormalizedRecordSortable {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

extension BusinessProfileRecord: NormalizedRecordSortable {}
extension ClientRecord: NormalizedRecordSortable {}
extension ProjectRecord: NormalizedRecordSortable {}
extension BucketRecord: NormalizedRecordSortable {}
extension TimeEntryRecord: NormalizedRecordSortable {}
extension FixedCostRecord: NormalizedRecordSortable {}
extension InvoiceRecord: NormalizedRecordSortable {}
extension InvoiceLineItemRecord: NormalizedRecordSortable {}

enum SwiftDataWorkspaceProjectionLoader {
    static func loadNormalizedWorkspace(from context: ModelContext) -> WorkspaceSnapshot? {
        guard
            let profileRecords = try? context.fetch(FetchDescriptor<BusinessProfileRecord>()),
            let clientRecords = try? context.fetch(FetchDescriptor<ClientRecord>()),
            let projectRecords = try? context.fetch(FetchDescriptor<ProjectRecord>()),
            let bucketRecords = try? context.fetch(FetchDescriptor<BucketRecord>()),
            let timeEntryRecords = try? context.fetch(FetchDescriptor<TimeEntryRecord>()),
            let fixedCostRecords = try? context.fetch(FetchDescriptor<FixedCostRecord>()),
            let invoiceRecords = try? context.fetch(FetchDescriptor<InvoiceRecord>()),
            let invoiceLineItemRecords = try? context.fetch(FetchDescriptor<InvoiceLineItemRecord>())
        else {
            return nil
        }

        let hasNormalizedData =
            !profileRecords.isEmpty ||
            !clientRecords.isEmpty ||
            !projectRecords.isEmpty ||
            !bucketRecords.isEmpty ||
            !timeEntryRecords.isEmpty ||
            !fixedCostRecords.isEmpty ||
            !invoiceRecords.isEmpty ||
            !invoiceLineItemRecords.isEmpty

        guard hasNormalizedData else {
            return nil
        }

        let profile = businessProfileProjection(from: profileRecords)
        let clients = buildClientProjections(from: clientRecords)
        let clientsByID = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })

        let bucketsByProjectID = Dictionary(grouping: bucketRecords, by: \.projectID)
        let timeEntriesByBucketID = Dictionary(grouping: timeEntryRecords, by: \.bucketID)
        let fixedCostsByBucketID = Dictionary(grouping: fixedCostRecords, by: \.bucketID)
        let invoicesByProjectID = Dictionary(grouping: invoiceRecords, by: \.projectID)
        let lineItemsByInvoiceID = Dictionary(grouping: invoiceLineItemRecords, by: \.invoiceID)

        let projects = sortedProjects(projectRecords).map { projectRecord in
            let projectClient = clientsByID[projectRecord.clientID] ?? projectRecord.client.map {
                clientProjection(from: $0)
            }

            let buckets = sortedBuckets(bucketsByProjectID[projectRecord.id] ?? [])
                .map {
                    bucketProjection(
                        from: $0,
                        timeEntriesByBucketID: timeEntriesByBucketID,
                        fixedCostsByBucketID: fixedCostsByBucketID
                    )
                }

            let bucketsByID = Dictionary(uniqueKeysWithValues: buckets.map { ($0.id, $0) })
            let invoices = sortedInvoices(invoicesByProjectID[projectRecord.id] ?? [])
                .map {
                    invoiceProjection(
                        from: $0,
                        projectRecord: projectRecord,
                        projectClient: projectClient,
                        bucket: bucketsByID[$0.bucketID],
                        profile: profile,
                        lineItemsByInvoiceID: lineItemsByInvoiceID
                    )
                }

            return WorkspaceProject(
                id: projectRecord.id,
                clientID: projectClient?.id ?? projectRecord.clientID,
                name: projectRecord.name,
                clientName: projectClient?.name ?? "",
                currencyCode: projectRecord.currencyCode,
                isArchived: projectRecord.isArchived,
                buckets: buckets,
                invoices: invoices
            )
        }

        return WorkspaceSnapshot(
            onboardingCompleted: sortedBusinessProfiles(profileRecords).last?.onboardingCompleted ?? false,
            businessProfile: profile,
            clients: clients,
            projects: projects,
            activity: []
        )
    }

    private static func businessProfileProjection(from records: [BusinessProfileRecord]) -> BusinessProfileProjection {
        guard let record = sortedBusinessProfiles(records).last else {
            return WorkspaceSnapshot.empty.businessProfile
        }

        return BusinessProfileProjection(
            businessName: record.businessName,
            personName: record.personName,
            email: record.email,
            phone: record.phone,
            address: record.address,
            taxIdentifier: record.taxIdentifier,
            economicIdentifier: record.economicIdentifier,
            invoicePrefix: record.invoicePrefix,
            nextInvoiceNumber: record.nextInvoiceNumber,
            currencyCode: record.currencyCode,
            paymentDetails: record.paymentDetails,
            taxNote: record.taxNote,
            defaultTermsDays: record.defaultTermsDays
        )
    }

    private static func buildClientProjections(from records: [ClientRecord]) -> [WorkspaceClient] {
        sortedClients(records).map { clientProjection(from: $0) }
    }

    private static func clientProjection(from record: ClientRecord) -> WorkspaceClient {
        WorkspaceClient(
            id: record.id,
            name: record.name,
            email: record.email,
            billingAddress: record.billingAddress,
            defaultTermsDays: record.defaultTermsDays,
            isArchived: record.isArchived
        )
    }

    private static func bucketProjection(
        from record: BucketRecord,
        timeEntriesByBucketID: [UUID: [TimeEntryRecord]],
        fixedCostsByBucketID: [UUID: [FixedCostRecord]]
    ) -> WorkspaceBucket {
        let timeEntries = buildTimeEntryProjections(
            from: sortedTimeEntries(timeEntriesByBucketID[record.id] ?? [])
        )
        let fixedCostEntries = buildFixedCostProjections(
            from: sortedFixedCosts(fixedCostsByBucketID[record.id] ?? [])
        )
        let billableMinutes = timeEntries
            .filter(\.isBillable)
            .map(\.durationMinutes)
            .reduce(0, +)
        let nonBillableMinutes = timeEntries
            .filter { !$0.isBillable }
            .map(\.durationMinutes)
            .reduce(0, +)
        let fixedCostMinorUnits = fixedCostEntries
            .map(\.amountMinorUnits)
            .reduce(0, +)
        let billableTimeMinorUnits = timeEntries
            .map(\.billableAmountMinorUnits)
            .reduce(0, +)

        return WorkspaceBucket(
            id: record.id,
            name: record.name,
            status: record.status,
            updatedAt: record.updatedAt,
            totalMinorUnits: billableTimeMinorUnits + fixedCostMinorUnits,
            billableMinutes: billableMinutes,
            fixedCostMinorUnits: fixedCostMinorUnits,
            nonBillableMinutes: nonBillableMinutes,
            defaultHourlyRateMinorUnits: timeEntries
                .first(where: { $0.isBillable && $0.hourlyRateMinorUnits > 0 })?
                .hourlyRateMinorUnits ?? positiveMinorUnits(record.defaultHourlyRateMinorUnits),
            timeEntries: timeEntries,
            fixedCostEntries: fixedCostEntries
        )
    }

    private static func invoiceProjection(
        from record: InvoiceRecord,
        projectRecord: ProjectRecord,
        projectClient: WorkspaceClient?,
        bucket: WorkspaceBucket?,
        profile: BusinessProfileProjection,
        lineItemsByInvoiceID: [UUID: [InvoiceLineItemRecord]]
    ) -> WorkspaceInvoice {
        let clientID = projectClient?.id ?? projectRecord.clientID
        let clientSnapshot = invoiceClientSnapshot(
            invoiceRecord: record,
            fallbackClient: projectClient,
            fallbackTermsDays: profile.defaultTermsDays,
            fallbackClientID: clientID
        )
        let invoiceLineItems = buildInvoiceLineItemSnapshots(
            from: sortedInvoiceLineItems(lineItemsByInvoiceID[record.id] ?? [])
        )

        return WorkspaceInvoice(
            id: record.id,
            number: record.number,
            businessSnapshot: invoiceBusinessSnapshot(invoiceRecord: record, fallbackProfile: profile),
            clientSnapshot: clientSnapshot,
            clientID: clientID,
            clientName: invoiceDisplayClientName(
                invoiceRecord: record,
                fallbackClient: projectClient
            ),
            projectID: projectRecord.id,
            projectName: record.projectName.isEmpty ? projectRecord.name : record.projectName,
            bucketID: record.bucketID,
            bucketName: record.bucketName.isEmpty ? (bucket?.name ?? "") : record.bucketName,
            template: record.template,
            issueDate: record.issueDate,
            dueDate: record.dueDate,
            servicePeriod: record.servicePeriod,
            status: record.status,
            totalMinorUnits: record.totalMinorUnits,
            lineItems: invoiceLineItems,
            currencyCode: record.currencyCode,
            note: record.note.isEmpty ? nil : record.note
        )
    }

    private static func buildTimeEntryProjections(from records: [TimeEntryRecord]) -> [WorkspaceTimeEntry] {
        records.map { record in
            let durationMinutes = normalizedDurationMinutes(for: record)
            let startTime = timeLabel(minuteOfDay: record.startMinuteOfDay)
            let endTime = timeLabel(minuteOfDay: record.endMinuteOfDay)
            return WorkspaceTimeEntry(
                id: record.id,
                date: record.workDate,
                startTime: startTime.isEmpty && endTime.isEmpty ? durationInputLabel(minutes: durationMinutes) : startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                description: record.descriptionText,
                isBillable: record.isBillable,
                hourlyRateMinorUnits: record.hourlyRateMinorUnits
            )
        }
    }

    private static func buildFixedCostProjections(from records: [FixedCostRecord]) -> [WorkspaceFixedCostEntry] {
        records.filter(\.isBillable).map { record in
            WorkspaceFixedCostEntry(
                id: record.id,
                date: record.date,
                description: record.descriptionText,
                amountMinorUnits: max(record.quantity, 1) * record.unitPriceMinorUnits
            )
        }
    }

    private static func buildInvoiceLineItemSnapshots(from records: [InvoiceLineItemRecord]) -> [WorkspaceInvoiceLineItemSnapshot] {
        records.map { record in
            WorkspaceInvoiceLineItemSnapshot(
                id: record.id,
                description: record.descriptionText,
                quantityLabel: record.quantityLabel,
                amountMinorUnits: record.amountMinorUnits
            )
        }
    }

    private static func invoiceBusinessSnapshot(
        invoiceRecord: InvoiceRecord,
        fallbackProfile: BusinessProfileProjection
    ) -> BusinessProfileProjection? {
        let hasSnapshotFields =
            !invoiceRecord.businessName.isEmpty ||
            !invoiceRecord.businessPersonName.isEmpty ||
            !invoiceRecord.businessEmail.isEmpty ||
            !invoiceRecord.businessPhone.isEmpty ||
            !invoiceRecord.businessAddress.isEmpty ||
            !invoiceRecord.businessTaxIdentifier.isEmpty ||
            !invoiceRecord.businessEconomicIdentifier.isEmpty ||
            !invoiceRecord.businessPaymentDetails.isEmpty ||
            !invoiceRecord.businessTaxNote.isEmpty

        guard hasSnapshotFields else { return nil }

        return BusinessProfileProjection(
            businessName: invoiceRecord.businessName,
            personName: invoiceRecord.businessPersonName,
            email: invoiceRecord.businessEmail,
            phone: invoiceRecord.businessPhone,
            address: invoiceRecord.businessAddress,
            taxIdentifier: invoiceRecord.businessTaxIdentifier,
            economicIdentifier: invoiceRecord.businessEconomicIdentifier,
            invoicePrefix: fallbackProfile.invoicePrefix,
            nextInvoiceNumber: fallbackProfile.nextInvoiceNumber,
            currencyCode: invoiceRecord.currencyCode.isEmpty ? fallbackProfile.currencyCode : invoiceRecord.currencyCode,
            paymentDetails: invoiceRecord.businessPaymentDetails,
            taxNote: invoiceRecord.businessTaxNote,
            defaultTermsDays: fallbackProfile.defaultTermsDays
        )
    }

    private static func invoiceClientSnapshot(
        invoiceRecord: InvoiceRecord,
        fallbackClient: WorkspaceClient?,
        fallbackTermsDays: Int,
        fallbackClientID: UUID
    ) -> WorkspaceClient? {
        let hasSnapshotFields =
            !invoiceRecord.clientName.isEmpty ||
            !invoiceRecord.clientEmail.isEmpty ||
            !invoiceRecord.clientBillingAddress.isEmpty

        guard hasSnapshotFields else { return nil }

        return WorkspaceClient(
            id: fallbackClient?.id ?? fallbackClientID,
            name: invoiceRecord.clientName.isEmpty ? fallbackClient?.name ?? "" : invoiceRecord.clientName,
            email: invoiceRecord.clientEmail.isEmpty ? fallbackClient?.email ?? "" : invoiceRecord.clientEmail,
            billingAddress: invoiceRecord.clientBillingAddress.isEmpty ? fallbackClient?.billingAddress ?? "" : invoiceRecord.clientBillingAddress,
            defaultTermsDays: fallbackClient?.defaultTermsDays ?? fallbackTermsDays,
            isArchived: fallbackClient?.isArchived ?? false
        )
    }

    private static func invoiceDisplayClientName(
        invoiceRecord: InvoiceRecord,
        fallbackClient: WorkspaceClient?
    ) -> String {
        invoiceRecord.clientName.isEmpty ? (fallbackClient?.name ?? "") : invoiceRecord.clientName
    }

    private static func normalizedDurationMinutes(for record: TimeEntryRecord) -> Int {
        if record.durationMinutes > 0 {
            return record.durationMinutes
        }

        guard let start = record.startMinuteOfDay, let end = record.endMinuteOfDay else {
            return 0
        }

        return max(end - start, 0)
    }

    private static func timeLabel(minuteOfDay: Int?) -> String {
        guard let minuteOfDay else { return "" }
        let hours = minuteOfDay / 60
        let minutes = minuteOfDay % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private static func durationInputLabel(minutes: Int) -> String {
        guard minutes > 0 else { return "" }
        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60)h"
        }
        if minutes.isMultiple(of: 30) {
            return String(format: "%.1fh", locale: Locale(identifier: "en_US_POSIX"), Double(minutes) / 60)
        }
        return "\(minutes)m"
    }

    private static func positiveMinorUnits(_ minorUnits: Int) -> Int? {
        guard minorUnits > 0 else { return nil }
        return minorUnits
    }

    private static func sortedClients(_ records: [ClientRecord]) -> [ClientRecord] {
        records.sorted { left, right in
            if left.name != right.name {
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }

            return normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func sortedBusinessProfiles(_ records: [BusinessProfileRecord]) -> [BusinessProfileRecord] {
        records.sorted { left, right in
            normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func sortedProjects(_ records: [ProjectRecord]) -> [ProjectRecord] {
        records.sorted { left, right in
            if left.name != right.name {
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }

            return normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func sortedBuckets(_ records: [BucketRecord]) -> [BucketRecord] {
        records.sorted { left, right in
            if left.name != right.name {
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }

            return normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func sortedTimeEntries(_ records: [TimeEntryRecord]) -> [TimeEntryRecord] {
        records.sorted { left, right in
            if left.workDate != right.workDate {
                return left.workDate < right.workDate
            }

            if left.startMinuteOfDay != right.startMinuteOfDay {
                return (left.startMinuteOfDay ?? .max) < (right.startMinuteOfDay ?? .max)
            }

            if left.endMinuteOfDay != right.endMinuteOfDay {
                return (left.endMinuteOfDay ?? .max) < (right.endMinuteOfDay ?? .max)
            }

            return normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func sortedFixedCosts(_ records: [FixedCostRecord]) -> [FixedCostRecord] {
        records.sorted { left, right in
            if left.date != right.date {
                return left.date < right.date
            }

            return normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func sortedInvoices(_ records: [InvoiceRecord]) -> [InvoiceRecord] {
        records.sorted { left, right in
            if left.issueDate != right.issueDate {
                return left.issueDate < right.issueDate
            }

            if left.number != right.number {
                return left.number.localizedCompare(right.number) == .orderedAscending
            }

            return normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func sortedInvoiceLineItems(_ records: [InvoiceLineItemRecord]) -> [InvoiceLineItemRecord] {
        records.sorted { left, right in
            if left.sortOrder != right.sortOrder {
                return left.sortOrder < right.sortOrder
            }

            return normalizedRecordSortAscending(left: left, right: right)
        }
    }

    private static func normalizedRecordSortAscending<Record: NormalizedRecordSortable>(
        left: Record,
        right: Record
    ) -> Bool {
        if left.createdAt != right.createdAt {
            return left.createdAt < right.createdAt
        }

        if left.updatedAt != right.updatedAt {
            return left.updatedAt < right.updatedAt
        }

        return left.id.uuidString < right.id.uuidString
    }
}
