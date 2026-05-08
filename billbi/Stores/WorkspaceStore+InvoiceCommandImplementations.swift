import Foundation
import SwiftData

extension WorkspaceStore {
    func updateInvoiceStatus(
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
        try ensureInvoiceStatusTransition(from: invoice.status, to: newStatus)

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

    func finalizeInvoiceInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft,
        occurredAt: Date
    ) throws -> WorkspaceInvoice {
        var didRetryAfterReload = false
        let activityBeforeFinalization = workspace.activity

        while true {
            let result: InvoiceFinalizationResult
            do {
                result = try finalizeInvoiceWorkflowResult(
                    projectID: projectID,
                    bucketID: bucketID,
                    draft: draft
                )
            } catch WorkspaceStoreError.bucketStatusNotReady(.finalized) {
                try reloadNormalizedWorkspace(preservingActivity: activityBeforeFinalization)
                throw WorkspaceStoreError.persistenceConflict
            }
            let finalizedActivity = WorkspaceActivity(
                message: "\(result.invoice.number) finalized",
                detail: result.invoice.clientName,
                occurredAt: occurredAt
            )

            do {
                try applyInvoiceFinalizationResult(
                    result,
                    preservingActivity: activityBeforeFinalization + [finalizedActivity]
                )
            } catch WorkspaceStoreError.persistenceConflict {
                if let invoice = existingFinalizedInvoice(
                    projectID: projectID,
                    bucketID: bucketID,
                    invoiceNumber: draft.invoiceNumber
                ) {
                    return invoice
                }

                guard !didRetryAfterReload,
                      !result.inputFingerprint.matches(
                          workspace: workspace,
                          projectID: projectID,
                          bucketID: bucketID
                      )
                else {
                    throw WorkspaceStoreError.persistenceConflict
                }
                didRetryAfterReload = true
                continue
            }

            let indices = try invoiceIndices(result.invoice.id)
            let persistedInvoice = workspace.projects[indices.project].invoices[indices.invoice]
            AppTelemetry.bucketFinalized(bucketName: persistedInvoice.bucketName, projectName: persistedInvoice.projectName)
            AppTelemetry.invoiceCreated(invoiceNumber: persistedInvoice.number, clientName: persistedInvoice.clientName)
            AppTelemetry.invoiceFinalized(invoiceNumber: persistedInvoice.number, clientName: persistedInvoice.clientName)
            return persistedInvoice
        }
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
        try ensureInvoiceStatusTransition(from: oldStatus, to: newStatus)

        invoiceRecord.status = newStatus
        invoiceRecord.updatedAt = .now

        try commitNormalizedWorkspaceMutation {
            let indices = try invoiceIndices(invoiceID)
            return workspace.projects[indices.project].invoices[indices.invoice]
        } activity: { invoice in
            WorkspaceActivity(
                message: "\(invoice.number) marked \(newStatus.rawValue)",
                detail: invoice.clientName,
                occurredAt: occurredAt
            )
        } telemetry: { invoice in
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
        }
    }

    private func invoiceRecord(_ id: WorkspaceInvoice.ID) throws -> InvoiceRecord? {
        var descriptor = FetchDescriptor<InvoiceRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try normalizedRecordStore.fetch(descriptor).first
    }

    func finalizeInvoiceWorkflowResult(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft
    ) throws -> InvoiceFinalizationResult {
        do {
            return try invoicingWorkflow.finalizeInvoice(
                workspace: workspace,
                projectID: projectID,
                bucketID: bucketID,
                draft: draft
            )
        } catch let workflowError as WorkspaceInvoicingWorkflowError {
            throw mapInvoicingWorkflowError(workflowError)
        }
    }

    private func ensureInvoiceStatusTransition(
        from sourceStatus: InvoiceStatus,
        to targetStatus: InvoiceStatus
    ) throws {
        do {
            try invoicingWorkflow.ensureInvoiceStatusTransition(
                from: sourceStatus,
                to: targetStatus
            )
        } catch let workflowError as WorkspaceInvoicingWorkflowError {
            throw mapInvoicingWorkflowError(workflowError)
        }
    }

    private func mapInvoicingWorkflowError(
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
        case let .invalidInvoiceStatusTransition(from, to):
            return .invalidInvoiceStatusTransition(from: from, to: to)
        }
    }
}
