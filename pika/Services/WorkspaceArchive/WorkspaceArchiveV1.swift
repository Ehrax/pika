import Foundation

enum WorkspaceArchiveError: Error, Equatable {
    case unsupportedFormat(String)
    case unsupportedVersion(Int)
}

struct WorkspaceArchiveEnvelope: Codable, Equatable {
    static let v1Format = "pika.workspace.archive"
    static let v1Version = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var generator: WorkspaceArchiveGenerator?
    var workspace: WorkspaceArchiveWorkspace

    func validate() throws {
        guard format == Self.v1Format else {
            throw WorkspaceArchiveError.unsupportedFormat(format)
        }

        guard version == Self.v1Version else {
            throw WorkspaceArchiveError.unsupportedVersion(version)
        }
    }
}

struct WorkspaceArchiveGenerator: Codable, Equatable {
    var name: String
    var version: String
}

struct WorkspaceArchiveWorkspace: Codable, Equatable {
    var businessProfile: WorkspaceArchiveBusinessProfile
    var clients: [WorkspaceArchiveClient]
    var projects: [WorkspaceArchiveProject]
    var buckets: [WorkspaceArchiveBucket]
    var timeEntries: [WorkspaceArchiveTimeEntry]
    var fixedCosts: [WorkspaceArchiveFixedCost]
    var invoices: [WorkspaceArchiveInvoice]
    var invoiceLineItems: [WorkspaceArchiveInvoiceLineItem]
}

struct WorkspaceArchiveBusinessProfile: Codable, Equatable {
    var id: UUID
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

struct WorkspaceArchiveClient: Codable, Equatable {
    var id: UUID
    var name: String
    var email: String
    var billingAddress: String
    var defaultTermsDays: Int
    var isArchived: Bool
}

struct WorkspaceArchiveProject: Codable, Equatable {
    var id: UUID
    var clientID: UUID
    var name: String
    var currencyCode: String
    var isArchived: Bool
}

struct WorkspaceArchiveBucket: Codable, Equatable {
    var id: UUID
    var projectID: UUID
    var name: String
    var status: BucketStatus
    var defaultHourlyRateMinorUnits: Int
}

struct WorkspaceArchiveTimeEntry: Codable, Equatable {
    var id: UUID
    var bucketID: UUID
    var workDate: Date
    var startMinuteOfDay: Int?
    var endMinuteOfDay: Int?
    var durationMinutes: Int
    var description: String
    var isBillable: Bool
    var hourlyRateMinorUnits: Int
}

struct WorkspaceArchiveFixedCost: Codable, Equatable {
    var id: UUID
    var bucketID: UUID
    var date: Date
    var description: String
    var quantity: Int
    var unitPriceMinorUnits: Int
    var isBillable: Bool
}

struct WorkspaceArchiveInvoice: Codable, Equatable {
    var id: UUID
    var projectID: UUID
    var bucketID: UUID
    var number: String
    var template: InvoiceTemplate
    var issueDate: Date
    var dueDate: Date
    var servicePeriod: String
    var status: InvoiceStatus
    var totalMinorUnits: Int
    var currencyCode: String
    var note: String
    var businessProfileSnapshot: WorkspaceArchiveBusinessProfileSnapshot
    var clientSnapshot: WorkspaceArchiveClientSnapshot
    var projectSnapshot: WorkspaceArchiveProjectSnapshot
    var bucketSnapshot: WorkspaceArchiveBucketSnapshot
}

struct WorkspaceArchiveBusinessProfileSnapshot: Codable, Equatable {
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

struct WorkspaceArchiveClientSnapshot: Codable, Equatable {
    var name: String
    var email: String
    var billingAddress: String
}

struct WorkspaceArchiveProjectSnapshot: Codable, Equatable {
    var name: String
}

struct WorkspaceArchiveBucketSnapshot: Codable, Equatable {
    var name: String
}

struct WorkspaceArchiveInvoiceLineItem: Codable, Equatable {
    var id: UUID
    var invoiceID: UUID
    var sortOrder: Int
    var description: String
    var quantityLabel: String
    var amountMinorUnits: Int
}

enum WorkspaceArchiveCodec {
    static func encode(_ envelope: WorkspaceArchiveEnvelope) throws -> Data {
        try envelope.validate()
        return try encodeUnchecked(envelope)
    }

    static func encodeUnchecked(_ envelope: WorkspaceArchiveEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(envelope)
    }

    static func decode(_ data: Data) throws -> WorkspaceArchiveEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(WorkspaceArchiveEnvelope.self, from: data)
        try envelope.validate()
        return envelope
    }
}
