import Foundation

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
        let initialBucketName = bucketName.isEmpty ? "General" : bucketName
        guard let client = workspace.clients.first(where: { $0.id == draft.clientID }) else {
            throw WorkspaceStoreError.invalidProject
        }
        let clientName = client.name

        guard !projectName.isEmpty,
              !currencyCode.isEmpty,
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
                    name: initialBucketName,
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
}
