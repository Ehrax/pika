import Foundation

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
}
