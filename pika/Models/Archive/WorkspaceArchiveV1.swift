import Foundation

enum WorkspaceArchiveError: Error, Equatable {
    case invalidFormatMarker(expected: String, found: String)
    case unsupportedVersion(expected: Int, found: Int)
    case invalidExportedAt(String)
    case invalidDate(field: String, value: String)
    case decodingFailed(String)
}

struct WorkspaceArchiveEnvelope: Equatable {
    static let formatMarker = "pika.workspace-archive"
    static let supportedVersion = 1

    let format: String
    let version: Int
    let exportedAt: Date
    let generator: WorkspaceArchiveGenerator?
    let workspace: WorkspaceArchiveV1Workspace

    static func v1(
        exportedAt: Date,
        generator: WorkspaceArchiveGenerator?,
        workspace: WorkspaceArchiveV1Workspace
    ) -> WorkspaceArchiveEnvelope {
        WorkspaceArchiveEnvelope(
            format: formatMarker,
            version: supportedVersion,
            exportedAt: exportedAt,
            generator: generator,
            workspace: workspace
        )
    }

    fileprivate init(
        format: String,
        version: Int,
        exportedAt: Date,
        generator: WorkspaceArchiveGenerator?,
        workspace: WorkspaceArchiveV1Workspace
    ) {
        self.format = format
        self.version = version
        self.exportedAt = exportedAt
        self.generator = generator
        self.workspace = workspace
    }
}

struct WorkspaceArchiveGenerator: Codable, Equatable {
    var app: String
    var version: String
    var build: String
}

struct WorkspaceArchiveV1Workspace: Codable, Equatable {
    var businessProfile: BusinessProfile
    var clients: [Client]
    var projects: [Project]
    var buckets: [Bucket]
    var timeEntries: [TimeEntry]
    var fixedCosts: [FixedCost]
    var invoices: [Invoice]
    var invoiceLineItems: [InvoiceLineItem]

    struct BusinessProfile: Codable, Equatable {
        var businessName: String
        var personName: String
        var email: String
        var phone: String
        var address: String
        var taxIdentifier: String
        var economicIdentifier: String
        var invoicePrefix: String
        var nextInvoiceNumber: Int
        var currencyCode: String
        var paymentDetails: String
        var taxNote: String
        var defaultTermsDays: Int
    }

    struct Client: Codable, Equatable {
        var id: UUID
        var name: String
        var email: String
        var billingAddress: String
        var defaultTermsDays: Int
        var isArchived: Bool
    }

    struct Project: Codable, Equatable {
        var id: UUID
        var clientID: UUID
        var name: String
        var currencyCode: String
        var isArchived: Bool
    }

    struct Bucket: Codable, Equatable {
        var id: UUID
        var projectID: UUID
        var name: String
        var status: WorkspaceArchiveBucketStatus
        var defaultHourlyRateMinorUnits: Int
    }

    struct TimeEntry: Codable, Equatable {
        var id: UUID
        var bucketID: UUID
        var date: String
        var startMinuteOfDay: Int?
        var endMinuteOfDay: Int?
        var durationMinutes: Int
        var description: String
        var isBillable: Bool
        var hourlyRateMinorUnits: Int
    }

    struct FixedCost: Codable, Equatable {
        var id: UUID
        var bucketID: UUID
        var date: String
        var description: String
        var amountMinorUnits: Int
    }

    struct Invoice: Codable, Equatable {
        var id: UUID
        var projectID: UUID
        var bucketID: UUID
        var number: String
        var businessSnapshot: BusinessSnapshot
        var clientSnapshot: ClientSnapshot
        var template: String
        var issueDate: String
        var dueDate: String
        var servicePeriod: String
        var status: WorkspaceArchiveInvoiceStatus
        var totalMinorUnits: Int
        var currencyCode: String
        var note: String?
    }

    struct BusinessSnapshot: Codable, Equatable {
        var businessName: String
        var personName: String
        var email: String
        var phone: String
        var address: String
        var taxIdentifier: String
        var economicIdentifier: String
        var paymentDetails: String
        var taxNote: String
    }

    struct ClientSnapshot: Codable, Equatable {
        var name: String
        var email: String
        var billingAddress: String
    }

    struct InvoiceLineItem: Codable, Equatable {
        var id: UUID
        var invoiceID: UUID
        var sortOrder: Int
        var description: String
        var quantityLabel: String
        var amountMinorUnits: Int
    }

    fileprivate func validateDateFields() throws {
        for entry in timeEntries {
            try WorkspaceArchiveDateCoding.validateDateOnly(entry.date, field: "workspace.timeEntries.date")
        }

        for fixedCost in fixedCosts {
            try WorkspaceArchiveDateCoding.validateDateOnly(fixedCost.date, field: "workspace.fixedCosts.date")
        }

        for invoice in invoices {
            try WorkspaceArchiveDateCoding.validateDateOnly(invoice.issueDate, field: "workspace.invoices.issueDate")
            try WorkspaceArchiveDateCoding.validateDateOnly(invoice.dueDate, field: "workspace.invoices.dueDate")
        }
    }
}

enum WorkspaceArchiveBucketStatus: String, Codable, Equatable, CaseIterable {
    case open
    case ready
    case finalized
    case archived
}

enum WorkspaceArchiveInvoiceStatus: String, Codable, Equatable, CaseIterable {
    case finalized
    case sent
    case paid
    case cancelled
}

enum WorkspaceArchiveCodec {
    private struct EnvelopeHeader: Codable {
        var format: String
        var version: Int
    }

    private struct RawEnvelope: Codable, Equatable {
        var format: String
        var version: Int
        var exportedAt: String
        var generator: WorkspaceArchiveGenerator?
        var workspace: WorkspaceArchiveV1Workspace
    }

    static func encode(_ archive: WorkspaceArchiveEnvelope) throws -> Data {
        try archive.workspace.validateDateFields()

        let rawEnvelope = RawEnvelope(
            format: archive.format,
            version: archive.version,
            exportedAt: WorkspaceArchiveDateCoding.timestampString(from: archive.exportedAt),
            generator: archive.generator,
            workspace: archive.workspace
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(rawEnvelope)
    }

    static func decode(_ data: Data) throws -> WorkspaceArchiveEnvelope {
        let decoder = JSONDecoder()

        do {
            let header = try decoder.decode(EnvelopeHeader.self, from: data)

            guard header.format == WorkspaceArchiveEnvelope.formatMarker else {
                throw WorkspaceArchiveError.invalidFormatMarker(
                    expected: WorkspaceArchiveEnvelope.formatMarker,
                    found: header.format
                )
            }

            guard header.version == WorkspaceArchiveEnvelope.supportedVersion else {
                throw WorkspaceArchiveError.unsupportedVersion(
                    expected: WorkspaceArchiveEnvelope.supportedVersion,
                    found: header.version
                )
            }

            let rawEnvelope = try decoder.decode(RawEnvelope.self, from: data)
            guard let exportedAt = WorkspaceArchiveDateCoding.date(fromTimestamp: rawEnvelope.exportedAt) else {
                throw WorkspaceArchiveError.invalidExportedAt(rawEnvelope.exportedAt)
            }

            try rawEnvelope.workspace.validateDateFields()

            return WorkspaceArchiveEnvelope(
                format: rawEnvelope.format,
                version: rawEnvelope.version,
                exportedAt: exportedAt,
                generator: rawEnvelope.generator,
                workspace: rawEnvelope.workspace
            )
        } catch let error as WorkspaceArchiveError {
            throw error
        } catch {
            throw WorkspaceArchiveError.decodingFailed(String(describing: error))
        }
    }
}

private enum WorkspaceArchiveDateCoding {
    static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func date(fromTimestamp timestamp: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }

    static func validateDateOnly(_ value: String, field: String) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false

        guard
            let date = formatter.date(from: value),
            formatter.string(from: date) == value
        else {
            throw WorkspaceArchiveError.invalidDate(field: field, value: value)
        }
    }
}
