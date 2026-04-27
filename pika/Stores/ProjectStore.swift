import Foundation
import Observation

protocol ProjectStore {
    func placeholderProjects() -> [ProjectRecord]
}

struct NoopProjectStore: ProjectStore {
    func placeholderProjects() -> [ProjectRecord] {
        []
    }
}

struct InvoiceFinalizationDraft: Equatable {
    var recipientName: String
    var recipientEmail: String
    var recipientBillingAddress: String
    var invoiceNumber: String
    var issueDate: Date
    var dueDate: Date
    var currencyCode: String
    var note: String
}

enum WorkspaceStoreError: Error, Equatable {
    case projectNotFound
    case bucketNotFound
    case invoiceNotFound
    case bucketNotInvoiceable
    case bucketStatusNotReady(BucketStatus)
    case invalidInvoiceStatusTransition(from: InvoiceStatus, to: InvoiceStatus)
}

@Observable
final class WorkspaceStore {
    var workspace: WorkspaceSnapshot

    init(seed: WorkspaceSnapshot = .sample) {
        workspace = seed
    }

    func defaultInvoiceDraft(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        issueDate: Date = .now
    ) throws -> InvoiceFinalizationDraft {
        let project = try project(projectID)
        _ = try bucket(bucketID, in: project)
        let client = workspace.clients.first { $0.name == project.clientName }
        let termsDays = client?.defaultTermsDays ?? workspace.businessProfile.defaultTermsDays
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
            issueDate: issueDate,
            dueDate: dueDate,
            currencyCode: project.currencyCode,
            note: workspace.businessProfile.taxNote
        )
    }

    func markBucketReady(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date = .now
    ) throws {
        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard bucket.status == .open, bucket.totalMinorUnits > 0 else {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }

        workspace.projects[projectIndex].buckets[bucketIndex].status = .ready
        appendActivity(
            message: "\(bucket.name) marked ready",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketMarkedReady(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
    }

    @discardableResult
    func finalizeInvoice(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceInvoice {
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
            named: project.clientName,
            draft: draft
        )
        let invoice = WorkspaceInvoice(
            id: UUID(),
            number: draft.invoiceNumber,
            businessSnapshot: workspace.businessProfile,
            clientSnapshot: clientSnapshot,
            clientName: draft.recipientName,
            projectName: project.name,
            bucketName: bucket.name,
            issueDate: draft.issueDate,
            dueDate: draft.dueDate,
            status: .finalized,
            totalMinorUnits: bucket.totalMinorUnits,
            lineItems: lineItems,
            currencyCode: draft.currencyCode,
            note: draft.note.isEmpty ? nil : draft.note
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
        let indices = try invoiceIndices(invoiceID)
        let invoice = workspace.projects[indices.project].invoices[indices.invoice]
        guard invoice.status.canTransition(to: newStatus) else {
            throw WorkspaceStoreError.invalidInvoiceStatusTransition(from: invoice.status, to: newStatus)
        }

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
    }

    private func nextInvoiceNumber(issueDate: Date) -> String {
        let year = Calendar.pikaStoreGregorian.component(.year, from: issueDate)
        return InvoiceNumberFormatter(prefix: workspace.businessProfile.invoicePrefix).string(
            year: year,
            sequence: workspace.businessProfile.nextInvoiceNumber
        )
    }

    private func snapshotClient(
        named clientName: String,
        draft: InvoiceFinalizationDraft
    ) -> WorkspaceClient {
        let clientID = workspace.clients.first { $0.name == clientName }?.id ?? UUID()
        let termsDays = workspace.clients.first { $0.name == clientName }?.defaultTermsDays
            ?? workspace.businessProfile.defaultTermsDays

        return WorkspaceClient(
            id: clientID,
            name: draft.recipientName,
            email: draft.recipientEmail,
            billingAddress: draft.recipientBillingAddress,
            defaultTermsDays: termsDays
        )
    }

    private func appendActivity(message: String, detail: String, occurredAt: Date) {
        workspace.activity.append(WorkspaceActivity(
            message: message,
            detail: detail,
            occurredAt: occurredAt
        ))
    }

    private func project(_ id: WorkspaceProject.ID) throws -> WorkspaceProject {
        guard let project = workspace.projects.first(where: { $0.id == id }) else {
            throw WorkspaceStoreError.projectNotFound
        }

        return project
    }

    private func projectIndex(_ id: WorkspaceProject.ID) throws -> Int {
        guard let index = workspace.projects.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceStoreError.projectNotFound
        }

        return index
    }

    private func bucket(_ id: WorkspaceBucket.ID, in project: WorkspaceProject) throws -> WorkspaceBucket {
        guard let bucket = project.buckets.first(where: { $0.id == id }) else {
            throw WorkspaceStoreError.bucketNotFound
        }

        return bucket
    }

    private func bucketIndex(_ id: WorkspaceBucket.ID, in project: WorkspaceProject) throws -> Int {
        guard let index = project.buckets.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceStoreError.bucketNotFound
        }

        return index
    }

    private func invoiceIndices(_ id: WorkspaceInvoice.ID) throws -> (project: Int, invoice: Int) {
        for projectIndex in workspace.projects.indices {
            if let invoiceIndex = workspace.projects[projectIndex].invoices.firstIndex(where: { $0.id == id }) {
                return (projectIndex, invoiceIndex)
            }
        }

        throw WorkspaceStoreError.invoiceNotFound
    }
}

private extension WorkspaceBucket {
    func invoiceLineItemSnapshots() -> [WorkspaceInvoiceLineItemSnapshot] {
        var items: [WorkspaceInvoiceLineItemSnapshot] = []

        if billableTimeMinorUnits > 0 {
            items.append(WorkspaceInvoiceLineItemSnapshot(
                description: "Billable time",
                quantityLabel: billableHoursLabel,
                amountMinorUnits: billableTimeMinorUnits
            ))
        }

        if fixedCostMinorUnits > 0 {
            items.append(WorkspaceInvoiceLineItemSnapshot(
                description: "Fixed costs",
                quantityLabel: "1 item",
                amountMinorUnits: fixedCostMinorUnits
            ))
        }

        return items
    }
}

private extension InvoiceStatus {
    func canTransition(to status: InvoiceStatus) -> Bool {
        switch (self, status) {
        case (.finalized, .sent),
             (.finalized, .paid),
             (.finalized, .cancelled),
             (.sent, .paid),
             (.sent, .cancelled):
            true
        default:
            false
        }
    }
}

private extension Calendar {
    static let pikaStoreGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}
