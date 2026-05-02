import Foundation
import SwiftData

extension WorkspaceStore {
    func updateBusinessProfileRecord(with profile: BusinessProfileProjection) throws {
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
