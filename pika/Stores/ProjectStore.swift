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
    case clientHasLinkedProjects
    case clientNotArchived
    case projectNotArchived
}

@Observable
final class WorkspaceStore {
    var workspace: WorkspaceSnapshot

    private let modelContext: ModelContext
    private let storageRecordID: UUID
    private static let deterministicImportTimestamp = Date(timeIntervalSince1970: 0)

    init(
        seed: WorkspaceSnapshot = .empty,
        modelContext: ModelContext? = nil,
        resetForSeedImport: Bool = false,
        storageRecordID: UUID = UUID(uuidString: "8C2E6FE9-EA65-4D16-91A0-CF1220195B79")!
    ) {
        self.storageRecordID = storageRecordID

        if let modelContext {
            self.modelContext = modelContext
        } else {
            self.modelContext = WorkspaceStore.makeDefaultModelContext()
        }

        if resetForSeedImport {
            workspace = seed
            workspace.normalizeMissingHourlyRates()
            try? replacePersistentWorkspaceWithSeedImport(workspace)
            return
        }

        let persistedWorkspace = Self.loadWorkspace(from: self.modelContext, recordID: storageRecordID)
        workspace = persistedWorkspace ?? seed
        workspace.normalizeMissingHourlyRates()

        if persistedWorkspace == nil {
            try? persistWorkspace()
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

    private static func loadWorkspace(
        from context: ModelContext,
        recordID: UUID
    ) -> WorkspaceSnapshot? {
        if let normalizedWorkspace = loadNormalizedWorkspace(from: context) {
            return normalizedWorkspace
        }

        return loadLegacyWorkspace(from: context, recordID: recordID)
    }

    private static func loadLegacyWorkspace(
        from context: ModelContext,
        recordID: UUID
    ) -> WorkspaceSnapshot? {
        var descriptor = FetchDescriptor<WorkspaceStorageRecord>(
            predicate: #Predicate { $0.id == recordID }
        )
        descriptor.fetchLimit = 1

        guard let record = try? context.fetch(descriptor).first else {
            return nil
        }

        return decodeWorkspace(from: record.payload)
    }

    private func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        do {
            try Self.clearWorkspaceRecords(from: modelContext)
            try Self.persistNormalizedWorkspace(snapshot, into: modelContext)
            let payload = try Self.encodeWorkspace(snapshot)
            try Self.upsertLegacyWorkspaceStorageRecord(
                payload: payload,
                recordID: storageRecordID,
                in: modelContext
            )
            try modelContext.save()
        } catch {
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    func persistWorkspace() throws {
        do {
            let payload = try Self.encodeWorkspace(workspace)
            try Self.upsertLegacyWorkspaceStorageRecord(
                payload: payload,
                recordID: storageRecordID,
                in: modelContext
            )
            try modelContext.save()
        } catch {
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    private static func encodeWorkspace(_ snapshot: WorkspaceSnapshot) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(snapshot)
    }

    private static func decodeWorkspace(from payload: Data) -> WorkspaceSnapshot? {
        try? PropertyListDecoder().decode(WorkspaceSnapshot.self, from: payload)
    }

    private static func upsertLegacyWorkspaceStorageRecord(
        payload: Data,
        recordID: UUID,
        in context: ModelContext
    ) throws {
        var descriptor = FetchDescriptor<WorkspaceStorageRecord>(
            predicate: #Predicate { $0.id == recordID }
        )
        descriptor.fetchLimit = 1

        if let existingRecord = try context.fetch(descriptor).first {
            existingRecord.apply(payload: payload)
        } else {
            context.insert(WorkspaceStorageRecord(
                id: recordID,
                payload: payload
            ))
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
        try deleteAll(FetchDescriptor<WorkspaceStorageRecord>(), from: context)
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

        var clientRecordsByID: [UUID: ClientRecord] = [:]
        var clientRecordsByName: [String: ClientRecord] = [:]
        for client in snapshot.clients {
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
            clientRecordsByID[record.id] = record
            clientRecordsByName[normalizedNameKey(client.name)] = record
        }

        for project in snapshot.projects {
            let normalizedClientName = normalizedNameKey(project.clientName)
            let resolvedClientRecord: ClientRecord
            if let clientID = project.clientID,
               let existing = clientRecordsByID[clientID] {
                resolvedClientRecord = existing
            } else if let existing = clientRecordsByName[normalizedClientName] {
                resolvedClientRecord = existing
            } else {
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
                clientRecordsByID[synthesizedClientID] = synthesizedClient
                clientRecordsByName[normalizedClientName] = synthesizedClient
                resolvedClientRecord = synthesizedClient
            }

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

            var bucketIDsByName: [String: UUID] = [:]
            for bucket in project.buckets {
                let bucketRecord = BucketRecord(
                    id: bucket.id,
                    projectID: project.id,
                    name: bucket.name,
                    statusRaw: bucket.status.rawValue,
                    createdAt: importedAt,
                    updatedAt: importedAt,
                    project: projectRecord
                )
                context.insert(bucketRecord)
                bucketIDsByName[normalizedNameKey(bucket.name)] = bucket.id

                if bucket.hasRowLevelEntries {
                    for entry in bucket.timeEntries {
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

                    for fixedCost in bucket.fixedCostEntries {
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
                } else {
                    persistLegacyAggregateRows(
                        for: bucket,
                        bucketRecord: bucketRecord,
                        importedAt: importedAt,
                        into: context
                    )
                }
            }

            for invoice in project.invoices {
                let resolvedBucketID =
                    invoice.bucketID
                    ?? bucketIDsByName[normalizedNameKey(invoice.bucketName)]
                    ?? project.buckets.first?.id
                    ?? UUID()
                let fallbackClient = invoice.clientSnapshot
                let invoiceRecord = InvoiceRecord(
                    id: invoice.id,
                    projectID: project.id,
                    bucketID: resolvedBucketID,
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
                    clientName: fallbackClient?.name.isEmpty == false ? (fallbackClient?.name ?? "") : invoice.clientName,
                    clientEmail: fallbackClient?.email ?? "",
                    clientBillingAddress: fallbackClient?.billingAddress ?? "",
                    projectName: invoice.projectName.isEmpty ? project.name : invoice.projectName,
                    bucketName: invoice.bucketName,
                    createdAt: invoice.issueDate,
                    updatedAt: invoice.issueDate
                )
                invoiceRecord.project = projectRecord
                invoiceRecord.bucket = nil
                context.insert(invoiceRecord)

                for (lineItemIndex, lineItem) in invoice.lineItems.enumerated() {
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
        }
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
                ?? (bucket.billableMinutes > 0 ? (billableMinorUnits * 60 / bucket.billableMinutes) : 0)
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
                .hourlyRateMinorUnits,
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
            WorkspaceTimeEntry(
                id: record.id,
                date: record.workDate,
                startTime: timeLabel(minuteOfDay: record.startMinuteOfDay),
                endTime: timeLabel(minuteOfDay: record.endMinuteOfDay),
                durationMinutes: normalizedDurationMinutes(for: record),
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

        workspace.businessProfile = BusinessProfileProjection(
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
        AppTelemetry.settingsSaved()
        try persistWorkspace()
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
        let termsDays = matchedClient?.defaultTermsDays
            ?? workspace.businessProfile.defaultTermsDays

        return WorkspaceClient(
            id: resolvedClientID,
            name: draft.recipientName,
            email: draft.recipientEmail,
            billingAddress: draft.recipientBillingAddress,
            defaultTermsDays: termsDays,
            isArchived: false
        )
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
