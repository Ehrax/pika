import Foundation

extension WorkspaceStore {
    @discardableResult
    func createClient(
        _ draft: WorkspaceClientDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceClient {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty,
              !email.isEmpty,
              !billingAddress.isEmpty,
              draft.defaultTermsDays > 0
        else {
            throw WorkspaceStoreError.invalidClient
        }

        let client = WorkspaceClient(
            id: UUID(),
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays,
            isArchived: false
        )

        workspace.clients.append(client)
        appendActivity(
            message: "\(client.name) client created",
            detail: client.email,
            occurredAt: occurredAt
        )
        AppTelemetry.clientCreated(clientName: client.name)
        try persistWorkspace()
        return client
    }

    @discardableResult
    func updateClient(
        clientID: WorkspaceClient.ID,
        _ draft: WorkspaceClientDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceClient {
        guard let clientIndex = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty,
              !email.isEmpty,
              !billingAddress.isEmpty,
              draft.defaultTermsDays > 0
        else {
            throw WorkspaceStoreError.invalidClient
        }

        let originalName = workspace.clients[clientIndex].name
        let client = WorkspaceClient(
            id: clientID,
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays,
            isArchived: workspace.clients[clientIndex].isArchived
        )

        workspace.clients[clientIndex] = client
        if originalName != client.name {
            for projectIndex in workspace.projects.indices where
                workspace.projects[projectIndex].clientID == clientID ||
                workspace.projects[projectIndex].clientName == originalName
            {
                workspace.projects[projectIndex].clientID = clientID
                workspace.projects[projectIndex].clientName = client.name
            }
        }
        appendActivity(
            message: "\(client.name) client updated",
            detail: client.email,
            occurredAt: occurredAt
        )
        AppTelemetry.clientUpdated(clientName: client.name)
        try persistWorkspace()
        return client
    }

    func archiveClient(clientID: WorkspaceClient.ID, occurredAt: Date = .now) throws {
        try setClientArchived(clientID: clientID, isArchived: true, occurredAt: occurredAt)
    }

    func restoreClient(clientID: WorkspaceClient.ID, occurredAt: Date = .now) throws {
        try setClientArchived(clientID: clientID, isArchived: false, occurredAt: occurredAt)
    }

    func removeClient(clientID: WorkspaceClient.ID, occurredAt: Date = .now) throws {
        guard let index = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        let client = workspace.clients[index]
        guard client.isArchived else {
            throw WorkspaceStoreError.clientNotArchived
        }

        let hasLinkedProjects = workspace.projects.contains {
            $0.clientID == clientID || $0.clientName == client.name
        }
        guard !hasLinkedProjects else {
            throw WorkspaceStoreError.clientHasLinkedProjects
        }

        workspace.clients.remove(at: index)
        appendActivity(
            message: "\(client.name) client removed",
            detail: client.email,
            occurredAt: occurredAt
        )
        AppTelemetry.clientRemoved(clientName: client.name)
        try persistWorkspace()
    }

    private func setClientArchived(
        clientID: WorkspaceClient.ID,
        isArchived: Bool,
        occurredAt: Date
    ) throws {
        guard let index = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        workspace.clients[index].isArchived = isArchived
        let client = workspace.clients[index]
        appendActivity(
            message: "\(client.name) \(isArchived ? "archived" : "restored")",
            detail: client.email,
            occurredAt: occurredAt
        )

        if isArchived {
            AppTelemetry.clientArchived(clientName: client.name)
        } else {
            AppTelemetry.clientRestored(clientName: client.name)
        }

        try persistWorkspace()
    }
}
