import Foundation
import Testing
@testable import billbi

struct TaxLegalFieldMigrationTests {
    @Test func businessProfileProjectionMigratesLegacyTaxIdentifiersIntoSenderFields() throws {
        let json = """
        {
          \"businessName\": \"North Coast Studio\",
          \"personName\": \"Avery North\",
          \"email\": \"billing@northcoast.example\",
          \"phone\": \"+49 555 0100\",
          \"address\": \"1 Harbour Way\",
          \"taxIdentifier\": \"DE123456789\",
          \"economicIdentifier\": \"ECO-7788\",
          \"invoicePrefix\": \"NCS\",
          \"nextInvoiceNumber\": 42,
          \"currencyCode\": \"EUR\",
          \"paymentDetails\": \"IBAN DE001234\",
          \"taxNote\": \"VAT exempt\",
          \"defaultTermsDays\": 14
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(BusinessProfileProjection.self, from: json)

        #expect(profile.senderTaxLegalFields.count == 2)
        #expect(profile.senderTaxLegalFields.map(\.label) == ["Steuernummer", "Wirtschafts-IdNr"])
        #expect(profile.senderTaxLegalFields.map(\.value) == ["DE123456789", "ECO-7788"])
        #expect(profile.senderTaxLegalFields.allSatisfy { $0.placement == .senderDetails })
    }

    @Test func senderFieldMigrationSkipsEmptyLegacyValues() {
        let migrated = [WorkspaceTaxLegalField].migratedSenderFields(
            taxIdentifier: "   ",
            economicIdentifier: "ECO-7788"
        )

        #expect(migrated.count == 1)
        #expect(migrated[0].label == "Wirtschafts-IdNr")
        #expect(migrated[0].value == "ECO-7788")
    }
}
