import Foundation

extension WorkspaceStore {
    func createRecipientTaxLegalField(clientID: WorkspaceClient.ID, label: String, value: String) throws {
        guard let clientIndex = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        let nextSortOrder = (workspace.clients[clientIndex].recipientTaxLegalFields.map(\.sortOrder).max() ?? -1) + 1
        workspace.clients[clientIndex].recipientTaxLegalFields.append(WorkspaceTaxLegalField(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            placement: .recipientDetails,
            isVisible: true,
            sortOrder: nextSortOrder
        ))

        try persistClientTaxLegalFields(clientID: clientID)
    }

    func updateRecipientTaxLegalField(
        clientID: WorkspaceClient.ID,
        fieldID: WorkspaceTaxLegalField.ID,
        label: String,
        value: String,
        placement: TaxLegalFieldPlacement,
        isVisible: Bool
    ) throws {
        guard let clientIndex = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }
        guard let fieldIndex = workspace.clients[clientIndex].recipientTaxLegalFields.firstIndex(where: { $0.id == fieldID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        workspace.clients[clientIndex].recipientTaxLegalFields[fieldIndex].label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        workspace.clients[clientIndex].recipientTaxLegalFields[fieldIndex].value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        workspace.clients[clientIndex].recipientTaxLegalFields[fieldIndex].placement = placement
        workspace.clients[clientIndex].recipientTaxLegalFields[fieldIndex].isVisible = isVisible

        try persistClientTaxLegalFields(clientID: clientID)
    }

    func reorderRecipientTaxLegalFields(clientID: WorkspaceClient.ID, idsInOrder: [WorkspaceTaxLegalField.ID]) throws {
        guard let clientIndex = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        let existing = workspace.clients[clientIndex].recipientTaxLegalFields
        guard idsInOrder.count == existing.count else {
            throw WorkspaceStoreError.invalidClient
        }

        let fieldsByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var reordered: [WorkspaceTaxLegalField] = []
        for (index, id) in idsInOrder.enumerated() {
            guard var field = fieldsByID[id] else {
                throw WorkspaceStoreError.invalidClient
            }
            field.sortOrder = index
            reordered.append(field)
        }

        workspace.clients[clientIndex].recipientTaxLegalFields = reordered
        try persistClientTaxLegalFields(clientID: clientID)
    }

    func deleteRecipientTaxLegalField(clientID: WorkspaceClient.ID, fieldID: WorkspaceTaxLegalField.ID) throws {
        guard let clientIndex = workspace.clients.firstIndex(where: { $0.id == clientID }) else {
            throw WorkspaceStoreError.invalidClient
        }

        workspace.clients[clientIndex].recipientTaxLegalFields.removeAll { $0.id == fieldID }
        for index in workspace.clients[clientIndex].recipientTaxLegalFields.indices {
            workspace.clients[clientIndex].recipientTaxLegalFields[index].sortOrder = index
        }
        try persistClientTaxLegalFields(clientID: clientID)
    }

    private func persistClientTaxLegalFields(clientID: WorkspaceClient.ID) throws {
        if isUsingNormalizedWorkspacePersistence() {
            guard let record = try clientRecord(clientID) else {
                throw WorkspaceStoreError.invalidClient
            }
            let client = try workspace.clients.first(where: { $0.id == clientID }).unwrap(or: WorkspaceStoreError.invalidClient)
            record.recipientTaxLegalFieldsData = SenderTaxLegalFieldCoding.encode(client.recipientTaxLegalFields)
            record.updatedAt = .now
            try saveAndReloadNormalizedWorkspacePreservingActivity()
        }

        try persistWorkspace()
    }
}

private extension Optional {
    func unwrap(or error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}
