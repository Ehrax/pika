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

        let result = try finalizeInvoiceWorkflowResult(
            projectID: projectID,
            bucketID: bucketID,
            draft: draft
        )
        let invoice = result.invoice
        let projectIndex = try projectIndex(result.projectID)
        let bucketIndex = try bucketIndex(result.bucketID, in: workspace.projects[projectIndex])
        let project = workspace.projects[projectIndex]
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

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
        let result = try finalizeInvoiceWorkflowResult(
            projectID: projectID,
            bucketID: bucketID,
            draft: draft
        )
        try applyInvoiceFinalizationResult(result, preservingActivity: workspace.activity)

        let indices = try invoiceIndices(result.invoice.id)
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

    private func invoiceRecord(_ id: WorkspaceInvoice.ID) throws -> InvoiceRecord? {
        var descriptor = FetchDescriptor<InvoiceRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func finalizeInvoiceWorkflowResult(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft
    ) throws -> InvoiceFinalizationResult {
        do {
            return try WorkspaceInvoicingWorkflow().finalizeInvoice(
                workspace: workspace,
                projectID: projectID,
                bucketID: bucketID,
                draft: draft
            )
        } catch let workflowError as WorkspaceInvoicingWorkflowError {
            throw mapFinalizationWorkflowError(workflowError)
        }
    }

    private func mapFinalizationWorkflowError(
        _ workflowError: WorkspaceInvoicingWorkflowError
    ) -> WorkspaceStoreError {
        switch workflowError {
        case .projectNotFound:
            return .projectNotFound
        case .bucketNotFound:
            return .bucketNotFound
        case let .bucketStatusNotReady(status):
            return .bucketStatusNotReady(status)
        case .bucketNotInvoiceable:
            return .bucketNotInvoiceable
        case .duplicateInvoiceNumber:
            return .duplicateInvoiceNumber
        }
    }
}
