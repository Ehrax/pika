import Foundation
import Observation
import SwiftData

enum WorkspaceStoreError: Error, Equatable {
    case projectNotFound
    case bucketNotFound
    case invoiceNotFound
    case persistenceFailed
    case persistenceConflict
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
    case duplicateInvoiceNumber
    case invalidPaymentMethodSelection
    case clientHasLinkedProjects
    case clientNotArchived
    case projectNotArchived
}

extension WorkspaceStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            "Project not found."
        case .bucketNotFound:
            "Bucket not found."
        case .invoiceNotFound:
            "Invoice not found."
        case .persistenceFailed:
            "The workspace could not be saved."
        case .persistenceConflict:
            "The workspace changed before this action completed. Refresh and try again."
        case .invalidBusinessProfile:
            "Business profile details are incomplete or invalid."
        case .invalidClient:
            "Client details are incomplete or invalid."
        case .invalidProject:
            "Project details are incomplete or invalid."
        case .invalidBucket:
            "Bucket details are incomplete or invalid."
        case .bucketNotInvoiceable:
            "This bucket has no billable work to invoice."
        case .bucketStatusNotReady(let status):
            "This bucket is \(status.rawValue), not ready to invoice."
        case .bucketLocked(let status):
            "This bucket is \(status.rawValue) and cannot be changed."
        case .invalidTimeEntry:
            "Time entry details are incomplete or invalid."
        case .invalidFixedCost:
            "Fixed Charge details are incomplete or invalid."
        case .entryNotFound:
            "Entry not found."
        case .invalidInvoiceStatusTransition(let from, let to):
            "Invoice cannot move from \(from.rawValue) to \(to.rawValue)."
        case .duplicateInvoiceNumber:
            "That invoice number already exists."
        case .invalidPaymentMethodSelection:
            "The selected payment method is incomplete."
        case .clientHasLinkedProjects:
            "This client still has linked projects."
        case .clientNotArchived:
            "Archive the client before removing it."
        case .projectNotArchived:
            "Archive the project before removing it."
        }
    }
}

@Observable
final class WorkspaceStore {
    var workspace: WorkspaceSnapshot

    private let modelContext: ModelContext
    let normalizedRecordStore: any WorkspaceNormalizedRecordStore
    let workspacePersistence: any WorkspacePersistence
    let mutationPolicy: any WorkspaceMutationPolicy
    let invoicingWorkflow: any WorkspaceInvoicing

    init(
        seed: WorkspaceSnapshot = .empty,
        modelContext: ModelContext? = nil,
        resetForSeedImport: Bool = false,
        projectionLoadingAdapter: any WorkspaceProjectionLoadingAdapter = SwiftDataWorkspaceProjectionLoadingAdapter(),
        mutationPolicy: any WorkspaceMutationPolicy = DefaultWorkspaceMutationPolicy(),
        invoicingWorkflow: any WorkspaceInvoicing = WorkspaceInvoicingWorkflow(),
        persistenceAdapter: (any WorkspacePersistenceAdapter)? = nil,
        workspacePersistence: (any WorkspacePersistence)? = nil
    ) {
        self.mutationPolicy = mutationPolicy
        self.invoicingWorkflow = invoicingWorkflow
        let usesNormalizedPersistence = modelContext != nil
        if let modelContext {
            self.modelContext = modelContext
        } else {
            self.modelContext = WorkspaceStore.makeDefaultModelContext()
        }
        self.normalizedRecordStore = SwiftDataWorkspaceNormalizedRecordStore(modelContext: self.modelContext)

        if let workspacePersistence {
            self.workspacePersistence = workspacePersistence
        } else {
            let resolvedPersistenceAdapter = persistenceAdapter ?? SwiftDataWorkspacePersistenceAdapter(
                modelContext: self.modelContext,
                projectionLoadingAdapter: projectionLoadingAdapter
            )
            self.workspacePersistence = DefaultWorkspacePersistence(
                modelContext: self.modelContext,
                usesNormalizedPersistence: usesNormalizedPersistence,
                projectionLoadingAdapter: projectionLoadingAdapter,
                persistenceAdapter: resolvedPersistenceAdapter
            )
        }
        self.workspace = self.workspacePersistence.bootstrapWorkspace(
            seed: seed,
            resetForSeedImport: resetForSeedImport
        )
    }

    static func makeModelContainer(
        mode: AppPersistenceMode,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        try BillbiApp.makeModelContainer(
            mode: mode,
            overrideStoreURL: storeURL
        )
    }

    private static func makeDefaultModelContext() -> ModelContext {
        do {
            let container = try makeModelContainer(mode: .inMemory)
            return ModelContext(container)
        } catch {
            fatalError("Could not create WorkspaceStore ModelContext: \(error)")
        }
    }

    func isUsingNormalizedWorkspacePersistence() -> Bool {
        workspacePersistence.isUsingNormalizedPersistence()
    }
}
