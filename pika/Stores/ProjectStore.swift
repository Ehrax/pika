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

struct WorkspaceTimeEntryDraft: Equatable {
    var date: Date
    var timeInput: String
    var description: String
    var isBillable: Bool
}

struct WorkspaceFixedCostDraft: Equatable {
    var date: Date
    var description: String
    var amountMinorUnits: Int
}

struct WorkspaceProjectDraft: Equatable {
    var name: String
    var clientName: String
    var currencyCode: String
    var firstBucketName: String
    var hourlyRateMinorUnits: Int
}

struct WorkspaceBucketDraft: Equatable {
    var name: String
    var hourlyRateMinorUnits: Int
}

struct WorkspaceClientDraft: Equatable {
    var name: String
    var email: String
    var billingAddress: String
    var defaultTermsDays: Int
}

struct WorkspaceBusinessProfileDraft: Equatable {
    var businessName: String
    var email: String
    var address: String
    var invoicePrefix: String
    var nextInvoiceNumber: Int
    var currencyCode: String
    var paymentDetails: String
    var taxNote: String
    var defaultTermsDays: Int

    init(
        businessName: String,
        email: String,
        address: String,
        invoicePrefix: String,
        nextInvoiceNumber: Int,
        currencyCode: String,
        paymentDetails: String,
        taxNote: String,
        defaultTermsDays: Int
    ) {
        self.businessName = businessName
        self.email = email
        self.address = address
        self.invoicePrefix = invoicePrefix
        self.nextInvoiceNumber = nextInvoiceNumber
        self.currencyCode = currencyCode
        self.paymentDetails = paymentDetails
        self.taxNote = taxNote
        self.defaultTermsDays = defaultTermsDays
    }

    init(profile: BusinessProfileProjection) {
        self.init(
            businessName: profile.businessName,
            email: profile.email,
            address: profile.address,
            invoicePrefix: profile.invoicePrefix,
            nextInvoiceNumber: profile.nextInvoiceNumber,
            currencyCode: profile.currencyCode,
            paymentDetails: profile.paymentDetails,
            taxNote: profile.taxNote,
            defaultTermsDays: profile.defaultTermsDays
        )
    }
}

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
    case invalidInvoiceStatusTransition(from: InvoiceStatus, to: InvoiceStatus)
}

@Observable
final class WorkspaceStore {
    var workspace: WorkspaceSnapshot
    private let persistenceURL: URL?

    init(seed: WorkspaceSnapshot = .sample, persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL
        workspace = persistenceURL.flatMap(Self.loadWorkspace(from:)) ?? seed
    }

    static func defaultPersistenceURL() -> URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("Pika", isDirectory: true)
            .appendingPathComponent("workspace.json")
    }

    @discardableResult
    func createClient(
        _ draft: WorkspaceClientDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceClient {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty,
              !email.isEmpty,
              !billingAddress.isEmpty,
              draft.defaultTermsDays > 0
        else {
            throw WorkspaceStoreError.invalidClient
        }

        let client = WorkspaceClient(
            id: UUID(),
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays
        )

        workspace.clients.append(client)
        appendActivity(
            message: "\(client.name) client created",
            detail: client.email,
            occurredAt: occurredAt
        )
        AppTelemetry.clientCreated(clientName: client.name)
        try persistWorkspace()
        return client
    }

    @discardableResult
    func updateClient(
        clientID: WorkspaceClient.ID,
        _ draft: WorkspaceClientDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceClient {
        guard let clientIndex = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty,
              !email.isEmpty,
              !billingAddress.isEmpty,
              draft.defaultTermsDays > 0
        else {
            throw WorkspaceStoreError.invalidClient
        }

        let originalName = workspace.clients[clientIndex].name
        let client = WorkspaceClient(
            id: clientID,
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays
        )

        workspace.clients[clientIndex] = client
        if originalName != client.name {
            for projectIndex in workspace.projects.indices where workspace.projects[projectIndex].clientName == originalName {
                workspace.projects[projectIndex].clientName = client.name
            }
        }
        appendActivity(
            message: "\(client.name) client updated",
            detail: client.email,
            occurredAt: occurredAt
        )
        AppTelemetry.clientUpdated(clientName: client.name)
        try persistWorkspace()
        return client
    }

    func updateBusinessProfile(_ draft: WorkspaceBusinessProfileDraft) throws {
        let businessName = draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let invoicePrefix = draft.invoicePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = draft.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let paymentDetails = draft.paymentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxNote = draft.taxNote.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !businessName.isEmpty,
              !email.isEmpty,
              !address.isEmpty,
              !invoicePrefix.isEmpty,
              !currencyCode.isEmpty,
              !paymentDetails.isEmpty,
              !taxNote.isEmpty,
              draft.nextInvoiceNumber > 0,
              draft.defaultTermsDays > 0
        else {
            throw WorkspaceStoreError.invalidBusinessProfile
        }

        workspace.businessProfile = BusinessProfileProjection(
            businessName: businessName,
            email: email,
            address: address,
            invoicePrefix: invoicePrefix.uppercased(),
            nextInvoiceNumber: draft.nextInvoiceNumber,
            currencyCode: currencyCode.uppercased(),
            paymentDetails: paymentDetails,
            taxNote: taxNote,
            defaultTermsDays: draft.defaultTermsDays
        )
        AppTelemetry.settingsSaved()
        try persistWorkspace()
    }

    @discardableResult
    func createProject(
        _ draft: WorkspaceProjectDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceProject {
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientName = draft.clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = draft.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let bucketName = draft.firstBucketName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !projectName.isEmpty,
              !clientName.isEmpty,
              !currencyCode.isEmpty,
              !bucketName.isEmpty,
              draft.hourlyRateMinorUnits > 0
        else {
            throw WorkspaceStoreError.invalidProject
        }

        let project = WorkspaceProject(
            id: UUID(),
            name: projectName,
            clientName: clientName,
            currencyCode: currencyCode.uppercased(),
            isArchived: false,
            buckets: [
                WorkspaceBucket(
                    id: UUID(),
                    name: bucketName,
                    status: .open,
                    totalMinorUnits: 0,
                    billableMinutes: 0,
                    fixedCostMinorUnits: 0,
                    defaultHourlyRateMinorUnits: draft.hourlyRateMinorUnits
                ),
            ],
            invoices: []
        )

        workspace.projects.append(project)
        appendActivity(
            message: "\(project.name) project created",
            detail: project.clientName,
            occurredAt: occurredAt
        )
        AppTelemetry.projectCreated(projectName: project.name, clientName: project.clientName)
        try persistWorkspace()
        return project
    }

    @discardableResult
    func createBucket(
        projectID: WorkspaceProject.ID,
        _ draft: WorkspaceBucketDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceBucket {
        let projectIndex = try projectIndex(projectID)
        let bucketName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bucketName.isEmpty, draft.hourlyRateMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidBucket
        }

        let bucket = WorkspaceBucket(
            id: UUID(),
            name: bucketName,
            status: .open,
            totalMinorUnits: 0,
            billableMinutes: 0,
            fixedCostMinorUnits: 0,
            defaultHourlyRateMinorUnits: draft.hourlyRateMinorUnits
        )

        workspace.projects[projectIndex].buckets.append(bucket)
        appendActivity(
            message: "\(bucket.name) bucket created",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketCreated(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
        return bucket
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

        guard bucket.status == .open, bucket.effectiveTotalMinorUnits > 0 else {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }

        workspace.projects[projectIndex].buckets[bucketIndex].status = .ready
        appendActivity(
            message: "\(bucket.name) marked ready",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketMarkedReady(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }

    func addTimeEntry(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceTimeEntryDraft,
        occurredAt: Date = .now
    ) throws {
        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        var bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard !bucket.status.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucket.status)
        }

        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !description.isEmpty,
            let durationMinutes = WorkspaceEntryDurationParser.minutes(from: draft.timeInput)
        else {
            throw WorkspaceStoreError.invalidTimeEntry
        }

        bucket.backfillLegacyRowsForEditing(on: draft.date)
        let labels = WorkspaceEntryDurationParser.timeRangeLabels(from: draft.timeInput)
        let displayLabel = WorkspaceEntryDurationParser.displayLabel(from: draft.timeInput)
        bucket.timeEntries.append(WorkspaceTimeEntry(
            date: draft.date,
            startTime: labels?.start ?? displayLabel,
            endTime: labels?.end ?? "",
            durationMinutes: durationMinutes,
            description: description,
            isBillable: draft.isBillable,
            hourlyRateMinorUnits: bucket.hourlyRateMinorUnits ?? 0
        ))
        if bucket.status == .ready {
            bucket.status = .open
        }

        workspace.projects[projectIndex].buckets[bucketIndex] = bucket
        appendActivity(
            message: "\(bucket.name) entry added",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketTimeEntryAdded(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }

    func addFixedCost(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceFixedCostDraft,
        occurredAt: Date = .now
    ) throws {
        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        var bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard !bucket.status.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucket.status)
        }

        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, draft.amountMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidFixedCost
        }

        bucket.backfillLegacyRowsForEditing(on: draft.date)
        bucket.fixedCostEntries.append(WorkspaceFixedCostEntry(
            date: draft.date,
            description: description,
            amountMinorUnits: draft.amountMinorUnits
        ))
        if bucket.status == .ready {
            bucket.status = .open
        }

        workspace.projects[projectIndex].buckets[bucketIndex] = bucket
        appendActivity(
            message: "\(bucket.name) cost added",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketFixedCostAdded(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
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
            totalMinorUnits: bucket.effectiveTotalMinorUnits,
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

        try persistWorkspace()
    }

    nonisolated private static func loadWorkspace(from url: URL) -> WorkspaceSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
    }

    private func persistWorkspace() throws {
        guard let persistenceURL else { return }

        do {
            try FileManager.default.createDirectory(
                at: persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(workspace)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            throw WorkspaceStoreError.persistenceFailed
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
    mutating func backfillLegacyRowsForEditing(on date: Date) {
        guard !hasRowLevelEntries else { return }

        if billableMinutes > 0 {
            timeEntries.append(WorkspaceTimeEntry(
                date: date,
                startTime: "Logged",
                endTime: "",
                durationMinutes: billableMinutes,
                description: "Billable time",
                hourlyRateMinorUnits: hourlyRateMinorUnits ?? 0
            ))
        }

        if nonBillableMinutes > 0 {
            timeEntries.append(WorkspaceTimeEntry(
                date: date,
                startTime: "Logged",
                endTime: "",
                durationMinutes: nonBillableMinutes,
                description: "Non-billable time",
                isBillable: false,
                hourlyRateMinorUnits: hourlyRateMinorUnits ?? 0
            ))
        }

        if fixedCostMinorUnits > 0 {
            fixedCostEntries.append(WorkspaceFixedCostEntry(
                date: date,
                description: "Fixed costs",
                amountMinorUnits: fixedCostMinorUnits
            ))
        }
    }

    func invoiceLineItemSnapshots() -> [WorkspaceInvoiceLineItemSnapshot] {
        var items: [WorkspaceInvoiceLineItemSnapshot] = []

        if billableTimeMinorUnits > 0 {
            items.append(WorkspaceInvoiceLineItemSnapshot(
                description: "Billable time",
                quantityLabel: billableHoursLabel,
                amountMinorUnits: billableTimeMinorUnits
            ))
        }

        if effectiveFixedCostMinorUnits > 0 {
            items.append(WorkspaceInvoiceLineItemSnapshot(
                description: "Fixed costs",
                quantityLabel: fixedCostEntries.isEmpty ? "1 item" : fixedCostEntries.count.formattedItemCount,
                amountMinorUnits: effectiveFixedCostMinorUnits
            ))
        }

        return items
    }
}

private extension Int {
    var formattedItemCount: String {
        self == 1 ? "1 item" : "\(self) items"
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
