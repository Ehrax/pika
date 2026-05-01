import Foundation
import Observation
import SwiftData

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
    case duplicateInvoiceNumber
    case clientHasLinkedProjects
    case clientNotArchived
    case projectNotArchived
}

@Observable
final class WorkspaceStore {
    var workspace: WorkspaceSnapshot

    let modelContext: ModelContext
    private let usesNormalizedPersistence: Bool
    let projectionLoadingAdapter: any WorkspaceProjectionLoadingAdapter
    let persistenceAdapter: any WorkspacePersistenceAdapter
    let mutationPolicy: any WorkspaceMutationPolicy

    init(
        seed: WorkspaceSnapshot = .empty,
        modelContext: ModelContext? = nil,
        resetForSeedImport: Bool = false,
        projectionLoadingAdapter: any WorkspaceProjectionLoadingAdapter = SwiftDataWorkspaceProjectionLoadingAdapter(),
        mutationPolicy: any WorkspaceMutationPolicy = DefaultWorkspaceMutationPolicy(),
        persistenceAdapter: any WorkspacePersistenceAdapter = SwiftDataWorkspacePersistenceAdapter()
    ) {
        self.projectionLoadingAdapter = projectionLoadingAdapter
        self.mutationPolicy = mutationPolicy
        self.persistenceAdapter = persistenceAdapter
        usesNormalizedPersistence = modelContext != nil
        if let modelContext {
            self.modelContext = modelContext
        } else {
            self.modelContext = WorkspaceStore.makeDefaultModelContext()
        }

        guard usesNormalizedPersistence else {
            workspace = seed
            workspace.normalizeMissingHourlyRates()
            return
        }

        if resetForSeedImport {
            workspace = seed
            workspace.normalizeMissingHourlyRates()
            try? replacePersistentWorkspaceWithSeedImport(workspace)
            return
        }

        let persistedWorkspace = projectionLoadingAdapter.loadNormalizedWorkspace(from: self.modelContext)
        workspace = persistedWorkspace ?? seed
        workspace.normalizeMissingHourlyRates()

        if persistedWorkspace == nil {
            try? replacePersistentWorkspaceWithSeedImport(workspace)
        }
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
        usesNormalizedPersistence && projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext) != nil
    }
}
