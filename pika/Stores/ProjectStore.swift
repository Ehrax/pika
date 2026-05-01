import Foundation
import Observation
import SwiftData

protocol ProjectStore {
    func placeholderProjects() -> [ProjectRecord]
}

struct NoopProjectStore: ProjectStore {
    func placeholderProjects() -> [ProjectRecord] {
        []
    }
}

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

enum WorkspaceStoreError: Error, Equatable {
    case projectNotFound
    case bucketNotFound
    case invoiceNotFound
    case persistenceFailed
    case invalidBusinessProfile
    case invalidClient
    case invalidProject
    case invalidBucket
    case bucketNotInvoiceable
    case bucketStatusNotReady(BucketStatus)
    case bucketLocked(BucketStatus)
    case invalidTimeEntry
    case invalidFixedCost
    case entryNotFound
    case invalidInvoiceStatusTransition(from: InvoiceStatus, to: InvoiceStatus)
    case duplicateInvoiceNumber
    case clientHasLinkedProjects
    case clientNotArchived
    case projectNotArchived
}

@Observable
final class WorkspaceStore {
    var workspace: WorkspaceSnapshot

    let modelContext: ModelContext
    private let usesNormalizedPersistence: Bool
    private static let deterministicImportTimestamp = Date(timeIntervalSince1970: 0)

    private struct ClientRecordLookup {
        var byID: [UUID: ClientRecord] = [:]
        var byName: [String: ClientRecord] = [:]

        mutating func insert(_ record: ClientRecord) {
            byID[record.id] = record
            byName[WorkspaceStore.normalizedNameKey(record.name)] = record
        }
    }

    init(
        seed: WorkspaceSnapshot = .empty,
        modelContext: ModelContext? = nil,
        resetForSeedImport: Bool = false
    ) {
        usesNormalizedPersistence = modelContext != nil
        if let modelContext {
            self.modelContext = modelContext
        } else {
            self.modelContext = WorkspaceStore.makeDefaultModelContext()
        }

        guard usesNormalizedPersistence else {
            workspace = seed
            workspace.normalizeMissingHourlyRates()
            return
        }

        if resetForSeedImport {
            workspace = seed
            workspace.normalizeMissingHourlyRates()
            try? replacePersistentWorkspaceWithSeedImport(workspace)
            return
        }

        let persistedWorkspace = Self.loadNormalizedWorkspace(from: self.modelContext)
        workspace = persistedWorkspace ?? seed
        workspace.normalizeMissingHourlyRates()

        if persistedWorkspace == nil {
            try? replacePersistentWorkspaceWithSeedImport(workspace)
        }
    }

    static func makeModelContainer(
        mode: AppPersistenceMode,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        try PikaApp.makeModelContainer(
            mode: mode,
            overrideStoreURL: storeURL
        )
    }

    private static func makeDefaultModelContext() -> ModelContext {
        do {
            let container = try makeModelContainer(mode: .inMemory)
            return ModelContext(container)
        } catch {
            fatalError("Could not create WorkspaceStore ModelContext: \(error)")
        }
    }

    private func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        do {
            try Self.clearWorkspaceRecords(from: modelContext)
            try Self.persistNormalizedWorkspace(snapshot, into: modelContext)
            try modelContext.save()
        } catch {
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    func persistWorkspace() throws {
        do {
            try modelContext.save()
        } catch {
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    private static func clearWorkspaceRecords(from context: ModelContext) throws {
        try deleteAll(FetchDescriptor<BusinessProfileRecord>(), from: context)
        try deleteAll(FetchDescriptor<ClientRecord>(), from: context)
        try deleteAll(FetchDescriptor<ProjectRecord>(), from: context)
        try deleteAll(FetchDescriptor<BucketRecord>(), from: context)
        try deleteAll(FetchDescriptor<TimeEntryRecord>(), from: context)
        try deleteAll(FetchDescriptor<FixedCostRecord>(), from: context)
        try deleteAll(FetchDescriptor<InvoiceLineItemRecord>(), from: context)
        try deleteAll(FetchDescriptor<InvoiceRecord>(), from: context)
    }

    private static func deleteAll<Record: PersistentModel>(
        _ descriptor: FetchDescriptor<Record>,
        from context: ModelContext
    ) throws {
        let records = try context.fetch(descriptor)
        for record in records {
            context.delete(record)
        }
    }

    private static func persistNormalizedWorkspace(_ snapshot: WorkspaceSnapshot, into context: ModelContext) throws {
        let importedAt = deterministicImportTimestamp

        let profile = snapshot.businessProfile
        persistBusinessProfile(profile, importedAt: importedAt, into: context)

        var clientLookup = persistClients(snapshot.clients, importedAt: importedAt, into: context)

        for project in snapshot.projects {
            let projectRecord = persistProject(
                project,
                profile: profile,
                clientLookup: &clientLookup,
                importedAt: importedAt,
                into: context
            )
            let bucketIDsByName = persistBuckets(
                project.buckets,
                projectID: project.id,
                projectRecord: projectRecord,
                importedAt: importedAt,
                into: context
            )
            persistInvoices(
                project.invoices,
                project: project,
                projectRecord: projectRecord,
                bucketIDsByName: bucketIDsByName,
                into: context
            )
        }
    }

    private static func persistBusinessProfile(
        _ profile: BusinessProfileProjection,
        importedAt: Date,
        into context: ModelContext
    ) {
        context.insert(BusinessProfileRecord(
            businessName: profile.businessName,
            personName: profile.personName,
            email: profile.email,
            phone: profile.phone,
            address: profile.address,
            taxIdentifier: profile.taxIdentifier,
            economicIdentifier: profile.economicIdentifier,
            invoicePrefix: profile.invoicePrefix,
            nextInvoiceNumber: profile.nextInvoiceNumber,
            currencyCode: profile.currencyCode,
            paymentDetails: profile.paymentDetails,
            taxNote: profile.taxNote,
            defaultTermsDays: profile.defaultTermsDays,
            createdAt: importedAt,
            updatedAt: importedAt
        ))
    }

    private static func persistClients(
        _ clients: [WorkspaceClient],
        importedAt: Date,
        into context: ModelContext
    ) -> ClientRecordLookup {
        var lookup = ClientRecordLookup()
        for client in clients {
            let record = ClientRecord(
                id: client.id,
                name: client.name,
                email: client.email,
                billingAddress: client.billingAddress,
                defaultTermsDays: client.defaultTermsDays,
                isArchived: client.isArchived,
                createdAt: importedAt,
                updatedAt: importedAt
            )
            context.insert(record)
            lookup.insert(record)
        }

        return lookup
    }

    private static func persistProject(
        _ project: WorkspaceProject,
        profile: BusinessProfileProjection,
        clientLookup: inout ClientRecordLookup,
        importedAt: Date,
        into context: ModelContext
    ) -> ProjectRecord {
        let resolvedClientRecord = resolveClientRecord(
            for: project,
            profile: profile,
            importedAt: importedAt,
            clientLookup: &clientLookup,
            into: context
        )
        let projectRecord = ProjectRecord(
            id: project.id,
            clientID: resolvedClientRecord.id,
            name: project.name,
            currencyCode: project.currencyCode,
            isArchived: project.isArchived,
            createdAt: importedAt,
            updatedAt: importedAt,
            client: resolvedClientRecord
        )
        context.insert(projectRecord)
        return projectRecord
    }

    private static func resolveClientRecord(
        for project: WorkspaceProject,
        profile: BusinessProfileProjection,
        importedAt: Date,
        clientLookup: inout ClientRecordLookup,
        into context: ModelContext
    ) -> ClientRecord {
        let normalizedClientName = normalizedNameKey(project.clientName)
        if let clientID = project.clientID,
           let existing = clientLookup.byID[clientID] {
            return existing
        }

        if let existing = clientLookup.byName[normalizedClientName] {
            return existing
        }

        let synthesizedClientID = project.clientID ?? project.id
        let synthesizedClient = ClientRecord(
            id: synthesizedClientID,
            name: project.clientName,
            email: "",
            billingAddress: "",
            defaultTermsDays: profile.defaultTermsDays,
            isArchived: false,
            createdAt: importedAt,
            updatedAt: importedAt
        )
        context.insert(synthesizedClient)
        clientLookup.insert(synthesizedClient)
        return synthesizedClient
    }

    private static func persistBuckets(
        _ buckets: [WorkspaceBucket],
        projectID: UUID,
        projectRecord: ProjectRecord,
        importedAt: Date,
        into context: ModelContext
    ) -> [String: UUID] {
        var bucketIDsByName: [String: UUID] = [:]
        for bucket in buckets {
            let bucketRecord = BucketRecord(
                id: bucket.id,
                projectID: projectID,
                name: bucket.name,
                statusRaw: bucket.status.rawValue,
                createdAt: importedAt,
                updatedAt: importedAt,
                project: projectRecord
            )
            context.insert(bucketRecord)
            bucketIDsByName[normalizedNameKey(bucket.name)] = bucket.id
            persistBucketRows(
                for: bucket,
                bucketRecord: bucketRecord,
                importedAt: importedAt,
                into: context
            )
        }

        return bucketIDsByName
    }

    private static func persistBucketRows(
        for bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        importedAt: Date,
        into context: ModelContext
    ) {
        if bucket.hasRowLevelEntries {
            persistTimeEntries(
                bucket.timeEntries,
                bucket: bucket,
                bucketRecord: bucketRecord,
                into: context
            )
            persistFixedCosts(
                bucket.fixedCostEntries,
                bucket: bucket,
                bucketRecord: bucketRecord,
                into: context
            )
        } else {
            persistLegacyAggregateRows(
                for: bucket,
                bucketRecord: bucketRecord,
                importedAt: importedAt,
                into: context
            )
        }
    }

    private static func persistTimeEntries(
        _ entries: [WorkspaceTimeEntry],
        bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        into context: ModelContext
    ) {
        for entry in entries {
            context.insert(TimeEntryRecord(
                id: entry.id,
                bucketID: bucket.id,
                workDate: entry.date,
                startMinuteOfDay: minuteOfDay(from: entry.startTime),
                endMinuteOfDay: minuteOfDay(from: entry.endTime),
                durationMinutes: max(entry.durationMinutes, 0),
                descriptionText: entry.description,
                isBillable: entry.isBillable,
                hourlyRateMinorUnits: max(entry.hourlyRateMinorUnits, 0),
                createdAt: entry.date,
                updatedAt: entry.date,
                bucket: bucketRecord
            ))
        }
    }

    private static func persistFixedCosts(
        _ fixedCosts: [WorkspaceFixedCostEntry],
        bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        into context: ModelContext
    ) {
        for fixedCost in fixedCosts {
            context.insert(FixedCostRecord(
                id: fixedCost.id,
                bucketID: bucket.id,
                date: fixedCost.date,
                descriptionText: fixedCost.description,
                quantity: 1,
                unitPriceMinorUnits: max(fixedCost.amountMinorUnits, 0),
                isBillable: true,
                createdAt: fixedCost.date,
                updatedAt: fixedCost.date,
                bucket: bucketRecord
            ))
        }
    }

    private static func persistInvoices(
        _ invoices: [WorkspaceInvoice],
        project: WorkspaceProject,
        projectRecord: ProjectRecord,
        bucketIDsByName: [String: UUID],
        into context: ModelContext
    ) {
        for invoice in invoices {
            let bucketID = resolvedBucketID(
                for: invoice,
                in: project,
                bucketIDsByName: bucketIDsByName
            )
            let invoiceRecord = InvoiceRecord(
                id: invoice.id,
                projectID: project.id,
                bucketID: bucketID,
                number: invoice.number,
                templateRaw: invoice.template.rawValue,
                issueDate: invoice.issueDate,
                dueDate: invoice.dueDate,
                servicePeriod: invoice.servicePeriod,
                statusRaw: invoice.status.rawValue,
                totalMinorUnits: invoice.totalMinorUnits,
                currencyCode: invoice.currencyCode.isEmpty ? project.currencyCode : invoice.currencyCode,
                note: invoice.note ?? "",
                businessName: invoice.businessSnapshot?.businessName ?? "",
                businessPersonName: invoice.businessSnapshot?.personName ?? "",
                businessEmail: invoice.businessSnapshot?.email ?? "",
                businessPhone: invoice.businessSnapshot?.phone ?? "",
                businessAddress: invoice.businessSnapshot?.address ?? "",
                businessTaxIdentifier: invoice.businessSnapshot?.taxIdentifier ?? "",
                businessEconomicIdentifier: invoice.businessSnapshot?.economicIdentifier ?? "",
                businessPaymentDetails: invoice.businessSnapshot?.paymentDetails ?? "",
                businessTaxNote: invoice.businessSnapshot?.taxNote ?? "",
                clientName: invoiceSnapshotClientName(for: invoice),
                clientEmail: invoice.clientSnapshot?.email ?? "",
                clientBillingAddress: invoice.clientSnapshot?.billingAddress ?? "",
                projectName: invoice.projectName.isEmpty ? project.name : invoice.projectName,
                bucketName: invoice.bucketName,
                createdAt: invoice.issueDate,
                updatedAt: invoice.issueDate
            )
            invoiceRecord.project = projectRecord
            invoiceRecord.bucket = nil
            context.insert(invoiceRecord)

            persistInvoiceLineItems(
                invoice.lineItems,
                invoice: invoice,
                invoiceRecord: invoiceRecord,
                into: context
            )
        }
    }

    private static func persistInvoiceLineItems(
        _ lineItems: [WorkspaceInvoiceLineItemSnapshot],
        invoice: WorkspaceInvoice,
        invoiceRecord: InvoiceRecord,
        into context: ModelContext
    ) {
        for (lineItemIndex, lineItem) in lineItems.enumerated() {
            context.insert(InvoiceLineItemRecord(
                id: derivedUUID(from: invoice.id, variant: UInt8((lineItemIndex + 1) % 255)),
                invoiceID: invoice.id,
                sortOrder: lineItemIndex,
                descriptionText: lineItem.description,
                quantityLabel: lineItem.quantityLabel,
                amountMinorUnits: lineItem.amountMinorUnits,
                createdAt: invoice.issueDate,
                updatedAt: invoice.issueDate,
                invoice: invoiceRecord
            ))
        }
    }

    private static func resolvedBucketID(
        for invoice: WorkspaceInvoice,
        in project: WorkspaceProject,
        bucketIDsByName: [String: UUID]
    ) -> UUID {
        if let bucketID = invoice.bucketID {
            return bucketID
        }

        if let bucketID = bucketIDsByName[normalizedNameKey(invoice.bucketName)] {
            return bucketID
        }

        if let bucketID = project.buckets.first?.id {
            return bucketID
        }

        return UUID()
    }

    private static func invoiceSnapshotClientName(for invoice: WorkspaceInvoice) -> String {
        if let clientSnapshotName = invoice.clientSnapshot?.name, !clientSnapshotName.isEmpty {
            return clientSnapshotName
        }

        return invoice.clientName
    }

    private static func persistLegacyAggregateRows(
        for bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        importedAt: Date,
        into context: ModelContext
    ) {
        let billableMinorUnits = max(bucket.totalMinorUnits - bucket.fixedCostMinorUnits, 0)
        if bucket.billableMinutes > 0 {
            let inferredRate = bucket.hourlyRateMinorUnits
                ?? billableMinorUnits * 60 / bucket.billableMinutes
            context.insert(TimeEntryRecord(
                id: derivedUUID(from: bucket.id, variant: 1),
                bucketID: bucket.id,
                workDate: importedAt,
                startMinuteOfDay: nil,
                endMinuteOfDay: nil,
                durationMinutes: bucket.billableMinutes,
                descriptionText: "Imported billable time",
                isBillable: true,
                hourlyRateMinorUnits: max(inferredRate, 0),
                createdAt: importedAt,
                updatedAt: importedAt,
                bucket: bucketRecord
            ))
        }

        if bucket.nonBillableMinutes > 0 {
            context.insert(TimeEntryRecord(
                id: derivedUUID(from: bucket.id, variant: 2),
                bucketID: bucket.id,
                workDate: importedAt,
                startMinuteOfDay: nil,
                endMinuteOfDay: nil,
                durationMinutes: bucket.nonBillableMinutes,
                descriptionText: "Imported non-billable time",
                isBillable: false,
                hourlyRateMinorUnits: max(bucket.hourlyRateMinorUnits ?? 0, 0),
                createdAt: importedAt,
                updatedAt: importedAt,
                bucket: bucketRecord
            ))
        }

        if bucket.fixedCostMinorUnits > 0 {
            context.insert(FixedCostRecord(
                id: derivedUUID(from: bucket.id, variant: 3),
                bucketID: bucket.id,
                date: importedAt,
                descriptionText: "Imported fixed costs",
                quantity: 1,
                unitPriceMinorUnits: bucket.fixedCostMinorUnits,
                isBillable: true,
                createdAt: importedAt,
                updatedAt: importedAt,
                bucket: bucketRecord
            ))
        }
    }

    private static func minuteOfDay(from label: String) -> Int? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 5 else { return nil }

        let components = trimmed.split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              (0...23).contains(hours),
              (0...59).contains(minutes)
        else {
            return nil
        }

        return hours * 60 + minutes
    }

    private static func normalizedNameKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func derivedUUID(from base: UUID, variant: UInt8) -> UUID {
        var raw = base.uuid
        withUnsafeMutableBytes(of: &raw) { bytes in
            bytes[15] ^= variant
            bytes[14] ^= 0xA5
        }
        return UUID(uuid: raw)
    }

    private static func loadNormalizedWorkspace(from context: ModelContext) -> WorkspaceSnapshot? {
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
        sortedClients(records).map(clientProjection)
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

    func isUsingNormalizedWorkspacePersistence() -> Bool {
        usesNormalizedPersistence && Self.loadNormalizedWorkspace(from: modelContext) != nil
    }

    func clientRecord(_ id: WorkspaceClient.ID) throws -> ClientRecord? {
        var descriptor = FetchDescriptor<ClientRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func projectRecord(_ id: WorkspaceProject.ID) throws -> ProjectRecord? {
        var descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func bucketRecord(_ id: WorkspaceBucket.ID) throws -> BucketRecord? {
        var descriptor = FetchDescriptor<BucketRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func hasProjectRecordLinked(to clientID: WorkspaceClient.ID) throws -> Bool {
        var descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { $0.clientID == clientID }
        )
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    func bucketRecords(for projectID: WorkspaceProject.ID) throws -> [BucketRecord] {
        let descriptor = FetchDescriptor<BucketRecord>(
            predicate: #Predicate { $0.projectID == projectID }
        )
        return try modelContext.fetch(descriptor)
    }

    func invoiceRecords(for projectID: WorkspaceProject.ID) throws -> [InvoiceRecord] {
        let descriptor = FetchDescriptor<InvoiceRecord>(
            predicate: #Predicate { $0.projectID == projectID }
        )
        return try modelContext.fetch(descriptor)
    }

    func timeEntryRecords(for bucketID: WorkspaceBucket.ID) throws -> [TimeEntryRecord] {
        let descriptor = FetchDescriptor<TimeEntryRecord>(
            predicate: #Predicate { $0.bucketID == bucketID }
        )
        return try modelContext.fetch(descriptor)
    }

    func fixedCostRecords(for bucketID: WorkspaceBucket.ID) throws -> [FixedCostRecord] {
        let descriptor = FetchDescriptor<FixedCostRecord>(
            predicate: #Predicate { $0.bucketID == bucketID }
        )
        return try modelContext.fetch(descriptor)
    }

    func invoiceLineItemRecords(for invoiceID: WorkspaceInvoice.ID) throws -> [InvoiceLineItemRecord] {
        let descriptor = FetchDescriptor<InvoiceLineItemRecord>(
            predicate: #Predicate { $0.invoiceID == invoiceID }
        )
        return try modelContext.fetch(descriptor)
    }

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws {
        try modelContext.save()
        guard var reloadedWorkspace = Self.loadNormalizedWorkspace(from: modelContext) else {
            throw WorkspaceStoreError.persistenceFailed
        }
        reloadedWorkspace.normalizeMissingHourlyRates()
        reloadedWorkspace.activity = activity
        workspace = reloadedWorkspace
    }

    func saveAndReloadNormalizedWorkspacePreservingActivity() throws {
        try saveAndReloadNormalizedWorkspace(preservingActivity: workspace.activity)
    }

    func updateBusinessProfile(_ draft: WorkspaceBusinessProfileDraft) throws {
        let businessName = draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let personName = draft.personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxIdentifier = draft.taxIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let economicIdentifier = draft.economicIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let invoicePrefix = draft.invoicePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let paymentDetails = draft.paymentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxNote = draft.taxNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !businessName.isEmpty,
              !email.isEmpty,
              !address.isEmpty,
              !invoicePrefix.isEmpty,
              !currencyCode.isEmpty,
              !paymentDetails.isEmpty,
              draft.nextInvoiceNumber > 0,
              draft.defaultTermsDays > 0
        else {
            throw WorkspaceStoreError.invalidBusinessProfile
        }

        let profile = BusinessProfileProjection(
            businessName: businessName,
            personName: personName,
            email: email,
            phone: phone,
            address: address,
            taxIdentifier: taxIdentifier,
            economicIdentifier: economicIdentifier,
            invoicePrefix: invoicePrefix.uppercased(),
            nextInvoiceNumber: draft.nextInvoiceNumber,
            currencyCode: currencyCode,
            paymentDetails: paymentDetails,
            taxNote: taxNote,
            defaultTermsDays: draft.defaultTermsDays
        )

        if isUsingNormalizedWorkspacePersistence() {
            try updateBusinessProfileRecord(with: profile)
            try saveAndReloadNormalizedWorkspacePreservingActivity()
        } else {
            workspace.businessProfile = profile
        }

        AppTelemetry.settingsSaved()
        try persistWorkspace()
    }

    private func updateBusinessProfileRecord(with profile: BusinessProfileProjection) throws {
        let now = Date.now
        let record = try latestBusinessProfileRecord() ?? makeBusinessProfileRecord(
            from: profile,
            createdAt: now
        )

        apply(profile, to: record, updatedAt: now)
    }

    private func makeBusinessProfileRecord(
        from profile: BusinessProfileProjection,
        createdAt: Date
    ) -> BusinessProfileRecord {
        let record = BusinessProfileRecord(
            businessName: profile.businessName,
            personName: profile.personName,
            email: profile.email,
            phone: profile.phone,
            address: profile.address,
            taxIdentifier: profile.taxIdentifier,
            economicIdentifier: profile.economicIdentifier,
            invoicePrefix: profile.invoicePrefix,
            nextInvoiceNumber: profile.nextInvoiceNumber,
            currencyCode: profile.currencyCode,
            paymentDetails: profile.paymentDetails,
            taxNote: profile.taxNote,
            defaultTermsDays: profile.defaultTermsDays,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        modelContext.insert(record)
        return record
    }

    private func apply(
        _ profile: BusinessProfileProjection,
        to record: BusinessProfileRecord,
        updatedAt: Date
    ) {
        record.businessName = profile.businessName
        record.personName = profile.personName
        record.email = profile.email
        record.phone = profile.phone
        record.address = profile.address
        record.taxIdentifier = profile.taxIdentifier
        record.economicIdentifier = profile.economicIdentifier
        record.invoicePrefix = profile.invoicePrefix
        record.nextInvoiceNumber = profile.nextInvoiceNumber
        record.currencyCode = profile.currencyCode
        record.paymentDetails = profile.paymentDetails
        record.taxNote = profile.taxNote
        record.defaultTermsDays = profile.defaultTermsDays
        record.updatedAt = updatedAt
    }

    private func latestBusinessProfileRecord() throws -> BusinessProfileRecord? {
        let records = try modelContext.fetch(FetchDescriptor<BusinessProfileRecord>())
        return records.max {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt < $1.updatedAt
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func nextInvoiceNumber(issueDate: Date) -> String {
        let year = Calendar.pikaStoreGregorian.component(.year, from: issueDate)
        return InvoiceNumberFormatter(prefix: workspace.businessProfile.invoicePrefix).string(
            year: year,
            sequence: workspace.businessProfile.nextInvoiceNumber
        )
    }

    func snapshotClient(
        id clientID: UUID? = nil,
        named clientName: String,
        draft: InvoiceFinalizationDraft
    ) -> WorkspaceClient {
        let matchedClient = workspace.clients.firstMatching(id: clientID, name: clientName)
        let resolvedClientID = matchedClient?.id ?? clientID ?? UUID()
        let termsDays = invoiceTermsDays(for: matchedClient)

        return WorkspaceClient(
            id: resolvedClientID,
            name: draft.recipientName,
            email: draft.recipientEmail,
            billingAddress: draft.recipientBillingAddress,
            defaultTermsDays: termsDays,
            isArchived: false
        )
    }

    func invoiceTermsDays(for client: WorkspaceClient?) -> Int {
        guard let client,
              Self.clientHasExplicitInvoiceDefaults(client)
        else {
            return workspace.businessProfile.defaultTermsDays
        }

        return client.defaultTermsDays
    }

    private static func clientHasExplicitInvoiceDefaults(_ client: WorkspaceClient) -> Bool {
        let email = client.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = client.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return !email.isEmpty || !billingAddress.isEmpty
    }

    func defaultServicePeriod(for bucket: WorkspaceBucket?) -> String {
        guard let bucket else { return "" }

        let dates = bucket.timeEntries.map(\.date) + bucket.fixedCostEntries.map(\.date)
        guard let first = dates.min(), let last = dates.max() else {
            return ""
        }
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "de_DE")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "dd.MM.yyyy"
        if first == last {
            return dateFormatter.string(from: first)
        }

        return "\(dateFormatter.string(from: first)) - \(dateFormatter.string(from: last))"
    }

    func appendActivity(message: String, detail: String, occurredAt: Date) {
        workspace.activity.append(WorkspaceActivity(
            message: message,
            detail: detail,
            occurredAt: occurredAt
        ))
    }

    func project(_ id: WorkspaceProject.ID) throws -> WorkspaceProject {
        guard let project = workspace.projects.first(where: { $0.id == id }) else {
            throw WorkspaceStoreError.projectNotFound
        }

        return project
    }

    func projectIndex(_ id: WorkspaceProject.ID) throws -> Int {
        guard let index = workspace.projects.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceStoreError.projectNotFound
        }

        return index
    }

    func bucket(_ id: WorkspaceBucket.ID, in project: WorkspaceProject) throws -> WorkspaceBucket {
        guard let bucket = project.buckets.first(where: { $0.id == id }) else {
            throw WorkspaceStoreError.bucketNotFound
        }

        return bucket
    }

    func bucketIndex(_ id: WorkspaceBucket.ID, in project: WorkspaceProject) throws -> Int {
        guard let index = project.buckets.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceStoreError.bucketNotFound
        }

        return index
    }

    func invoiceIndices(_ id: WorkspaceInvoice.ID) throws -> (project: Int, invoice: Int) {
        for projectIndex in workspace.projects.indices {
            if let invoiceIndex = workspace.projects[projectIndex].invoices.firstIndex(where: { $0.id == id }) {
                return (projectIndex, invoiceIndex)
            }
        }

        throw WorkspaceStoreError.invoiceNotFound
    }
}
