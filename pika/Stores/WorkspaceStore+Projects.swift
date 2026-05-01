import Foundation
import SwiftData

extension WorkspaceStore {
    func archiveProject(projectID: WorkspaceProject.ID, occurredAt: Date = .now) throws {
        try setProjectArchived(projectID: projectID, isArchived: true, occurredAt: occurredAt)
    }

    func restoreProject(projectID: WorkspaceProject.ID, occurredAt: Date = .now) throws {
        try setProjectArchived(projectID: projectID, isArchived: false, occurredAt: occurredAt)
    }

    func removeProject(projectID: WorkspaceProject.ID, occurredAt: Date = .now) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try removeProjectFromNormalizedRecords(projectID: projectID, occurredAt: occurredAt)
            return
        }

        guard let index = workspace.projects.firstIndex(where: { $0.id == projectID }) else {
            throw WorkspaceStoreError.invalidProject
        }

        let project = workspace.projects[index]
        guard project.isArchived else {
            throw WorkspaceStoreError.projectNotArchived
        }

        workspace.projects.remove(at: index)
        appendActivity(
            message: "\(project.name) project removed",
            detail: project.clientName,
            occurredAt: occurredAt
        )
        AppTelemetry.projectRemoved(projectName: project.name)
        try persistWorkspace()
    }

    @discardableResult
    func updateProject(
        projectID: WorkspaceProject.ID,
        _ draft: WorkspaceProjectUpdateDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceProject {
        if isUsingNormalizedWorkspacePersistence() {
            return try updateProjectInNormalizedRecords(
                projectID: projectID,
                draft,
                occurredAt: occurredAt
            )
        }

        let index = try projectIndex(projectID)
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        guard let client = workspace.clients.first(where: { $0.id == draft.clientID }) else {
            throw WorkspaceStoreError.invalidProject
        }
        let clientName = client.name

        guard !projectName.isEmpty, !currencyCode.isEmpty else {
            throw WorkspaceStoreError.invalidProject
        }

        workspace.projects[index].name = projectName
        workspace.projects[index].clientID = client.id
        workspace.projects[index].clientName = clientName
        workspace.projects[index].currencyCode = currencyCode
        let project = workspace.projects[index]

        appendActivity(
            message: "\(project.name) project updated",
            detail: project.clientName,
            occurredAt: occurredAt
        )
        AppTelemetry.projectUpdated(projectName: project.name, clientName: project.clientName)
        try persistWorkspace()
        return project
    }

    @discardableResult
    func createProject(
        _ draft: WorkspaceProjectDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceProject {
        if isUsingNormalizedWorkspacePersistence() {
            return try createProjectInNormalizedRecords(draft, occurredAt: occurredAt)
        }

        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let bucketName = draft.firstBucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client = workspace.clients.first(where: { $0.id == draft.clientID }) else {
            throw WorkspaceStoreError.invalidProject
        }
        let clientName = client.name

        guard !projectName.isEmpty,
              !currencyCode.isEmpty,
              !bucketName.isEmpty,
              draft.hourlyRateMinorUnits > 0
        else {
            throw WorkspaceStoreError.invalidProject
        }

        let project = WorkspaceProject(
            id: UUID(),
            clientID: client.id,
            name: projectName,
            clientName: clientName,
            currencyCode: currencyCode,
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

    private func setProjectArchived(
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
    private func createProjectInNormalizedRecords(
        _ draft: WorkspaceProjectDraft,
        occurredAt: Date
    ) throws -> WorkspaceProject {
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let bucketName = draft.firstBucketName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !projectName.isEmpty,
              !currencyCode.isEmpty,
              !bucketName.isEmpty,
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
            name: bucketName,
            createdAt: now,
            updatedAt: now,
            project: projectRecord
        )

        modelContext.insert(projectRecord)
        modelContext.insert(bucketRecord)

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
    private func updateProjectInNormalizedRecords(
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

    private func setProjectArchivedInNormalizedRecords(
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

    private func removeProjectFromNormalizedRecords(
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
        modelContext.delete(projectRecord)

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
            modelContext.delete(bucketRecord)
        }

        for invoiceRecord in try invoiceRecords(for: projectID) {
            try deleteInvoiceDependenciesFromNormalizedRecords(invoiceRecord.id)
            modelContext.delete(invoiceRecord)
        }
    }

    private func deleteBucketDependenciesFromNormalizedRecords(
        _ bucketID: WorkspaceBucket.ID
    ) throws {
        for timeEntry in try timeEntryRecords(for: bucketID) {
            modelContext.delete(timeEntry)
        }

        for fixedCost in try fixedCostRecords(for: bucketID) {
            modelContext.delete(fixedCost)
        }
    }

    private func deleteInvoiceDependenciesFromNormalizedRecords(
        _ invoiceID: WorkspaceInvoice.ID
    ) throws {
        for lineItem in try invoiceLineItemRecords(for: invoiceID) {
            modelContext.delete(lineItem)
        }
    }
}
