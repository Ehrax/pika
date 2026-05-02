import Foundation
import Testing
@testable import pika

@MainActor
struct WorkspaceArchiveV1Tests {
    @Test func archiveV1RoundTripUsesPrettyJSONAndISO8601Dates() throws {
        let exportedAt = Date.pikaDate(year: 2026, month: 5, day: 2)
        let fixture = WorkspaceArchiveFixture.makeEnvelope(exportedAt: exportedAt)

        let encoded = try WorkspaceArchiveCodec.encode(fixture)
        let json = try #require(String(data: encoded, encoding: .utf8))

        #expect(json.contains("\n  \"format\""))
        #expect(json.contains("\"exportedAt\" : \"2026-05-02T00:00:00Z\""))
        #expect(json.contains("\"amountMinorUnits\" : 10000"))

        let decoded = try WorkspaceArchiveCodec.decode(encoded)
        #expect(decoded == fixture)
    }

    @Test func archiveV1DecodeRejectsUnsupportedFormatMarker() throws {
        let fixture = WorkspaceArchiveFixture.makeEnvelope(exportedAt: Date.pikaDate(year: 2026, month: 5, day: 2))
        var invalid = fixture
        invalid.format = "not.pika.archive"

        let encoded = try WorkspaceArchiveCodec.encodeUnchecked(invalid)
        #expect(throws: WorkspaceArchiveError.unsupportedFormat("not.pika.archive")) {
            _ = try WorkspaceArchiveCodec.decode(encoded)
        }
    }

    @Test func archiveV1DecodeRejectsUnsupportedVersion() throws {
        let fixture = WorkspaceArchiveFixture.makeEnvelope(exportedAt: Date.pikaDate(year: 2026, month: 5, day: 2))
        var invalid = fixture
        invalid.version = 2

        let encoded = try WorkspaceArchiveCodec.encodeUnchecked(invalid)
        #expect(throws: WorkspaceArchiveError.unsupportedVersion(2)) {
            _ = try WorkspaceArchiveCodec.decode(encoded)
        }
    }
}

private enum WorkspaceArchiveFixture {
    static func makeEnvelope(exportedAt: Date) -> WorkspaceArchiveEnvelope {
        let businessProfileID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let clientID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let projectID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let bucketID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let timeEntryID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
        let fixedCostID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
        let invoiceID = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
        let lineItemID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

        return WorkspaceArchiveEnvelope(
            format: WorkspaceArchiveEnvelope.v1Format,
            version: WorkspaceArchiveEnvelope.v1Version,
            exportedAt: exportedAt,
            generator: WorkspaceArchiveGenerator(name: "pika-tests", version: "1.0.0"),
            workspace: WorkspaceArchiveWorkspace(
                businessProfile: WorkspaceArchiveBusinessProfile(
                    id: businessProfileID,
                    businessName: "North Coast Studio",
                    personName: "Avery North",
                    email: "billing@northcoast.example",
                    phone: "+49 555 0100",
                    address: "1 Harbour Way",
                    taxIdentifier: "DE123",
                    economicIdentifier: "ECO123",
                    invoicePrefix: "NCS",
                    nextInvoiceNumber: 42,
                    currencyCode: "EUR",
                    paymentDetails: "IBAN DE00 1234",
                    taxNote: "VAT exempt",
                    defaultTermsDays: 14
                ),
                clients: [
                    WorkspaceArchiveClient(
                        id: clientID,
                        name: "Snapshot Client",
                        email: "billing@snapshot.example",
                        billingAddress: "1 Snapshot Way",
                        defaultTermsDays: 21,
                        isArchived: false
                    ),
                ],
                projects: [
                    WorkspaceArchiveProject(
                        id: projectID,
                        clientID: clientID,
                        name: "Snapshot Project",
                        currencyCode: "EUR",
                        isArchived: false
                    ),
                ],
                buckets: [
                    WorkspaceArchiveBucket(
                        id: bucketID,
                        projectID: projectID,
                        name: "Ready Snapshot",
                        status: .ready,
                        defaultHourlyRateMinorUnits: 10_000
                    ),
                ],
                timeEntries: [
                    WorkspaceArchiveTimeEntry(
                        id: timeEntryID,
                        bucketID: bucketID,
                        workDate: Date.pikaDate(year: 2026, month: 5, day: 1),
                        startMinuteOfDay: 540,
                        endMinuteOfDay: 600,
                        durationMinutes: 60,
                        description: "Billable work",
                        isBillable: true,
                        hourlyRateMinorUnits: 10_000
                    ),
                ],
                fixedCosts: [
                    WorkspaceArchiveFixedCost(
                        id: fixedCostID,
                        bucketID: bucketID,
                        date: Date.pikaDate(year: 2026, month: 5, day: 1),
                        description: "Design package",
                        quantity: 1,
                        unitPriceMinorUnits: 32_000,
                        isBillable: true
                    ),
                ],
                invoices: [
                    WorkspaceArchiveInvoice(
                        id: invoiceID,
                        projectID: projectID,
                        bucketID: bucketID,
                        number: "NCS-2026-042",
                        template: .kleinunternehmerClassic,
                        issueDate: Date.pikaDate(year: 2026, month: 5, day: 1),
                        dueDate: Date.pikaDate(year: 2026, month: 5, day: 15),
                        servicePeriod: "May 2026",
                        status: .finalized,
                        totalMinorUnits: 42_000,
                        currencyCode: "EUR",
                        note: "Thank you.",
                        businessProfileSnapshot: WorkspaceArchiveBusinessProfileSnapshot(
                            businessName: "North Coast Studio",
                            personName: "Avery North",
                            email: "billing@northcoast.example",
                            phone: "+49 555 0100",
                            address: "1 Harbour Way",
                            taxIdentifier: "DE123",
                            economicIdentifier: "ECO123",
                            paymentDetails: "IBAN DE00 1234",
                            taxNote: "VAT exempt"
                        ),
                        clientSnapshot: WorkspaceArchiveClientSnapshot(
                            name: "Snapshot Client",
                            email: "billing@snapshot.example",
                            billingAddress: "1 Snapshot Way"
                        ),
                        projectSnapshot: WorkspaceArchiveProjectSnapshot(
                            name: "Snapshot Project"
                        ),
                        bucketSnapshot: WorkspaceArchiveBucketSnapshot(
                            name: "Ready Snapshot"
                        )
                    ),
                ],
                invoiceLineItems: [
                    WorkspaceArchiveInvoiceLineItem(
                        id: lineItemID,
                        invoiceID: invoiceID,
                        sortOrder: 0,
                        description: "Ready Snapshot",
                        quantityLabel: "1h",
                        amountMinorUnits: 10_000
                    ),
                ]
            )
        )
    }
}
