import Foundation
import SwiftData

extension WorkspaceStore {
    func updateBusinessProfile(_ draft: WorkspaceBusinessProfileDraft) throws {
        let businessName = draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let personName = draft.personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxIdentifier = draft.taxIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let economicIdentifier = draft.economicIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryCode = draft.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let invoicePrefix = draft.invoicePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let paymentDetails = draft.paymentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxNote = draft.taxNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let senderTaxLegalFields = draft.senderTaxLegalFields
        let paymentMethods = draft.paymentMethods
        let defaultPaymentMethodID = draft.defaultPaymentMethodID
        guard !businessName.isEmpty,
              !email.isEmpty,
              !address.isEmpty,
              !invoicePrefix.isEmpty,
              !currencyCode.isEmpty,
              !paymentDetails.isEmpty,
              draft.nextInvoiceNumber > 0,
              draft.defaultTermsDays > 0
        else {
            throw WorkspaceStoreError.invalidBusinessProfile
        }

        let profile = BusinessProfileProjection(
            businessName: businessName,
            personName: personName,
            email: email,
            phone: phone,
            address: address,
            taxIdentifier: taxIdentifier,
            economicIdentifier: economicIdentifier,
            countryCode: countryCode,
            invoicePrefix: invoicePrefix.uppercased(),
            nextInvoiceNumber: draft.nextInvoiceNumber,
            currencyCode: currencyCode,
            paymentDetails: paymentDetails,
            paymentMethods: paymentMethods,
            defaultPaymentMethodID: defaultPaymentMethodID,
            taxNote: taxNote,
            defaultTermsDays: draft.defaultTermsDays,
            senderTaxLegalFields: senderTaxLegalFields
        )

        if isUsingNormalizedWorkspacePersistence() {
            try updateBusinessProfileInNormalizedRecords(with: profile)
            try clearOrphanedClientPaymentMethodReferences(validMethodIDs: Set(profile.paymentMethods.map(\.id)))
            try saveAndReloadNormalizedWorkspacePreservingActivity()
        } else {
            workspace.businessProfile = profile
            clearOrphanedClientPaymentMethodReferencesInSnapshot(validMethodIDs: Set(profile.paymentMethods.map(\.id)))
        }

        AppTelemetry.settingsSaved()
        try persistWorkspace()
    }

    private func clearOrphanedClientPaymentMethodReferencesInSnapshot(validMethodIDs: Set<UUID>) {
        for index in workspace.clients.indices {
            if let preferredID = workspace.clients[index].preferredPaymentMethodID,
               !validMethodIDs.contains(preferredID) {
                workspace.clients[index].preferredPaymentMethodID = nil
            }
        }
    }

    private func clearOrphanedClientPaymentMethodReferences(validMethodIDs: Set<UUID>) throws {
        let clientRecords = try normalizedRecordStore.fetch(FetchDescriptor<ClientRecord>())
        for record in clientRecords {
            guard let preferredID = UUID(uuidString: record.preferredPaymentMethodIDString),
                  !validMethodIDs.contains(preferredID) else {
                continue
            }
            record.preferredPaymentMethodIDString = ""
            record.updatedAt = Date.now
        }
    }
}
