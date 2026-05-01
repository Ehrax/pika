import Foundation
import SwiftData

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
            isArchived: workspace.clients[clientIndex].isArchived
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

    @discardableResult
    private func createClientInNormalizedRecords(
        _ draft: WorkspaceClientDraft,
        occurredAt: Date
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

        let now = Date.now
        let record = ClientRecord(
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(record)

        let previousActivity = workspace.activity
        try saveAndReloadNormalizedWorkspace(preservingActivity: previousActivity)
        guard let client = workspace.clients.first(where: { $0.id == record.id }) else {
            throw WorkspaceStoreError.persistenceFailed
        }

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
    private func updateClientInNormalizedRecords(
        clientID: WorkspaceClient.ID,
        _ draft: WorkspaceClientDraft,
        occurredAt: Date
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

        guard let record = try clientRecord(clientID) else {
            throw WorkspaceStoreError.invalidClient
        }

        record.name = name
        record.email = email
        record.billingAddress = billingAddress
        record.defaultTermsDays = draft.defaultTermsDays
        record.updatedAt = .now

        let previousActivity = workspace.activity
        try saveAndReloadNormalizedWorkspace(preservingActivity: previousActivity)
        guard let client = workspace.clients.first(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.persistenceFailed
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

    private func setClientArchivedInNormalizedRecords(
        clientID: WorkspaceClient.ID,
        isArchived: Bool,
        occurredAt: Date
    ) throws {
        guard let record = try clientRecord(clientID) else {
            throw WorkspaceStoreError.invalidClient
        }

        record.isArchived = isArchived
        record.updatedAt = .now

        let previousActivity = workspace.activity
        try saveAndReloadNormalizedWorkspace(preservingActivity: previousActivity)
        guard let client = workspace.clients.first(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.persistenceFailed
        }

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

    private func removeClientFromNormalizedRecords(
        clientID: WorkspaceClient.ID,
        occurredAt: Date
    ) throws {
        guard let record = try clientRecord(clientID) else {
            throw WorkspaceStoreError.invalidClient
        }

        guard record.isArchived else {
            throw WorkspaceStoreError.clientNotArchived
        }

        guard try !hasProjectRecordLinked(to: clientID) else {
            throw WorkspaceStoreError.clientHasLinkedProjects
        }

        let clientName = record.name
        let clientEmail = record.email
        modelContext.delete(record)

        let previousActivity = workspace.activity
        try saveAndReloadNormalizedWorkspace(preservingActivity: previousActivity)
        appendActivity(
            message: "\(clientName) client removed",
            detail: clientEmail,
            occurredAt: occurredAt
        )
        AppTelemetry.clientRemoved(clientName: clientName)
        try persistWorkspace()
    }
}
