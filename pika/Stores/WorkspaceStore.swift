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
    case clientHasLinkedProjects
    case clientNotArchived
    case projectNotArchived
}

@Observable
final class WorkspaceStore {
    var workspace: WorkspaceSnapshot

    private let modelContext: ModelContext
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

        if let workspacePersistence {
            self.workspacePersistence = workspacePersistence
        } else {
            let resolvedPersistenceAdapter = persistenceAdapter ?? SwiftDataWorkspacePersistenceAdapter(
                modelContext: self.modelContext
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
        try PikaApp.makeModelContainer(
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

    func workspacePersistenceModelContext() -> ModelContext {
        modelContext
    }
}
