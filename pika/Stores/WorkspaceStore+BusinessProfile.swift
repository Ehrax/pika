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
            try updateBusinessProfileRecord(with: profile)
            try saveAndReloadNormalizedWorkspacePreservingActivity()
        } else {
            workspace.businessProfile = profile
        }

        AppTelemetry.settingsSaved()
        try persistWorkspace()
    }

    private func updateBusinessProfileRecord(with profile: BusinessProfileProjection) throws {
        let now = Date.now
        let record = try latestBusinessProfileRecord() ?? makeBusinessProfileRecord(
            from: profile,
            createdAt: now
        )

        apply(profile, to: record, updatedAt: now)
    }

    private func makeBusinessProfileRecord(
        from profile: BusinessProfileProjection,
        createdAt: Date
    ) -> BusinessProfileRecord {
        let record = BusinessProfileRecord(
            businessName: profile.businessName,
            personName: profile.personName,
            email: profile.email,
            phone: profile.phone,
            address: profile.address,
            taxIdentifier: profile.taxIdentifier,
            economicIdentifier: profile.economicIdentifier,
            invoicePrefix: profile.invoicePrefix,
            nextInvoiceNumber: profile.nextInvoiceNumber,
            currencyCode: profile.currencyCode,
            paymentDetails: profile.paymentDetails,
            taxNote: profile.taxNote,
            defaultTermsDays: profile.defaultTermsDays,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        modelContext.insert(record)
        return record
    }

    private func apply(
        _ profile: BusinessProfileProjection,
        to record: BusinessProfileRecord,
        updatedAt: Date
    ) {
        record.businessName = profile.businessName
        record.personName = profile.personName
        record.email = profile.email
        record.phone = profile.phone
        record.address = profile.address
        record.taxIdentifier = profile.taxIdentifier
        record.economicIdentifier = profile.economicIdentifier
        record.invoicePrefix = profile.invoicePrefix
        record.nextInvoiceNumber = profile.nextInvoiceNumber
        record.currencyCode = profile.currencyCode
        record.paymentDetails = profile.paymentDetails
        record.taxNote = profile.taxNote
        record.defaultTermsDays = profile.defaultTermsDays
        record.updatedAt = updatedAt
    }

    private func latestBusinessProfileRecord() throws -> BusinessProfileRecord? {
        let records = try modelContext.fetch(FetchDescriptor<BusinessProfileRecord>())
        return records.max {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt < $1.updatedAt
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
