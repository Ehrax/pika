import Foundation

extension WorkspaceStore {
    func archiveProject(projectID: WorkspaceProject.ID, occurredAt: Date = .now) throws {
        try setProjectArchived(projectID: projectID, isArchived: true, occurredAt: occurredAt)
    }

    func restoreProject(projectID: WorkspaceProject.ID, occurredAt: Date = .now) throws {
        try setProjectArchived(projectID: projectID, isArchived: false, occurredAt: occurredAt)
    }

    func removeProject(projectID: WorkspaceProject.ID, occurredAt: Date = .now) throws {
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
        let index = try projectIndex(projectID)
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientName = draft.clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)

        guard !projectName.isEmpty, !clientName.isEmpty, !currencyCode.isEmpty else {
            throw WorkspaceStoreError.invalidProject
        }

        let resolvedClientID = workspace.clients.first { $0.name == clientName }?.id
        workspace.projects[index].name = projectName
        workspace.projects[index].clientID = resolvedClientID
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
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientName = draft.clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let bucketName = draft.firstBucketName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !projectName.isEmpty,
              !clientName.isEmpty,
              !currencyCode.isEmpty,
              !bucketName.isEmpty,
              draft.hourlyRateMinorUnits > 0
        else {
            throw WorkspaceStoreError.invalidProject
        }

        let resolvedClientID = workspace.clients.first { $0.name == clientName }?.id
        let project = WorkspaceProject(
            id: UUID(),
            clientID: resolvedClientID,
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
}
