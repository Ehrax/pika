import Foundation

extension WorkspaceStore {
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
