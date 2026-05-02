import Foundation

extension WorkspaceStore {
    func updateBusinessProfile(_ draft: WorkspaceBusinessProfileDraft) throws {
        let businessName = draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let personName = draft.personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxIdentifier = draft.taxIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let economicIdentifier = draft.economicIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let invoicePrefix = draft.invoicePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyCode = CurrencyTextFormatting.normalizedInput(draft.currencyCode)
        let paymentDetails = draft.paymentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxNote = draft.taxNote.trimmingCharacters(in: .whitespacesAndNewlines)
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
            invoicePrefix: invoicePrefix.uppercased(),
            nextInvoiceNumber: draft.nextInvoiceNumber,
            currencyCode: currencyCode,
            paymentDetails: paymentDetails,
            taxNote: taxNote,
            defaultTermsDays: draft.defaultTermsDays
        )

        if isUsingNormalizedWorkspacePersistence() {
            try updateBusinessProfileInNormalizedRecords(with: profile)
            try saveAndReloadNormalizedWorkspacePreservingActivity()
        } else {
            workspace.businessProfile = profile
        }

        AppTelemetry.settingsSaved()
        try persistWorkspace()
    }
}
