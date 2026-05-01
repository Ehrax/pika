import Foundation
import SwiftData

extension WorkspaceStore {
    func defaultInvoiceDraft(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        issueDate: Date = .now
    ) throws -> InvoiceFinalizationDraft {
        let project = try project(projectID)
        _ = try bucket(bucketID, in: project)
        let client = workspace.clients.firstMatching(id: project.clientID, name: project.clientName)
        let termsDays = invoiceTermsDays(for: client)
        let dueDate = Calendar.pikaStoreGregorian.date(
            byAdding: .day,
            value: termsDays,
            to: issueDate
        ) ?? issueDate

        return InvoiceFinalizationDraft(
            recipientName: client?.name ?? project.clientName,
            recipientEmail: client?.email ?? "",
            recipientBillingAddress: client?.billingAddress ?? "",
            invoiceNumber: nextInvoiceNumber(issueDate: issueDate),
            template: .kleinunternehmerClassic,
            issueDate: issueDate,
            dueDate: dueDate,
            servicePeriod: defaultServicePeriod(for: project.buckets.first { $0.id == bucketID }),
            currencyCode: project.currencyCode,
            taxNote: workspace.businessProfile.taxNote
        )
    }

    @discardableResult
    func finalizeInvoice(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceInvoice {
        if isUsingNormalizedWorkspacePersistence() {
            return try finalizeInvoiceInNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                draft: draft,
                occurredAt: occurredAt
            )
        }

        let invoiceNumber = draft.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureLocalInvoiceNumberIsAvailable(invoiceNumber)

        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let project = workspace.projects[projectIndex]
        let bucket = project.buckets[bucketIndex]

        guard bucket.status == .ready else {
            throw WorkspaceStoreError.bucketStatusNotReady(bucket.status)
        }

        let lineItems = bucket.invoiceLineItemSnapshots()
        guard !lineItems.isEmpty else {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }

        let clientSnapshot = snapshotClient(
            id: project.clientID,
            named: project.clientName,
            draft: draft
        )
        let invoice = finalizedInvoiceSnapshot(
            invoiceNumber: invoiceNumber,
            project: project,
            bucket: bucket,
            draft: draft,
            clientSnapshot: clientSnapshot,
            lineItems: lineItems
        )

        workspace.projects[projectIndex].buckets[bucketIndex].status = .finalized
        workspace.projects[projectIndex].invoices.append(invoice)
        workspace.businessProfile.nextInvoiceNumber += 1
        appendActivity(
            message: "\(invoice.number) finalized",
            detail: invoice.clientName,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketFinalized(bucketName: bucket.name, projectName: project.name)
        AppTelemetry.invoiceCreated(invoiceNumber: invoice.number, clientName: invoice.clientName)
        AppTelemetry.invoiceFinalized(invoiceNumber: invoice.number, clientName: invoice.clientName)
        try persistWorkspace()
        return invoice
    }

    func markInvoiceSent(invoiceID: WorkspaceInvoice.ID, occurredAt: Date = .now) throws {
        try updateInvoiceStatus(invoiceID: invoiceID, to: .sent, occurredAt: occurredAt)
    }

    func markInvoicePaid(invoiceID: WorkspaceInvoice.ID, occurredAt: Date = .now) throws {
        try updateInvoiceStatus(invoiceID: invoiceID, to: .paid, occurredAt: occurredAt)
    }

    func cancelInvoice(invoiceID: WorkspaceInvoice.ID, occurredAt: Date = .now) throws {
        try updateInvoiceStatus(invoiceID: invoiceID, to: .cancelled, occurredAt: occurredAt)
    }

    private func updateInvoiceStatus(
        invoiceID: WorkspaceInvoice.ID,
        to newStatus: InvoiceStatus,
        occurredAt: Date
    ) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try updateInvoiceStatusInNormalizedRecords(
                invoiceID: invoiceID,
                to: newStatus,
                occurredAt: occurredAt
            )
            return
        }

        let indices = try invoiceIndices(invoiceID)
        let invoice = workspace.projects[indices.project].invoices[indices.invoice]
        try mutationPolicy.ensureInvoiceStatusTransition(from: invoice.status, to: newStatus)

        workspace.projects[indices.project].invoices[indices.invoice].status = newStatus
        appendActivity(
            message: "\(invoice.number) marked \(newStatus.rawValue)",
            detail: invoice.clientName,
            occurredAt: occurredAt
        )

        switch newStatus {
        case .sent:
            AppTelemetry.invoiceMarkedSent(invoiceNumber: invoice.number)
        case .paid:
            AppTelemetry.invoiceMarkedPaid(invoiceNumber: invoice.number)
        case .cancelled:
            AppTelemetry.invoiceCancelled(invoiceNumber: invoice.number)
        case .finalized:
            break
        }

        try persistWorkspace()
    }

    private func finalizeInvoiceInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft,
        occurredAt: Date
    ) throws -> WorkspaceInvoice {
        let invoiceNumber = draft.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureLocalInvoiceNumberIsAvailable(invoiceNumber)

        guard let projectRecord = try projectRecord(projectID) else {
            throw WorkspaceStoreError.projectNotFound
        }
        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }
        guard bucketRecord.status == .ready else {
            throw WorkspaceStoreError.bucketStatusNotReady(bucketRecord.status)
        }

        let project = try project(projectID)
        let bucket = try bucket(bucketID, in: project)
        guard bucket.status == .ready else {
            throw WorkspaceStoreError.bucketStatusNotReady(bucket.status)
        }

        let lineItems = bucket.invoiceLineItemSnapshots()
        guard !lineItems.isEmpty else {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }

        let clientSnapshot = snapshotClient(
            id: project.clientID,
            named: project.clientName,
            draft: draft
        )
        let profileRecord = try existingBusinessProfileRecord()
        let now = Date.now

        let invoice = finalizedInvoiceSnapshot(
            invoiceNumber: invoiceNumber,
            project: project,
            bucket: bucket,
            draft: draft,
            clientSnapshot: clientSnapshot,
            lineItems: lineItems
        )
        _ = insertInvoiceRecord(
            for: invoice,
            projectID: projectID,
            bucketID: bucketID,
            updatedAt: now,
            project: projectRecord,
            bucket: bucketRecord
        )

        bucketRecord.status = .finalized
        bucketRecord.updatedAt = now
        profileRecord.nextInvoiceNumber += 1
        profileRecord.updatedAt = now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        let indices = try invoiceIndices(invoice.id)
        let persistedInvoice = workspace.projects[indices.project].invoices[indices.invoice]
        appendActivity(
            message: "\(persistedInvoice.number) finalized",
            detail: persistedInvoice.clientName,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketFinalized(bucketName: persistedInvoice.bucketName, projectName: persistedInvoice.projectName)
        AppTelemetry.invoiceCreated(invoiceNumber: persistedInvoice.number, clientName: persistedInvoice.clientName)
        AppTelemetry.invoiceFinalized(invoiceNumber: persistedInvoice.number, clientName: persistedInvoice.clientName)
        try persistWorkspace()
        return persistedInvoice
    }

    private func updateInvoiceStatusInNormalizedRecords(
        invoiceID: WorkspaceInvoice.ID,
        to newStatus: InvoiceStatus,
        occurredAt: Date
    ) throws {
        guard let invoiceRecord = try invoiceRecord(invoiceID) else {
            throw WorkspaceStoreError.invoiceNotFound
        }

        let oldStatus = invoiceRecord.status
        try mutationPolicy.ensureInvoiceStatusTransition(from: oldStatus, to: newStatus)

        invoiceRecord.status = newStatus
        invoiceRecord.updatedAt = .now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        let indices = try invoiceIndices(invoiceID)
        let invoice = workspace.projects[indices.project].invoices[indices.invoice]
        appendActivity(
            message: "\(invoice.number) marked \(newStatus.rawValue)",
            detail: invoice.clientName,
            occurredAt: occurredAt
        )

        switch newStatus {
        case .sent:
            AppTelemetry.invoiceMarkedSent(invoiceNumber: invoice.number)
        case .paid:
            AppTelemetry.invoiceMarkedPaid(invoiceNumber: invoice.number)
        case .cancelled:
            AppTelemetry.invoiceCancelled(invoiceNumber: invoice.number)
        case .finalized:
            break
        }

        try persistWorkspace()
    }

    private func finalizedInvoiceSnapshot(
        invoiceNumber: String,
        project: WorkspaceProject,
        bucket: WorkspaceBucket,
        draft: InvoiceFinalizationDraft,
        clientSnapshot: WorkspaceClient,
        lineItems: [WorkspaceInvoiceLineItemSnapshot]
    ) -> WorkspaceInvoice {
        WorkspaceInvoice(
            id: UUID(),
            number: invoiceNumber,
            businessSnapshot: workspace.businessProfile,
            clientSnapshot: clientSnapshot,
            clientID: project.clientID ?? clientSnapshot.id,
            clientName: draft.recipientName,
            projectID: project.id,
            projectName: project.name,
            bucketID: bucket.id,
            bucketName: bucket.name,
            template: draft.template,
            issueDate: draft.issueDate,
            dueDate: draft.dueDate,
            servicePeriod: draft.servicePeriod.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .finalized,
            totalMinorUnits: bucket.effectiveTotalMinorUnits,
            lineItems: lineItems,
            currencyCode: CurrencyTextFormatting.normalizedInput(draft.currencyCode),
            note: draft.taxNote.isEmpty ? nil : draft.taxNote
        )
    }

    private func insertInvoiceRecord(
        for invoice: WorkspaceInvoice,
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        updatedAt: Date,
        project projectRecord: ProjectRecord,
        bucket bucketRecord: BucketRecord
    ) -> InvoiceRecord {
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

        return invoiceRecord
    }

    private func invoiceRecord(_ id: WorkspaceInvoice.ID) throws -> InvoiceRecord? {
        var descriptor = FetchDescriptor<InvoiceRecord>(
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

    private func ensureLocalInvoiceNumberIsAvailable(_ invoiceNumber: String) throws {
        let normalizedNumber = normalizedInvoiceNumberKey(invoiceNumber)
        guard !normalizedNumber.isEmpty else { return }

        if isUsingNormalizedWorkspacePersistence() {
            let records = try modelContext.fetch(FetchDescriptor<InvoiceRecord>())
            let hasDuplicate = records.contains {
                normalizedInvoiceNumberKey($0.number) == normalizedNumber
            }
            guard !hasDuplicate else {
                throw WorkspaceStoreError.duplicateInvoiceNumber
            }
            return
        }

        let hasDuplicate = workspace.projects
            .flatMap(\.invoices)
            .contains { normalizedInvoiceNumberKey($0.number) == normalizedNumber }
        guard !hasDuplicate else {
            throw WorkspaceStoreError.duplicateInvoiceNumber
        }
    }

    private func normalizedInvoiceNumberKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
