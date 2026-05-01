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

    init(
        seed: WorkspaceSnapshot = .empty,
        modelContext: ModelContext? = nil,
        storageRecordID: UUID = UUID(uuidString: "8C2E6FE9-EA65-4D16-91A0-CF1220195B79")!
    ) {
        self.storageRecordID = storageRecordID

        if let modelContext {
            self.modelContext = modelContext
        } else {
            self.modelContext = WorkspaceStore.makeDefaultModelContext()
        }

        let loadedWorkspace = Self.loadWorkspace(from: self.modelContext, recordID: storageRecordID) ?? seed
        workspace = loadedWorkspace
        workspace.normalizeMissingHourlyRates()

        if Self.loadWorkspace(from: self.modelContext, recordID: storageRecordID) == nil {
            try? persistWorkspace()
        }
    }

    static func defaultStoreURL() -> URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("Pika", isDirectory: true)
            .appendingPathComponent("workspace.store")
    }

    static func makeModelContainer(
        mode: AppPersistenceMode
    ) throws -> ModelContainer {
        try PikaApp.makeModelContainer(mode: mode)
    }

    static func makeModelContainer(
        inMemory: Bool,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        if inMemory {
            return try makeModelContainer(mode: .inMemory)
        }

        if let storeURL {
            return try PikaApp.makeModelContainer(
                mode: .local,
                overrideStoreURL: storeURL
            )
        }

        return try makeModelContainer(mode: .local)
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
        var descriptor = FetchDescriptor<WorkspaceStorageRecord>(
            predicate: #Predicate { $0.id == recordID }
        )
        descriptor.fetchLimit = 1

        guard let record = try? context.fetch(descriptor).first else {
            return nil
        }

        return decodeWorkspace(from: record.payload)
    }

    func persistWorkspace() throws {
        do {
            let payload = try Self.encodeWorkspace(workspace)
            var descriptor = FetchDescriptor<WorkspaceStorageRecord>(
                predicate: #Predicate { $0.id == storageRecordID }
            )
            descriptor.fetchLimit = 1

            if let existingRecord = try modelContext.fetch(descriptor).first {
                existingRecord.apply(payload: payload)
            } else {
                let record = WorkspaceStorageRecord(
                    id: storageRecordID,
                    payload: payload
                )
                modelContext.insert(record)
            }

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
