import Foundation

extension WorkspaceStore {
    @discardableResult
    func createClient(
        _ draft: WorkspaceClientDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceClient {
        if isUsingNormalizedWorkspacePersistence() {
            return try createClientInNormalizedRecords(draft, occurredAt: occurredAt)
        }

        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, draft.defaultTermsDays > 0 else {
            throw WorkspaceStoreError.invalidClient
        }

        let client = WorkspaceClient(
            id: UUID(),
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays,
            isArchived: false,
            recipientTaxLegalFields: []
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
        if isUsingNormalizedWorkspacePersistence() {
            return try updateClientInNormalizedRecords(
                clientID: clientID,
                draft,
                occurredAt: occurredAt
            )
        }

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

        let client = WorkspaceClient(
            id: clientID,
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays,
            isArchived: workspace.clients[clientIndex].isArchived,
            recipientTaxLegalFields: workspace.clients[clientIndex].recipientTaxLegalFields
        )

        workspace.clients[clientIndex] = client
        for projectIndex in workspace.projects.indices where
            workspace.projects[projectIndex].clientID == clientID
        {
            workspace.projects[projectIndex].clientName = client.name
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
        if isUsingNormalizedWorkspacePersistence() {
            try setClientArchivedInNormalizedRecords(
                clientID: clientID,
                isArchived: true,
                occurredAt: occurredAt
            )
            return
        }

        try setClientArchived(clientID: clientID, isArchived: true, occurredAt: occurredAt)
    }

    func restoreClient(clientID: WorkspaceClient.ID, occurredAt: Date = .now) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try setClientArchivedInNormalizedRecords(
                clientID: clientID,
                isArchived: false,
                occurredAt: occurredAt
            )
            return
        }

        try setClientArchived(clientID: clientID, isArchived: false, occurredAt: occurredAt)
    }

    func removeClient(clientID: WorkspaceClient.ID, occurredAt: Date = .now) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try removeClientFromNormalizedRecords(clientID: clientID, occurredAt: occurredAt)
            return
        }

        guard let index = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        let client = workspace.clients[index]
        guard client.isArchived else {
            throw WorkspaceStoreError.clientNotArchived
        }

        let hasLinkedProjects = workspace.projects.contains { $0.clientID == clientID }
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
}
