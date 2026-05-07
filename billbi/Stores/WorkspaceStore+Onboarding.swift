import Foundation
import SwiftData

extension WorkspaceStore {
    func completeOnboarding() throws {
        workspace.onboardingCompleted = true
        if isUsingNormalizedWorkspacePersistence() {
            try updateOnboardingCompletionInNormalizedRecords(isCompleted: true)
        }
        try persistWorkspace()
    }

    func resetOnboardingCompletionForDebug() throws {
        workspace.onboardingCompleted = false
        if isUsingNormalizedWorkspacePersistence() {
            try updateOnboardingCompletionInNormalizedRecords(isCompleted: false)
        }
        try persistWorkspace()
    }

    func saveOnboardingBusiness(_ draft: OnboardingBusinessDraft) throws {
        let businessName = draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !businessName.isEmpty else { return }

        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let profile = BusinessProfileProjection(
            businessName: businessName,
            personName: draft.personName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: draft.email.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: draft.phone.trimmingCharacters(in: .whitespacesAndNewlines),
            address: draft.address.trimmingCharacters(in: .whitespacesAndNewlines),
            taxIdentifier: draft.taxIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            invoicePrefix: workspace.businessProfile.invoicePrefix.isEmpty ? "INV" : workspace.businessProfile.invoicePrefix,
            nextInvoiceNumber: max(workspace.businessProfile.nextInvoiceNumber, 1),
            currencyCode: currencyCode.isEmpty ? workspace.businessProfile.currencyCode : currencyCode,
            paymentDetails: draft.paymentDetails.trimmingCharacters(in: .whitespacesAndNewlines),
            taxNote: workspace.businessProfile.taxNote,
            defaultTermsDays: draft.defaultTermsDays > 0 ? draft.defaultTermsDays : workspace.businessProfile.defaultTermsDays
        )

        workspace.businessProfile = profile
        if isUsingNormalizedWorkspacePersistence() {
            try updateBusinessProfileInNormalizedRecords(with: profile)
        }
        try persistWorkspace()
    }

    @discardableResult
    func saveOnboardingClient(_ draft: OnboardingClientDraft, occurredAt: Date = .now) throws -> WorkspaceClient? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        return try createOnboardingClient(
            WorkspaceClientDraft(
                name: name,
                email: draft.email.trimmingCharacters(in: .whitespacesAndNewlines),
                billingAddress: draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                defaultTermsDays: workspace.businessProfile.defaultTermsDays
            ),
            occurredAt: occurredAt
        )
    }

    @discardableResult
    func saveOnboardingProject(_ draft: OnboardingProjectDraft, occurredAt: Date = .now) throws -> WorkspaceProject? {
        let projectName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectName.isEmpty,
              let clientID = draft.clientID
        else {
            return nil
        }

        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let bucketName = draft.firstBucketName.trimmingCharacters(in: .whitespacesAndNewlines)
        return try createOnboardingProject(
            WorkspaceProjectDraft(
                name: projectName,
                clientID: clientID,
                currencyCode: currencyCode.isEmpty ? workspace.businessProfile.currencyCode : currencyCode,
                firstBucketName: bucketName.isEmpty ? "General" : bucketName,
                hourlyRateMinorUnits: draft.hourlyRateMinorUnits > 0 ? draft.hourlyRateMinorUnits : 8_000
            ),
            occurredAt: occurredAt
        )
    }

    @discardableResult
    private func createOnboardingClient(
        _ draft: WorkspaceClientDraft,
        occurredAt: Date
    ) throws -> WorkspaceClient {
        if isUsingNormalizedWorkspacePersistence() {
            return try createOnboardingClientInNormalizedRecords(draft, occurredAt: occurredAt)
        }

        let client = WorkspaceClient(
            id: UUID(),
            name: draft.name,
            email: draft.email,
            billingAddress: draft.billingAddress,
            defaultTermsDays: max(draft.defaultTermsDays, 1),
            isArchived: false
        )
        workspace.clients.append(client)
        appendActivity(message: "\(client.name) client created", detail: client.email, occurredAt: occurredAt)
        try persistWorkspace()
        return client
    }

    @discardableResult
    private func createOnboardingClientInNormalizedRecords(
        _ draft: WorkspaceClientDraft,
        occurredAt: Date
    ) throws -> WorkspaceClient {
        let now = Date.now
        let record = ClientRecord(
            name: draft.name,
            email: draft.email,
            billingAddress: draft.billingAddress,
            defaultTermsDays: max(draft.defaultTermsDays, 1),
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
        normalizedRecordStore.insert(record)
        try saveAndReloadNormalizedWorkspacePreservingActivity()
        guard let client = workspace.clients.first(where: { $0.id == record.id }) else {
            throw WorkspaceStoreError.persistenceFailed
        }
        appendActivity(message: "\(client.name) client created", detail: client.email, occurredAt: occurredAt)
        try persistWorkspace()
        return client
    }

    @discardableResult
    private func createOnboardingProject(
        _ draft: WorkspaceProjectDraft,
        occurredAt: Date
    ) throws -> WorkspaceProject {
        if isUsingNormalizedWorkspacePersistence() {
            return try createProjectInNormalizedRecords(draft, occurredAt: occurredAt)
        }
        return try createProject(draft, occurredAt: occurredAt)
    }
}
