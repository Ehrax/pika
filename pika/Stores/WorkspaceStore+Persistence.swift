import Foundation
import SwiftData

protocol WorkspaceProjectionLoadingAdapter {
    func loadNormalizedWorkspace(from context: ModelContext) -> WorkspaceSnapshot?
}

struct SwiftDataWorkspaceProjectionLoadingAdapter: WorkspaceProjectionLoadingAdapter {
    func loadNormalizedWorkspace(from context: ModelContext) -> WorkspaceSnapshot? {
        SwiftDataWorkspaceProjectionLoader.loadNormalizedWorkspace(from: context)
    }
}

protocol WorkspacePersistenceAdapter {
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws
    func applyInvoiceFinalizationResult(_ result: InvoiceFinalizationResult) throws
    func save() throws
    func rollback()
}

enum WorkspacePersistenceConflictError: Error, Equatable {
    case invoiceFinalizationConflict
}

struct SwiftDataWorkspacePersistenceAdapter: WorkspacePersistenceAdapter {
    let modelContext: ModelContext
    let projectionLoadingAdapter: any WorkspaceProjectionLoadingAdapter
    let seedImportingAdapter: any WorkspaceSeedImportingAdapter

    init(
        modelContext: ModelContext,
        projectionLoadingAdapter: any WorkspaceProjectionLoadingAdapter = SwiftDataWorkspaceProjectionLoadingAdapter(),
        seedImportingAdapter: any WorkspaceSeedImportingAdapter = SwiftDataWorkspaceSeedImportingAdapter()
    ) {
        self.modelContext = modelContext
        self.projectionLoadingAdapter = projectionLoadingAdapter
        self.seedImportingAdapter = seedImportingAdapter
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        try seedImportingAdapter.replacePersistentWorkspaceWithSeedImport(snapshot, in: modelContext)
    }

    func applyInvoiceFinalizationResult(_ result: InvoiceFinalizationResult) throws {
        try ensureFinalizationInputsAreCurrent(result)
        try ensureDurableInvoiceNumberIsAvailable(result.invoice.number)
        try ensureDurableBucketHasNoInvoice(result.bucketID)

        guard let projectRecord = try projectRecord(result.projectID) else {
            throw WorkspacePersistenceConflictError.invoiceFinalizationConflict
        }
        guard let bucketRecord = try bucketRecord(result.bucketID),
              bucketRecord.projectID == result.projectID,
              bucketRecord.status == .ready
        else {
            throw WorkspacePersistenceConflictError.invoiceFinalizationConflict
        }

        let profileRecord = try existingBusinessProfileRecord()
        let now = Date.now
        insertInvoiceRecord(
            for: result.invoice,
            projectID: result.projectID,
            bucketID: result.bucketID,
            updatedAt: now,
            project: projectRecord,
            bucket: bucketRecord
        )
        bucketRecord.status = .finalized
        bucketRecord.updatedAt = now
        profileRecord.nextInvoiceNumber += 1
        profileRecord.updatedAt = now
    }

    func save() throws {
        try modelContext.save()
    }

    func rollback() {
        modelContext.rollback()
    }

    private func ensureFinalizationInputsAreCurrent(_ result: InvoiceFinalizationResult) throws {
        guard let currentWorkspace = projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext),
              result.inputFingerprint.matches(
                  workspace: currentWorkspace,
                  projectID: result.projectID,
                  bucketID: result.bucketID
              )
        else {
            throw WorkspacePersistenceConflictError.invoiceFinalizationConflict
        }
    }

    private func projectRecord(_ id: WorkspaceProject.ID) throws -> ProjectRecord? {
        var descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func bucketRecord(_ id: WorkspaceBucket.ID) throws -> BucketRecord? {
        var descriptor = FetchDescriptor<BucketRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func existingBusinessProfileRecord() throws -> BusinessProfileRecord {
        let records = try modelContext.fetch(FetchDescriptor<BusinessProfileRecord>())
        guard let record = records.max(by: {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt < $1.updatedAt
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }) else {
            throw WorkspaceStoreError.persistenceFailed
        }

        return record
    }

    private func ensureDurableInvoiceNumberIsAvailable(_ invoiceNumber: String) throws {
        let normalizedNumber = WorkspaceInvoice.normalizedNumberKey(invoiceNumber)
        guard !normalizedNumber.isEmpty else { return }

        let records = try modelContext.fetch(FetchDescriptor<InvoiceRecord>())
        let hasDuplicate = records.contains {
            WorkspaceInvoice.normalizedNumberKey($0.number) == normalizedNumber
        }
        guard !hasDuplicate else {
            throw WorkspacePersistenceConflictError.invoiceFinalizationConflict
        }
    }

    private func ensureDurableBucketHasNoInvoice(_ bucketID: WorkspaceBucket.ID) throws {
        var descriptor = FetchDescriptor<InvoiceRecord>(
            predicate: #Predicate { $0.bucketID == bucketID }
        )
        descriptor.fetchLimit = 1
        let hasFinalizedInvoice = try !modelContext.fetch(descriptor).isEmpty
        guard !hasFinalizedInvoice else {
            throw WorkspacePersistenceConflictError.invoiceFinalizationConflict
        }
    }

    private func insertInvoiceRecord(
        for invoice: WorkspaceInvoice,
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        updatedAt: Date,
        project projectRecord: ProjectRecord,
        bucket bucketRecord: BucketRecord
    ) {
        let invoiceRecord = InvoiceRecord(
            id: invoice.id,
            projectID: projectID,
            bucketID: bucketID,
            number: invoice.number,
            templateRaw: invoice.template.rawValue,
            issueDate: invoice.issueDate,
            dueDate: invoice.dueDate,
            servicePeriod: invoice.servicePeriod,
            statusRaw: invoice.status.rawValue,
            totalMinorUnits: invoice.totalMinorUnits,
            currencyCode: invoice.currencyCode,
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
            clientName: invoice.clientSnapshot?.name ?? invoice.clientName,
            clientEmail: invoice.clientSnapshot?.email ?? "",
            clientBillingAddress: invoice.clientSnapshot?.billingAddress ?? "",
            projectName: invoice.projectName,
            bucketName: invoice.bucketName,
            createdAt: invoice.issueDate,
            updatedAt: updatedAt,
            project: projectRecord,
            bucket: bucketRecord
        )
        modelContext.insert(invoiceRecord)

        for (lineItemIndex, lineItem) in invoice.lineItems.enumerated() {
            modelContext.insert(InvoiceLineItemRecord(
                id: lineItem.id,
                invoiceID: invoice.id,
                sortOrder: lineItemIndex,
                descriptionText: lineItem.description,
                quantityLabel: lineItem.quantityLabel,
                amountMinorUnits: lineItem.amountMinorUnits,
                createdAt: invoice.issueDate,
                updatedAt: updatedAt,
                invoice: invoiceRecord
            ))
        }
    }
}

protocol WorkspaceSeedImportingAdapter {
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot, in context: ModelContext) throws
}

struct SwiftDataWorkspaceSeedImportingAdapter: WorkspaceSeedImportingAdapter {
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot, in context: ModelContext) throws {
        try WorkspaceStore.replacePersistentWorkspaceWithSeedImport(snapshot, in: context)
    }
}

protocol WorkspacePersistence {
    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot
    func isUsingNormalizedPersistence() -> Bool
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws
    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot
    func persistWorkspace() throws
    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot
    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot
}

private enum WorkspacePersistenceOperation {
    static let replacePersistentWorkspaceWithSeedImport = "replace_persistent_workspace_with_seed_import"
    static let applyInvoiceFinalizationResult = "apply_invoice_finalization_result"
    static let persistWorkspace = "persist_workspace"
    static let saveAndReloadNormalizedWorkspace = "save_and_reload_normalized_workspace"
}

private final class WorkspaceInvoiceFinalizationWriteLock {
    static let shared = WorkspaceInvoiceFinalizationWriteLock()

    private let lock = NSLock()

    func withLock<Result>(_ operation: () throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

struct DefaultWorkspacePersistence: WorkspacePersistence {
    let modelContext: ModelContext
    let usesNormalizedPersistence: Bool
    let projectionLoadingAdapter: any WorkspaceProjectionLoadingAdapter
    let persistenceAdapter: any WorkspacePersistenceAdapter

    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot {
        guard usesNormalizedPersistence else {
            return normalizedWorkspace(seed)
        }

        if resetForSeedImport {
            let workspace = normalizedWorkspace(seed)
            replacePersistentWorkspaceWithSeedImportIfPossible(workspace)
            return workspace
        }

        let persistedWorkspace = projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext)
        let workspace = normalizedWorkspace(persistedWorkspace ?? seed)
        if persistedWorkspace == nil {
            replacePersistentWorkspaceWithSeedImportIfPossible(workspace)
        }
        return workspace
    }

    func isUsingNormalizedPersistence() -> Bool {
        usesNormalizedPersistence && projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext) != nil
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        try persistenceAdapter.replacePersistentWorkspaceWithSeedImport(normalizedWorkspace(snapshot))
    }

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot {
        try WorkspaceInvoiceFinalizationWriteLock.shared.withLock {
            do {
                try persistenceAdapter.applyInvoiceFinalizationResult(result)
                try persistenceAdapter.save()
            } catch {
                persistenceAdapter.rollback()
                throw error
            }

            return try reloadNormalizedWorkspace(preservingActivity: activity)
        }
    }

    func persistWorkspace() throws {
        try persistenceAdapter.save()
    }

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        try persistenceAdapter.save()
        return try reloadNormalizedWorkspace(preservingActivity: activity)
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        guard var reloadedWorkspace = projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext) else {
            AppTelemetry.persistenceProjectionReloadFailed(
                operation: WorkspacePersistenceOperation.saveAndReloadNormalizedWorkspace
            )
            throw WorkspaceStoreError.persistenceFailed
        }
        reloadedWorkspace.normalizeMissingHourlyRates()
        reloadedWorkspace.activity = activity
        return reloadedWorkspace
    }

    private func normalizedWorkspace(_ snapshot: WorkspaceSnapshot) -> WorkspaceSnapshot {
        var workspace = snapshot
        workspace.normalizeMissingHourlyRates()
        return workspace
    }

    private func replacePersistentWorkspaceWithSeedImportIfPossible(_ workspace: WorkspaceSnapshot) {
        do {
            try replacePersistentWorkspaceWithSeedImport(workspace)
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: WorkspacePersistenceOperation.replacePersistentWorkspaceWithSeedImport,
                message: String(describing: error)
            )
        }
    }
}

extension WorkspaceStore {
    private static let deterministicImportTimestamp = Date(timeIntervalSince1970: 0)

    private struct ClientRecordLookup {
        var byID: [UUID: ClientRecord] = [:]
        var byName: [String: ClientRecord] = [:]

        mutating func insert(_ record: ClientRecord) {
            byID[record.id] = record
            byName[Self.normalizedNameKey(record.name)] = record
        }

        private static func normalizedNameKey(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        try performPersistentWorkspaceWrite(
            operation: WorkspacePersistenceOperation.replacePersistentWorkspaceWithSeedImport
        ) {
            try workspacePersistence.replacePersistentWorkspaceWithSeedImport(snapshot)
        }
    }

    func persistWorkspace() throws {
        try performPersistentWorkspaceWrite(operation: WorkspacePersistenceOperation.persistWorkspace) {
            try workspacePersistence.persistWorkspace()
        }
    }

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws {
        do {
            workspace = try workspacePersistence.applyInvoiceFinalizationResult(
                result,
                preservingActivity: activity
            )
        } catch WorkspacePersistenceConflictError.invoiceFinalizationConflict {
            try reloadNormalizedWorkspace(preservingActivity: activity)
            throw WorkspaceStoreError.persistenceConflict
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: WorkspacePersistenceOperation.applyInvoiceFinalizationResult,
                message: String(describing: error)
            )
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    fileprivate static func replacePersistentWorkspaceWithSeedImport(
        _ snapshot: WorkspaceSnapshot,
        in context: ModelContext
    ) throws {
        try clearWorkspaceRecords(from: context)
        try persistNormalizedWorkspace(snapshot, into: context)
        try context.save()
    }

    private func performPersistentWorkspaceWrite(
        operation: String,
        _ write: () throws -> Void
    ) throws {
        do {
            try write()
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: operation,
                message: String(describing: error)
            )
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
        let importedAt = Self.deterministicImportTimestamp

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
           let existing = clientLookup.byID[clientID]
        {
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
              (0 ... 23).contains(hours),
              (0 ... 59).contains(minutes)
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

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws {
        do {
            workspace = try workspacePersistence.saveAndReloadNormalizedWorkspace(
                preservingActivity: activity
            )
        } catch WorkspaceStoreError.persistenceFailed {
            throw WorkspaceStoreError.persistenceFailed
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: WorkspacePersistenceOperation.saveAndReloadNormalizedWorkspace,
                message: String(describing: error)
            )
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    func saveAndReloadNormalizedWorkspacePreservingActivity() throws {
        try saveAndReloadNormalizedWorkspace(preservingActivity: workspace.activity)
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws {
        do {
            workspace = try workspacePersistence.reloadNormalizedWorkspace(
                preservingActivity: activity
            )
        } catch WorkspaceStoreError.persistenceFailed {
            throw WorkspaceStoreError.persistenceFailed
        } catch {
            AppTelemetry.persistenceProjectionReloadFailed(
                operation: WorkspacePersistenceOperation.saveAndReloadNormalizedWorkspace
            )
            throw WorkspaceStoreError.persistenceFailed
        }
    }
}
