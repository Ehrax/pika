import Foundation

extension WorkspaceStore {
    func createSenderTaxLegalField(
        label: String,
        value: String,
        placement: TaxLegalFieldPlacement = .senderDetails,
        isVisible: Bool = true
    ) throws {
        var profile = workspace.businessProfile
        let nextSortOrder = (profile.senderTaxLegalFields.map(\.sortOrder).max() ?? -1) + 1
        profile.senderTaxLegalFields.append(WorkspaceTaxLegalField(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            placement: placement,
            isVisible: isVisible,
            sortOrder: nextSortOrder
        ))
        try applySenderTaxLegalFieldProfile(profile)
    }

    func updateSenderTaxLegalField(
        id: WorkspaceTaxLegalField.ID,
        label: String,
        value: String,
        placement: TaxLegalFieldPlacement,
        isVisible: Bool
    ) throws {
        var profile = workspace.businessProfile
        guard let fieldIndex = profile.senderTaxLegalFields.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceStoreError.invalidBusinessProfile
        }

        profile.senderTaxLegalFields[fieldIndex].label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.senderTaxLegalFields[fieldIndex].value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.senderTaxLegalFields[fieldIndex].placement = placement
        profile.senderTaxLegalFields[fieldIndex].isVisible = isVisible
        try applySenderTaxLegalFieldProfile(profile)
    }

    func setSenderTaxLegalFieldVisibility(
        id: WorkspaceTaxLegalField.ID,
        isVisible: Bool
    ) throws {
        guard let field = workspace.businessProfile.senderTaxLegalFields.first(where: { $0.id == id }) else {
            throw WorkspaceStoreError.invalidBusinessProfile
        }

        try updateSenderTaxLegalField(
            id: id,
            label: field.label,
            value: field.value,
            placement: field.placement,
            isVisible: isVisible
        )
    }

    func reorderSenderTaxLegalFields(_ idsInOrder: [WorkspaceTaxLegalField.ID]) throws {
        var profile = workspace.businessProfile
        guard idsInOrder.count == profile.senderTaxLegalFields.count else {
            throw WorkspaceStoreError.invalidBusinessProfile
        }

        let fieldsByID = Dictionary(uniqueKeysWithValues: profile.senderTaxLegalFields.map { ($0.id, $0) })
        var reordered: [WorkspaceTaxLegalField] = []
        reordered.reserveCapacity(idsInOrder.count)

        for (index, id) in idsInOrder.enumerated() {
            guard var field = fieldsByID[id] else {
                throw WorkspaceStoreError.invalidBusinessProfile
            }
            field.sortOrder = index
            reordered.append(field)
        }

        profile.senderTaxLegalFields = reordered
        try applySenderTaxLegalFieldProfile(profile)
    }

    func deleteSenderTaxLegalField(id: WorkspaceTaxLegalField.ID) throws {
        var profile = workspace.businessProfile
        profile.senderTaxLegalFields.removeAll { $0.id == id }
        for index in profile.senderTaxLegalFields.indices {
            profile.senderTaxLegalFields[index].sortOrder = index
        }
        try applySenderTaxLegalFieldProfile(profile)
    }

    private func applySenderTaxLegalFieldProfile(_ profile: BusinessProfileProjection) throws {
        let legacy = legacyIdentifiers(from: profile.senderTaxLegalFields)
        var updatedProfile = profile
        updatedProfile.taxIdentifier = legacy.taxIdentifier
        updatedProfile.economicIdentifier = legacy.economicIdentifier

        let draft = WorkspaceBusinessProfileDraft(profile: updatedProfile)
        try updateBusinessProfile(draft)
    }

    private func legacyIdentifiers(from fields: [WorkspaceTaxLegalField]) -> (taxIdentifier: String, economicIdentifier: String) {
        let normalized = fields
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { field in
                (label: field.label.lowercased(), value: field.value)
            }

        let taxIdentifier = normalized.first(where: { $0.label.contains("steuernummer") || $0.label.contains("tax identifier") })?.value ?? ""
        let economicIdentifier = normalized.first(where: { $0.label.contains("wirtschafts-idnr") || $0.label.contains("economic identifier") })?.value ?? ""
        return (taxIdentifier, economicIdentifier)
    }
}
