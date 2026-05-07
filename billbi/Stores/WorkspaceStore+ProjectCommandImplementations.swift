import Foundation
import SwiftData

extension WorkspaceStore {
    func setProjectArchived(
        projectID: WorkspaceProject.ID,
        isArchived: Bool,
        occurredAt: Date
    ) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try setProjectArchivedInNormalizedRecords(
                projectID: projectID,
                isArchived: isArchived,
                occurredAt: occurredAt
            )
            return
        }

        let index = try projectIndex(projectID)
        workspace.projects[index].isArchived = isArchived
        let project = workspace.projects[index]

        appendActivity(
            message: "\(project.name) \(isArchived ? "archived" : "restored")",
            detail: project.clientName,
            occurredAt: occurredAt
        )

        if isArchived {
            AppTelemetry.projectArchived(projectName: project.name)
        } else {
            AppTelemetry.projectRestored(projectName: project.name)
        }

        try persistWorkspace()
    }

    @discardableResult
    func createProjectInNormalizedRecords(
        _ draft: WorkspaceProjectDraft,
        occurredAt: Date
    ) throws -> WorkspaceProject {
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let bucketName = draft.firstBucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialBucketName = bucketName.isEmpty ? "General" : bucketName

        guard !projectName.isEmpty,
              !currencyCode.isEmpty,
              draft.hourlyRateMinorUnits > 0
        else {
            throw WorkspaceStoreError.invalidProject
        }

        guard let clientRecord = try clientRecord(draft.clientID) else {
            throw WorkspaceStoreError.invalidProject
        }

        let now = Date.now
        let projectID = UUID()
        let projectRecord = ProjectRecord(
            id: projectID,
            clientID: clientRecord.id,
            name: projectName,
            currencyCode: currencyCode,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
            client: clientRecord
        )
        let bucketRecord = BucketRecord(
            projectID: projectID,
            name: initialBucketName,
            defaultHourlyRateMinorUnits: draft.hourlyRateMinorUnits,
            createdAt: now,
            updatedAt: now,
            project: projectRecord
        )

        workspacePersistenceModelContext().insert(projectRecord)
        workspacePersistenceModelContext().insert(bucketRecord)

        try saveAndReloadNormalizedWorkspacePreservingActivity()

        guard let project = workspace.projects.first(where: { $0.id == projectID }) else {
            throw WorkspaceStoreError.persistenceFailed
        }

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
    func updateProjectInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        _ draft: WorkspaceProjectUpdateDraft,
        occurredAt: Date
    ) throws -> WorkspaceProject {
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)

        guard !projectName.isEmpty, !currencyCode.isEmpty else {
            throw WorkspaceStoreError.invalidProject
        }

        guard let projectRecord = try projectRecord(projectID),
              let clientRecord = try clientRecord(draft.clientID)
        else {
            throw WorkspaceStoreError.invalidProject
        }

        projectRecord.name = projectName
        projectRecord.currencyCode = currencyCode
        projectRecord.clientID = clientRecord.id
        projectRecord.client = clientRecord
        projectRecord.updatedAt = .now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        guard let project = workspace.projects.first(where: { $0.id == projectID }) else {
            throw WorkspaceStoreError.persistenceFailed
        }

        appendActivity(
            message: "\(project.name) project updated",
            detail: project.clientName,
            occurredAt: occurredAt
        )
        AppTelemetry.projectUpdated(projectName: project.name, clientName: project.clientName)
        try persistWorkspace()
        return project
    }

    func setProjectArchivedInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        isArchived: Bool,
        occurredAt: Date
    ) throws {
        guard let projectRecord = try projectRecord(projectID) else {
            throw WorkspaceStoreError.projectNotFound
        }

        projectRecord.isArchived = isArchived
        projectRecord.updatedAt = .now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        guard let project = workspace.projects.first(where: { $0.id == projectID }) else {
            throw WorkspaceStoreError.persistenceFailed
        }

        appendActivity(
            message: "\(project.name) \(isArchived ? "archived" : "restored")",
            detail: project.clientName,
            occurredAt: occurredAt
        )

        if isArchived {
            AppTelemetry.projectArchived(projectName: project.name)
        } else {
            AppTelemetry.projectRestored(projectName: project.name)
        }

        try persistWorkspace()
    }

    func removeProjectFromNormalizedRecords(
        projectID: WorkspaceProject.ID,
        occurredAt: Date
    ) throws {
        guard let projectRecord = try projectRecord(projectID) else {
            throw WorkspaceStoreError.invalidProject
        }

        guard projectRecord.isArchived else {
            throw WorkspaceStoreError.projectNotArchived
        }

        let projectName = projectRecord.name
        let projectClientName = workspace.projects.first(where: { $0.id == projectID })?.clientName ?? ""
        try deleteProjectDependenciesFromNormalizedRecords(projectID: projectID)
        workspacePersistenceModelContext().delete(projectRecord)

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        appendActivity(
            message: "\(projectName) project removed",
            detail: projectClientName,
            occurredAt: occurredAt
        )
        AppTelemetry.projectRemoved(projectName: projectName)
        try persistWorkspace()
    }

    private func deleteProjectDependenciesFromNormalizedRecords(
        projectID: WorkspaceProject.ID
    ) throws {
        for bucketRecord in try bucketRecords(for: projectID) {
            try deleteBucketDependenciesFromNormalizedRecords(bucketRecord.id)
            workspacePersistenceModelContext().delete(bucketRecord)
        }

        for invoiceRecord in try invoiceRecords(for: projectID) {
            try deleteInvoiceDependenciesFromNormalizedRecords(invoiceRecord.id)
            workspacePersistenceModelContext().delete(invoiceRecord)
        }
    }

    private func deleteBucketDependenciesFromNormalizedRecords(
        _ bucketID: WorkspaceBucket.ID
    ) throws {
        for timeEntry in try timeEntryRecords(for: bucketID) {
            workspacePersistenceModelContext().delete(timeEntry)
        }

        for fixedCost in try fixedCostRecords(for: bucketID) {
            workspacePersistenceModelContext().delete(fixedCost)
        }
    }

    private func deleteInvoiceDependenciesFromNormalizedRecords(
        _ invoiceID: WorkspaceInvoice.ID
    ) throws {
        for lineItem in try invoiceLineItemRecords(for: invoiceID) {
            workspacePersistenceModelContext().delete(lineItem)
        }
    }
}
