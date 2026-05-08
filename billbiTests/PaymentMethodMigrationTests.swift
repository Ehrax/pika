import Foundation
import Testing
@testable import billbi

struct PaymentMethodMigrationTests {
    @Test func businessProfileProjectionMigratesLegacyIBANToSEPAPaymentMethod() throws {
        let json = """
        {
          \"businessName\": \"North Coast Studio\",
          \"personName\": \"Avery North\",
          \"email\": \"billing@northcoast.example\",
          \"phone\": \"+49 555 0100\",
          \"address\": \"1 Harbour Way\",
          \"invoicePrefix\": \"NCS\",
          \"nextInvoiceNumber\": 42,
          \"currencyCode\": \"EUR\",
          \"paymentDetails\": \"IBAN DE32 1001 1001 2141 1444 52\\nBIC NTSBDEB1XXX\",
          \"taxNote\": \"VAT exempt\",
          \"defaultTermsDays\": 14
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(BusinessProfileProjection.self, from: json)
        let method = try #require(profile.defaultPaymentMethod)

        #expect(method.type == .sepaBankTransfer)
        #expect(method.iban.contains("DE32"))
        #expect(profile.defaultPaymentMethodID == method.id)
    }

    @Test func businessProfileProjectionMigratesLegacyWithoutIBANToOtherMethod() throws {
        let profile = BusinessProfileProjection(
            businessName: "North Coast Studio",
            email: "billing@northcoast.example",
            address: "1 Harbour Way",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 42,
            currencyCode: "EUR",
            paymentDetails: "Please pay via agreed transfer instructions.",
            taxNote: "VAT exempt",
            defaultTermsDays: 14
        )

        let method = try #require(profile.defaultPaymentMethod)
        #expect(method.type == .other)
        #expect(method.printableInstructions == "Please pay via agreed transfer instructions.")
    }
}
