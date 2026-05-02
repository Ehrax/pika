import Foundation

struct InvoiceFinalizationResult: Equatable {
    let projectID: WorkspaceProject.ID
    let bucketID: WorkspaceBucket.ID
    let invoice: WorkspaceInvoice
}

enum WorkspaceInvoicingWorkflowError: Error, Equatable {
    case projectNotFound
    case bucketNotFound
    case bucketStatusNotReady(BucketStatus)
    case bucketNotInvoiceable
    case duplicateInvoiceNumber
}

struct WorkspaceInvoicingWorkflow {
    func finalizeInvoice(
        workspace: WorkspaceSnapshot,
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft
    ) throws -> InvoiceFinalizationResult {
        let invoiceNumber = draft.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        try ensureInvoiceNumberIsAvailable(invoiceNumber, in: workspace)

        guard let project = workspace.projects.first(where: { $0.id == projectID }) else {
            throw WorkspaceInvoicingWorkflowError.projectNotFound
        }
        guard let bucket = project.buckets.first(where: { $0.id == bucketID }) else {
            throw WorkspaceInvoicingWorkflowError.bucketNotFound
        }
        guard bucket.status == .ready else {
            throw WorkspaceInvoicingWorkflowError.bucketStatusNotReady(bucket.status)
        }

        let lineItems = bucket.invoiceLineItemSnapshots()
        guard !lineItems.isEmpty else {
            throw WorkspaceInvoicingWorkflowError.bucketNotInvoiceable
        }

        let clientSnapshot = snapshotClient(in: workspace, project: project, draft: draft)
        let invoice = WorkspaceInvoice(
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

        return InvoiceFinalizationResult(
            projectID: project.id,
            bucketID: bucket.id,
            invoice: invoice
        )
    }

    private func ensureInvoiceNumberIsAvailable(
        _ invoiceNumber: String,
        in workspace: WorkspaceSnapshot
    ) throws {
        let normalizedNumber = WorkspaceInvoice.normalizedNumberKey(invoiceNumber)
        guard !normalizedNumber.isEmpty else { return }

        let hasDuplicate = workspace.projects
            .flatMap(\.invoices)
            .contains { WorkspaceInvoice.normalizedNumberKey($0.number) == normalizedNumber }
        guard !hasDuplicate else {
            throw WorkspaceInvoicingWorkflowError.duplicateInvoiceNumber
        }
    }

    private func snapshotClient(
        in workspace: WorkspaceSnapshot,
        project: WorkspaceProject,
        draft: InvoiceFinalizationDraft
    ) -> WorkspaceClient {
        let matchedClient = workspace.clients.firstMatching(id: project.clientID, name: project.clientName)
        let resolvedClientID = matchedClient?.id ?? project.clientID ?? UUID()
        let termsDays = invoiceTermsDays(in: workspace, for: matchedClient)

        return WorkspaceClient(
            id: resolvedClientID,
            name: draft.recipientName,
            email: draft.recipientEmail,
            billingAddress: draft.recipientBillingAddress,
            defaultTermsDays: termsDays,
            isArchived: false
        )
    }

    private func invoiceTermsDays(in workspace: WorkspaceSnapshot, for client: WorkspaceClient?) -> Int {
        guard let client,
              client.hasExplicitInvoiceDefaults
        else {
            return workspace.businessProfile.defaultTermsDays
        }

        return client.defaultTermsDays
    }
}
