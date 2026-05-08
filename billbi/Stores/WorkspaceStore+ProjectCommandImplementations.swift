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

        normalizedRecordStore.insert(projectRecord)
        normalizedRecordStore.insert(bucketRecord)

        return try commitNormalizedWorkspaceMutation {
            guard let project = workspace.projects.first(where: { $0.id == projectID }) else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return project
        } activity: { project in
            WorkspaceActivity(
                message: "\(project.name) project created",
                detail: project.clientName,
                occurredAt: occurredAt
            )
        } telemetry: { project in
            AppTelemetry.projectCreated(projectName: project.name, clientName: project.clientName)
        }
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

        return try commitNormalizedWorkspaceMutation {
            guard let project = workspace.projects.first(where: { $0.id == projectID }) else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return project
        } activity: { project in
            WorkspaceActivity(
                message: "\(project.name) project updated",
                detail: project.clientName,
                occurredAt: occurredAt
            )
        } telemetry: { project in
            AppTelemetry.projectUpdated(projectName: project.name, clientName: project.clientName)
        }
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

        try commitNormalizedWorkspaceMutation {
            guard let project = workspace.projects.first(where: { $0.id == projectID }) else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return project
        } activity: { project in
            WorkspaceActivity(
                message: "\(project.name) \(isArchived ? "archived" : "restored")",
                detail: project.clientName,
                occurredAt: occurredAt
            )
        } telemetry: { project in
            if isArchived {
                AppTelemetry.projectArchived(projectName: project.name)
            } else {
                AppTelemetry.projectRestored(projectName: project.name)
            }
        }
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
        normalizedRecordStore.delete(projectRecord)

        try commitNormalizedWorkspaceMutation {
            projectName
        } activity: { projectName in
            WorkspaceActivity(
                message: "\(projectName) project removed",
                detail: projectClientName,
                occurredAt: occurredAt
            )
        } telemetry: { projectName in
            AppTelemetry.projectRemoved(projectName: projectName)
        }
    }

    private func deleteProjectDependenciesFromNormalizedRecords(
        projectID: WorkspaceProject.ID
    ) throws {
        for bucketRecord in try bucketRecords(for: projectID) {
            try deleteBucketDependenciesFromNormalizedRecords(bucketRecord.id)
            normalizedRecordStore.delete(bucketRecord)
        }

        for invoiceRecord in try invoiceRecords(for: projectID) {
            try deleteInvoiceDependenciesFromNormalizedRecords(invoiceRecord.id)
            normalizedRecordStore.delete(invoiceRecord)
        }
    }

    private func deleteBucketDependenciesFromNormalizedRecords(
        _ bucketID: WorkspaceBucket.ID
    ) throws {
        for timeEntry in try timeEntryRecords(for: bucketID) {
            normalizedRecordStore.delete(timeEntry)
        }

        for fixedCost in try fixedCostRecords(for: bucketID) {
            normalizedRecordStore.delete(fixedCost)
        }
    }

    private func deleteInvoiceDependenciesFromNormalizedRecords(
        _ invoiceID: WorkspaceInvoice.ID
    ) throws {
        for lineItem in try invoiceLineItemRecords(for: invoiceID) {
            normalizedRecordStore.delete(lineItem)
        }
    }
}
