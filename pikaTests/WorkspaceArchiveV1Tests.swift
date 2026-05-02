import Foundation
import Testing
@testable import pika

struct WorkspaceArchiveV1Tests {
    @Test func v1ArchiveEncodesAndDecodesRepresentativeWorkspace() throws {
        let exportedAt = try #require(isoTimestamp("2026-05-02T10:00:00Z"))
        let archive = WorkspaceArchiveEnvelope.v1(
            exportedAt: exportedAt,
            generator: WorkspaceArchiveGenerator(app: "Pika", version: "0.1.0", build: "27"),
            workspace: fixtureWorkspace()
        )

        let data = try WorkspaceArchiveCodec.encode(archive)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\n  \"format\""))
        #expect(json.contains("\"format\" : \"pika.workspace-archive\""))
        #expect(json.contains("\"version\" : 1"))
        #expect(json.contains("\"exportedAt\" : \"2026-05-02T10:00:00Z\""))
        #expect(json.contains("\"issueDate\" : \"2026-05-01\""))
        #expect(json.contains("\"totalMinorUnits\" : 52000"))

        let decoded = try WorkspaceArchiveCodec.decode(data)
        #expect(decoded.format == WorkspaceArchiveEnvelope.formatMarker)
        #expect(decoded.version == WorkspaceArchiveEnvelope.supportedVersion)
        #expect(decoded.generator?.app == "Pika")
        #expect(decoded.workspace.projects.first?.name == "Snapshot Project")
        #expect(decoded.workspace.invoices.first?.totalMinorUnits == 52_000)
    }

    @Test func decodeRejectsWrongFormatMarker() throws {
        let payload = """
        {
          "format" : "other.workspace-archive",
          "version" : 1,
          "exportedAt" : "2026-05-02T10:00:00Z",
          "workspace" : {
            "businessProfile" : {
              "businessName" : "North Coast Studio",
              "personName" : "Avery North",
              "email" : "billing@northcoast.example",
              "phone" : "+49 555 0100",
              "address" : "1 Harbour Way",
              "taxIdentifier" : "DE123",
              "economicIdentifier" : "ECO123",
              "invoicePrefix" : "NCS",
              "nextInvoiceNumber" : 42,
              "currencyCode" : "EUR",
              "paymentDetails" : "IBAN DE00 1234",
              "taxNote" : "VAT exempt",
              "defaultTermsDays" : 14
            },
            "clients" : [],
            "projects" : [],
            "buckets" : [],
            "timeEntries" : [],
            "fixedCosts" : [],
            "invoices" : [],
            "invoiceLineItems" : []
          }
        }
        """

        #expect(throws: WorkspaceArchiveError.invalidFormatMarker(
            expected: WorkspaceArchiveEnvelope.formatMarker,
            found: "other.workspace-archive"
        )) {
            _ = try WorkspaceArchiveCodec.decode(data(payload))
        }
    }

    @Test func decodeRejectsUnsupportedVersion() throws {
        let payload = """
        {
          "format" : "pika.workspace-archive",
          "version" : 2,
          "exportedAt" : "2026-05-02T10:00:00Z",
          "workspace" : {
            "businessProfile" : {
              "businessName" : "North Coast Studio",
              "personName" : "Avery North",
              "email" : "billing@northcoast.example",
              "phone" : "+49 555 0100",
              "address" : "1 Harbour Way",
              "taxIdentifier" : "DE123",
              "economicIdentifier" : "ECO123",
              "invoicePrefix" : "NCS",
              "nextInvoiceNumber" : 42,
              "currencyCode" : "EUR",
              "paymentDetails" : "IBAN DE00 1234",
              "taxNote" : "VAT exempt",
              "defaultTermsDays" : 14
            },
            "clients" : [],
            "projects" : [],
            "buckets" : [],
            "timeEntries" : [],
            "fixedCosts" : [],
            "invoices" : [],
            "invoiceLineItems" : []
          }
        }
        """

        #expect(throws: WorkspaceArchiveError.unsupportedVersion(
            expected: WorkspaceArchiveEnvelope.supportedVersion,
            found: 2
        )) {
            _ = try WorkspaceArchiveCodec.decode(data(payload))
        }
    }

    @Test func decodeRejectsInvalidDateOnlyField() throws {
        let payload = """
        {
          "format" : "pika.workspace-archive",
          "version" : 1,
          "exportedAt" : "2026-05-02T10:00:00Z",
          "workspace" : {
            "businessProfile" : {
              "businessName" : "North Coast Studio",
              "personName" : "Avery North",
              "email" : "billing@northcoast.example",
              "phone" : "+49 555 0100",
              "address" : "1 Harbour Way",
              "taxIdentifier" : "DE123",
              "economicIdentifier" : "ECO123",
              "invoicePrefix" : "NCS",
              "nextInvoiceNumber" : 42,
              "currencyCode" : "EUR",
              "paymentDetails" : "IBAN DE00 1234",
              "taxNote" : "VAT exempt",
              "defaultTermsDays" : 14
            },
            "clients" : [],
            "projects" : [],
            "buckets" : [],
            "timeEntries" : [],
            "fixedCosts" : [],
            "invoices" : [
              {
                "id" : "40000000-0000-0000-0000-000000000001",
                "projectID" : "20000000-0000-0000-0000-000000000001",
                "bucketID" : "30000000-0000-0000-0000-000000000001",
                "number" : "NCS-2026-042",
                "businessSnapshot" : {
                  "businessName" : "North Coast Studio",
                  "personName" : "Avery North",
                  "email" : "billing@northcoast.example",
                  "phone" : "+49 555 0100",
                  "address" : "1 Harbour Way",
                  "taxIdentifier" : "DE123",
                  "economicIdentifier" : "ECO123",
                  "paymentDetails" : "IBAN DE00 1234",
                  "taxNote" : "VAT exempt"
                },
                "clientSnapshot" : {
                  "name" : "Snapshot Client",
                  "email" : "billing@snapshot.example",
                  "billingAddress" : "1 Snapshot Way"
                },
                "template" : "kleinunternehmer-classic",
                "issueDate" : "2026-15-01",
                "dueDate" : "2026-05-15",
                "servicePeriod" : "May 2026",
                "status" : "finalized",
                "totalMinorUnits" : 52000,
                "currencyCode" : "EUR",
                "note" : "Thank you."
              }
            ],
            "invoiceLineItems" : []
          }
        }
        """

        #expect(throws: WorkspaceArchiveError.invalidDate(
            field: "workspace.invoices.issueDate",
            value: "2026-15-01"
        )) {
            _ = try WorkspaceArchiveCodec.decode(data(payload))
        }
    }

    private func fixtureWorkspace() -> WorkspaceArchiveV1Workspace {
        WorkspaceArchiveV1Workspace(
            businessProfile: .init(
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
                .init(
                    id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                    name: "Snapshot Client",
                    email: "billing@snapshot.example",
                    billingAddress: "1 Snapshot Way",
                    defaultTermsDays: 21,
                    isArchived: false
                ),
            ],
            projects: [
                .init(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                    clientID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                    name: "Snapshot Project",
                    currencyCode: "EUR",
                    isArchived: false
                ),
            ],
            buckets: [
                .init(
                    id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                    projectID: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                    name: "Ready Snapshot",
                    status: .ready,
                    defaultHourlyRateMinorUnits: 10_000
                ),
            ],
            timeEntries: [
                .init(
                    id: UUID(uuidString: "31000000-0000-0000-0000-000000000001")!,
                    bucketID: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                    date: "2026-05-01",
                    startMinuteOfDay: 540,
                    endMinuteOfDay: 660,
                    durationMinutes: 120,
                    description: "Billable work",
                    isBillable: true,
                    hourlyRateMinorUnits: 10_000
                ),
            ],
            fixedCosts: [
                .init(
                    id: UUID(uuidString: "32000000-0000-0000-0000-000000000001")!,
                    bucketID: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                    date: "2026-05-01",
                    description: "Design package",
                    amountMinorUnits: 32_000
                ),
            ],
            invoices: [
                .init(
                    id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                    projectID: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                    bucketID: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                    number: "NCS-2026-042",
                    businessSnapshot: .init(
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
                    clientSnapshot: .init(
                        name: "Snapshot Client",
                        email: "billing@snapshot.example",
                        billingAddress: "1 Snapshot Way"
                    ),
                    template: "kleinunternehmer-classic",
                    issueDate: "2026-05-01",
                    dueDate: "2026-05-15",
                    servicePeriod: "May 2026",
                    status: .finalized,
                    totalMinorUnits: 52_000,
                    currencyCode: "EUR",
                    note: "Thank you."
                ),
            ],
            invoiceLineItems: [
                .init(
                    id: UUID(uuidString: "41000000-0000-0000-0000-000000000001")!,
                    invoiceID: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                    sortOrder: 0,
                    description: "Ready Snapshot",
                    quantityLabel: "2h",
                    amountMinorUnits: 20_000
                ),
                .init(
                    id: UUID(uuidString: "41000000-0000-0000-0000-000000000002")!,
                    invoiceID: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                    sortOrder: 1,
                    description: "Design package",
                    quantityLabel: "1 item",
                    amountMinorUnits: 32_000
                ),
            ]
        )
    }

    private func isoTimestamp(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func data(_ payload: String) -> Data {
        Data(payload.utf8)
    }
}
