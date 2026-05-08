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
            businessSenderTaxLegalFieldsData: SenderTaxLegalFieldCoding.encode(invoice.businessSnapshot?.senderTaxLegalFields ?? []),
            selectedPaymentMethodData: PaymentMethodCoding.encodeOptional(invoice.selectedPaymentMethodSnapshot),
            businessTaxNote: invoice.businessSnapshot?.taxNote ?? "",
            clientName: invoice.clientSnapshot?.name ?? invoice.clientName,
            clientEmail: invoice.clientSnapshot?.email ?? "",
            clientBillingAddress: invoice.clientSnapshot?.billingAddress ?? "",
            clientRecipientTaxLegalFieldsData: SenderTaxLegalFieldCoding.encode(invoice.clientSnapshot?.recipientTaxLegalFields ?? []),
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
        try SwiftDataWorkspaceSeedImporter.replacePersistentWorkspaceWithSeedImport(snapshot, in: context)
    }
}
