import Foundation
import SwiftData

extension WorkspaceStore {
    func setClientArchived(
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
    func createClientInNormalizedRecords(
        _ draft: WorkspaceClientDraft,
        occurredAt: Date
    ) throws -> WorkspaceClient {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, draft.defaultTermsDays > 0 else {
            throw WorkspaceStoreError.invalidClient
        }

        let now = Date.now
        let record = ClientRecord(
            name: name,
            email: email,
            billingAddress: billingAddress,
            defaultTermsDays: draft.defaultTermsDays,
            recipientTaxLegalFieldsData: "[]",
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
        normalizedRecordStore.insert(record)

        return try commitNormalizedWorkspaceMutation {
            guard let client = workspace.clients.first(where: { $0.id == record.id }) else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return client
        } activity: { client in
            WorkspaceActivity(
                message: "\(client.name) client created",
                detail: client.email,
                occurredAt: occurredAt
            )
        } telemetry: { client in
            AppTelemetry.clientCreated(clientName: client.name)
        }
    }

    @discardableResult
    func updateClientInNormalizedRecords(
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

        return try commitNormalizedWorkspaceMutation {
            guard let client = workspace.clients.first(where: { $0.id == clientID }) else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return client
        } activity: { client in
            WorkspaceActivity(
                message: "\(client.name) client updated",
                detail: client.email,
                occurredAt: occurredAt
            )
        } telemetry: { client in
            AppTelemetry.clientUpdated(clientName: client.name)
        }
    }

    func setClientArchivedInNormalizedRecords(
        clientID: WorkspaceClient.ID,
        isArchived: Bool,
        occurredAt: Date
    ) throws {
        guard let record = try clientRecord(clientID) else {
            throw WorkspaceStoreError.invalidClient
        }

        record.isArchived = isArchived
        record.updatedAt = .now

        try commitNormalizedWorkspaceMutation {
            guard let client = workspace.clients.first(where: { $0.id == clientID }) else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return client
        } activity: { client in
            WorkspaceActivity(
                message: "\(client.name) \(isArchived ? "archived" : "restored")",
                detail: client.email,
                occurredAt: occurredAt
            )
        } telemetry: { client in
            if isArchived {
                AppTelemetry.clientArchived(clientName: client.name)
            } else {
                AppTelemetry.clientRestored(clientName: client.name)
            }
        }
    }

    func removeClientFromNormalizedRecords(
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
        normalizedRecordStore.delete(record)

        try commitNormalizedWorkspaceMutation {
            clientName
        } activity: { clientName in
            WorkspaceActivity(
                message: "\(clientName) client removed",
                detail: clientEmail,
                occurredAt: occurredAt
            )
        } telemetry: { clientName in
            AppTelemetry.clientRemoved(clientName: clientName)
        }
    }
}
