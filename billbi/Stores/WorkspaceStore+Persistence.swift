import Foundation
import SwiftData

protocol WorkspacePersistence {
    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot
    func isUsingNormalizedPersistence() -> Bool
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws
    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot
    func persistWorkspace() throws
    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot
    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot
}

private enum WorkspacePersistenceOperation {
    static let replacePersistentWorkspaceWithSeedImport = "replace_persistent_workspace_with_seed_import"
    static let applyInvoiceFinalizationResult = "apply_invoice_finalization_result"
    static let persistWorkspace = "persist_workspace"
    static let saveAndReloadNormalizedWorkspace = "save_and_reload_normalized_workspace"
}

private final class WorkspaceInvoiceFinalizationWriteLock {
    static let shared = WorkspaceInvoiceFinalizationWriteLock()

    private let lock = NSLock()

    func withLock<Result>(_ operation: () throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

struct DefaultWorkspacePersistence: WorkspacePersistence {
    let modelContext: ModelContext
    let usesNormalizedPersistence: Bool
    let projectionLoadingAdapter: any WorkspaceProjectionLoadingAdapter
    let persistenceAdapter: any WorkspacePersistenceAdapter

    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot {
        guard usesNormalizedPersistence else {
            return normalizedWorkspace(seed)
        }

        if resetForSeedImport {
            let workspace = normalizedWorkspace(seed)
            replacePersistentWorkspaceWithSeedImportIfPossible(workspace)
            return workspace
        }

        let persistedWorkspace = projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext)
        let workspace = normalizedWorkspace(persistedWorkspace ?? seed)
        if persistedWorkspace == nil {
            replacePersistentWorkspaceWithSeedImportIfPossible(workspace)
        }
        return workspace
    }

    func isUsingNormalizedPersistence() -> Bool {
        usesNormalizedPersistence && projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext) != nil
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        do {
            try persistenceAdapter.replacePersistentWorkspaceWithSeedImport(normalizedWorkspace(snapshot))
        } catch {
            persistenceAdapter.rollback()
            throw error
        }
    }

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot {
        try WorkspaceInvoiceFinalizationWriteLock.shared.withLock {
            do {
                try persistenceAdapter.applyInvoiceFinalizationResult(result)
                try persistenceAdapter.save()
            } catch {
                persistenceAdapter.rollback()
                throw error
            }

            return try reloadNormalizedWorkspace(preservingActivity: activity)
        }
    }

    func persistWorkspace() throws {
        try persistenceAdapter.save()
    }

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        try persistenceAdapter.save()
        return try reloadNormalizedWorkspace(preservingActivity: activity)
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        guard var reloadedWorkspace = projectionLoadingAdapter.loadNormalizedWorkspace(from: modelContext) else {
            AppTelemetry.persistenceProjectionReloadFailed(
                operation: WorkspacePersistenceOperation.saveAndReloadNormalizedWorkspace
            )
            throw WorkspaceStoreError.persistenceFailed
        }
        reloadedWorkspace.normalizeMissingHourlyRates()
        reloadedWorkspace.activity = activity
        return reloadedWorkspace
    }

    private func normalizedWorkspace(_ snapshot: WorkspaceSnapshot) -> WorkspaceSnapshot {
        var workspace = snapshot
        workspace.normalizeMissingHourlyRates()
        return workspace
    }

    private func replacePersistentWorkspaceWithSeedImportIfPossible(_ workspace: WorkspaceSnapshot) {
        do {
            try replacePersistentWorkspaceWithSeedImport(workspace)
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: WorkspacePersistenceOperation.replacePersistentWorkspaceWithSeedImport,
                message: String(describing: error)
            )
        }
    }
}

extension WorkspaceStore {
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        try performPersistentWorkspaceWrite(
            operation: WorkspacePersistenceOperation.replacePersistentWorkspaceWithSeedImport
        ) {
            try workspacePersistence.replacePersistentWorkspaceWithSeedImport(snapshot)
        }
    }

    func persistWorkspace() throws {
        try performPersistentWorkspaceWrite(operation: WorkspacePersistenceOperation.persistWorkspace) {
            try workspacePersistence.persistWorkspace()
        }
    }

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws {
        do {
            workspace = try workspacePersistence.applyInvoiceFinalizationResult(
                result,
                preservingActivity: activity
            )
        } catch WorkspacePersistenceConflictError.invoiceFinalizationConflict {
            try reloadNormalizedWorkspace(preservingActivity: activity)
            throw WorkspaceStoreError.persistenceConflict
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: WorkspacePersistenceOperation.applyInvoiceFinalizationResult,
                message: String(describing: error)
            )
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    private func performPersistentWorkspaceWrite(
        operation: String,
        _ write: () throws -> Void
    ) throws {
        do {
            try write()
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: operation,
                message: String(describing: error)
            )
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws {
        do {
            workspace = try workspacePersistence.saveAndReloadNormalizedWorkspace(
                preservingActivity: activity
            )
        } catch WorkspaceStoreError.persistenceFailed {
            throw WorkspaceStoreError.persistenceFailed
        } catch {
            AppTelemetry.persistenceSaveFailed(
                operation: WorkspacePersistenceOperation.saveAndReloadNormalizedWorkspace,
                message: String(describing: error)
            )
            throw WorkspaceStoreError.persistenceFailed
        }
    }

    func saveAndReloadNormalizedWorkspacePreservingActivity() throws {
        try saveAndReloadNormalizedWorkspace(preservingActivity: workspace.activity)
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws {
        do {
            workspace = try workspacePersistence.reloadNormalizedWorkspace(
                preservingActivity: activity
            )
        } catch WorkspaceStoreError.persistenceFailed {
            throw WorkspaceStoreError.persistenceFailed
        } catch {
            AppTelemetry.persistenceProjectionReloadFailed(
                operation: WorkspacePersistenceOperation.saveAndReloadNormalizedWorkspace
            )
            throw WorkspaceStoreError.persistenceFailed
        }
    }
}
