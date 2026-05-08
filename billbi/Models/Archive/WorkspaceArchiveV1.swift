import Foundation

enum WorkspaceArchiveError: Error, Equatable {
    case invalidFormatMarker(expected: String, found: String)
    case unsupportedVersion(expected: Int, found: Int)
    case invalidExportedAt(String)
    case invalidDate(field: String, value: String)
    case unknownField(String)
    case decodingFailed(String)
}

struct WorkspaceArchiveEnvelope: Equatable {
    static let formatMarker = "billbi.workspace-archive"
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
    var onboardingCompleted: Bool
    var businessProfile: BusinessProfile
    var clients: [Client]
    var projects: [Project]
    var buckets: [Bucket]
    var timeEntries: [TimeEntry]
    var fixedCosts: [FixedCost]
    var invoices: [Invoice]
    var invoiceLineItems: [InvoiceLineItem]

    init(
        onboardingCompleted: Bool = false,
        businessProfile: BusinessProfile,
        clients: [Client],
        projects: [Project],
        buckets: [Bucket],
        timeEntries: [TimeEntry],
        fixedCosts: [FixedCost],
        invoices: [Invoice],
        invoiceLineItems: [InvoiceLineItem]
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.businessProfile = businessProfile
        self.clients = clients
        self.projects = projects
        self.buckets = buckets
        self.timeEntries = timeEntries
        self.fixedCosts = fixedCosts
        self.invoices = invoices
        self.invoiceLineItems = invoiceLineItems
    }

    private enum CodingKeys: String, CodingKey {
        case onboardingCompleted
        case businessProfile
        case clients
        case projects
        case buckets
        case timeEntries
        case fixedCosts
        case invoices
        case invoiceLineItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        businessProfile = try container.decode(BusinessProfile.self, forKey: .businessProfile)
        clients = try container.decode([Client].self, forKey: .clients)
        projects = try container.decode([Project].self, forKey: .projects)
        buckets = try container.decode([Bucket].self, forKey: .buckets)
        timeEntries = try container.decode([TimeEntry].self, forKey: .timeEntries)
        fixedCosts = try container.decode([FixedCost].self, forKey: .fixedCosts)
        invoices = try container.decode([Invoice].self, forKey: .invoices)
        invoiceLineItems = try container.decode([InvoiceLineItem].self, forKey: .invoiceLineItems)
    }

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
        var senderTaxLegalFields: [WorkspaceTaxLegalField] = []
        var paymentMethods: [WorkspacePaymentMethod] = []
        var defaultPaymentMethodID: UUID? = nil
        var taxNote: String
        var defaultTermsDays: Int

        private enum CodingKeys: String, CodingKey {
            case businessName
            case personName
            case email
            case phone
            case address
            case taxIdentifier
            case economicIdentifier
            case invoicePrefix
            case nextInvoiceNumber
            case currencyCode
            case paymentDetails
            case senderTaxLegalFields
            case paymentMethods
            case defaultPaymentMethodID
            case taxNote
            case defaultTermsDays
        }

        init(
            businessName: String,
            personName: String,
            email: String,
            phone: String,
            address: String,
            taxIdentifier: String,
            economicIdentifier: String,
            invoicePrefix: String,
            nextInvoiceNumber: Int,
            currencyCode: String,
            paymentDetails: String,
            senderTaxLegalFields: [WorkspaceTaxLegalField] = [],
            paymentMethods: [WorkspacePaymentMethod] = [],
            defaultPaymentMethodID: UUID? = nil,
            taxNote: String,
            defaultTermsDays: Int
        ) {
            self.businessName = businessName
            self.personName = personName
            self.email = email
            self.phone = phone
            self.address = address
            self.taxIdentifier = taxIdentifier
            self.economicIdentifier = economicIdentifier
            self.invoicePrefix = invoicePrefix
            self.nextInvoiceNumber = nextInvoiceNumber
            self.currencyCode = currencyCode
            self.paymentDetails = paymentDetails
            self.senderTaxLegalFields = senderTaxLegalFields
            self.paymentMethods = paymentMethods
            self.defaultPaymentMethodID = defaultPaymentMethodID
            self.taxNote = taxNote
            self.defaultTermsDays = defaultTermsDays
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            businessName = try container.decode(String.self, forKey: .businessName)
            personName = try container.decode(String.self, forKey: .personName)
            email = try container.decode(String.self, forKey: .email)
            phone = try container.decode(String.self, forKey: .phone)
            address = try container.decode(String.self, forKey: .address)
            taxIdentifier = try container.decode(String.self, forKey: .taxIdentifier)
            economicIdentifier = try container.decode(String.self, forKey: .economicIdentifier)
            invoicePrefix = try container.decode(String.self, forKey: .invoicePrefix)
            nextInvoiceNumber = try container.decode(Int.self, forKey: .nextInvoiceNumber)
            currencyCode = try container.decode(String.self, forKey: .currencyCode)
            paymentDetails = try container.decode(String.self, forKey: .paymentDetails)
            senderTaxLegalFields = try container.decodeIfPresent([WorkspaceTaxLegalField].self, forKey: .senderTaxLegalFields) ?? []
            paymentMethods = try container.decodeIfPresent([WorkspacePaymentMethod].self, forKey: .paymentMethods) ?? []
            defaultPaymentMethodID = try container.decodeIfPresent(UUID.self, forKey: .defaultPaymentMethodID)
            taxNote = try container.decode(String.self, forKey: .taxNote)
            defaultTermsDays = try container.decode(Int.self, forKey: .defaultTermsDays)
        }
    }

    struct Client: Codable, Equatable {
        var id: UUID
        var name: String
        var email: String
        var billingAddress: String
        var defaultTermsDays: Int
        var preferredPaymentMethodID: UUID? = nil
        var isArchived: Bool
        var recipientTaxLegalFields: [WorkspaceTaxLegalField] = []

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case email
            case billingAddress
            case defaultTermsDays
            case preferredPaymentMethodID
            case isArchived
            case recipientTaxLegalFields
        }

        init(
            id: UUID,
            name: String,
            email: String,
            billingAddress: String,
            defaultTermsDays: Int,
            preferredPaymentMethodID: UUID? = nil,
            isArchived: Bool,
            recipientTaxLegalFields: [WorkspaceTaxLegalField] = []
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.billingAddress = billingAddress
            self.defaultTermsDays = defaultTermsDays
            self.preferredPaymentMethodID = preferredPaymentMethodID
            self.isArchived = isArchived
            self.recipientTaxLegalFields = recipientTaxLegalFields
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            email = try container.decode(String.self, forKey: .email)
            billingAddress = try container.decode(String.self, forKey: .billingAddress)
            defaultTermsDays = try container.decode(Int.self, forKey: .defaultTermsDays)
            preferredPaymentMethodID = try container.decodeIfPresent(UUID.self, forKey: .preferredPaymentMethodID)
            isArchived = try container.decode(Bool.self, forKey: .isArchived)
            recipientTaxLegalFields = try container.decodeIfPresent([WorkspaceTaxLegalField].self, forKey: .recipientTaxLegalFields) ?? []
        }
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
        var billingMode: WorkspaceBucketBillingMode
        var defaultHourlyRateMinorUnits: Int
        var fixedAmountMinorUnits: Int
        var retainerAmountMinorUnits: Int
        var retainerPeriodLabel: String
        var retainerIncludedMinutes: Int?
        var retainerOverageRateMinorUnits: Int

        init(
            id: UUID,
            projectID: UUID,
            name: String,
            status: WorkspaceArchiveBucketStatus,
            billingMode: WorkspaceBucketBillingMode = .hourly,
            defaultHourlyRateMinorUnits: Int,
            fixedAmountMinorUnits: Int = 0,
            retainerAmountMinorUnits: Int = 0,
            retainerPeriodLabel: String = "",
            retainerIncludedMinutes: Int? = nil,
            retainerOverageRateMinorUnits: Int = 0
        ) {
            self.id = id
            self.projectID = projectID
            self.name = name
            self.status = status
            self.billingMode = billingMode
            self.defaultHourlyRateMinorUnits = defaultHourlyRateMinorUnits
            self.fixedAmountMinorUnits = fixedAmountMinorUnits
            self.retainerAmountMinorUnits = retainerAmountMinorUnits
            self.retainerPeriodLabel = retainerPeriodLabel
            self.retainerIncludedMinutes = retainerIncludedMinutes
            self.retainerOverageRateMinorUnits = retainerOverageRateMinorUnits
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case projectID
            case name
            case status
            case billingMode
            case defaultHourlyRateMinorUnits
            case fixedAmountMinorUnits
            case retainerAmountMinorUnits
            case retainerPeriodLabel
            case retainerIncludedMinutes
            case retainerOverageRateMinorUnits
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            projectID = try container.decode(UUID.self, forKey: .projectID)
            name = try container.decode(String.self, forKey: .name)
            status = try container.decode(WorkspaceArchiveBucketStatus.self, forKey: .status)
            billingMode = try container.decodeIfPresent(WorkspaceBucketBillingMode.self, forKey: .billingMode) ?? .hourly
            defaultHourlyRateMinorUnits = try container.decode(Int.self, forKey: .defaultHourlyRateMinorUnits)
            fixedAmountMinorUnits = try container.decodeIfPresent(Int.self, forKey: .fixedAmountMinorUnits) ?? 0
            retainerAmountMinorUnits = try container.decodeIfPresent(Int.self, forKey: .retainerAmountMinorUnits) ?? 0
            retainerPeriodLabel = try container.decodeIfPresent(String.self, forKey: .retainerPeriodLabel) ?? ""
            retainerIncludedMinutes = try container.decodeIfPresent(Int.self, forKey: .retainerIncludedMinutes)
            retainerOverageRateMinorUnits = try container.decodeIfPresent(Int.self, forKey: .retainerOverageRateMinorUnits) ?? 0
        }
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
        var senderTaxLegalFields: [WorkspaceTaxLegalField] = []
        var selectedPaymentMethod: WorkspacePaymentMethod? = nil
        var taxNote: String

        private enum CodingKeys: String, CodingKey {
            case businessName
            case personName
            case email
            case phone
            case address
            case taxIdentifier
            case economicIdentifier
            case paymentDetails
            case senderTaxLegalFields
            case selectedPaymentMethod
            case taxNote
        }

        init(
            businessName: String,
            personName: String,
            email: String,
            phone: String,
            address: String,
            taxIdentifier: String,
            economicIdentifier: String,
            paymentDetails: String,
            senderTaxLegalFields: [WorkspaceTaxLegalField] = [],
            selectedPaymentMethod: WorkspacePaymentMethod? = nil,
            taxNote: String
        ) {
            self.businessName = businessName
            self.personName = personName
            self.email = email
            self.phone = phone
            self.address = address
            self.taxIdentifier = taxIdentifier
            self.economicIdentifier = economicIdentifier
            self.paymentDetails = paymentDetails
            self.senderTaxLegalFields = senderTaxLegalFields
            self.selectedPaymentMethod = selectedPaymentMethod
            self.taxNote = taxNote
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            businessName = try container.decode(String.self, forKey: .businessName)
            personName = try container.decode(String.self, forKey: .personName)
            email = try container.decode(String.self, forKey: .email)
            phone = try container.decode(String.self, forKey: .phone)
            address = try container.decode(String.self, forKey: .address)
            taxIdentifier = try container.decode(String.self, forKey: .taxIdentifier)
            economicIdentifier = try container.decode(String.self, forKey: .economicIdentifier)
            paymentDetails = try container.decode(String.self, forKey: .paymentDetails)
            senderTaxLegalFields = try container.decodeIfPresent([WorkspaceTaxLegalField].self, forKey: .senderTaxLegalFields) ?? []
            selectedPaymentMethod = try container.decodeIfPresent(WorkspacePaymentMethod.self, forKey: .selectedPaymentMethod)
            taxNote = try container.decode(String.self, forKey: .taxNote)
        }
    }

    struct ClientSnapshot: Codable, Equatable {
        var name: String
        var email: String
        var billingAddress: String
        var recipientTaxLegalFields: [WorkspaceTaxLegalField] = []

        private enum CodingKeys: String, CodingKey {
            case name
            case email
            case billingAddress
            case recipientTaxLegalFields
        }

        init(
            name: String,
            email: String,
            billingAddress: String,
            recipientTaxLegalFields: [WorkspaceTaxLegalField] = []
        ) {
            self.name = name
            self.email = email
            self.billingAddress = billingAddress
            self.recipientTaxLegalFields = recipientTaxLegalFields
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            email = try container.decode(String.self, forKey: .email)
            billingAddress = try container.decode(String.self, forKey: .billingAddress)
            recipientTaxLegalFields = try container.decodeIfPresent([WorkspaceTaxLegalField].self, forKey: .recipientTaxLegalFields) ?? []
        }
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
            try validateStrictSchemaKeys(in: data)
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

    private static func validateStrictSchemaKeys(in data: Data) throws {
        let rawObject = try JSONSerialization.jsonObject(with: data)
        guard let envelope = rawObject as? [String: Any] else {
            throw WorkspaceArchiveError.decodingFailed("Archive root must be an object.")
        }

        try ensureAllowedKeys(
            in: envelope,
            path: "archive",
            allowedKeys: ["format", "version", "exportedAt", "generator", "workspace"]
        )

        if let generator = envelope["generator"] as? [String: Any] {
            try ensureAllowedKeys(
                in: generator,
                path: "generator",
                allowedKeys: ["app", "version", "build"]
            )
        }

        guard let workspace = envelope["workspace"] as? [String: Any] else {
            return
        }

        try ensureAllowedKeys(
            in: workspace,
            path: "workspace",
            allowedKeys: [
                "businessProfile",
                "onboardingCompleted",
                "clients",
                "projects",
                "buckets",
                "timeEntries",
                "fixedCosts",
                "invoices",
                "invoiceLineItems",
            ]
        )

        if let businessProfile = workspace["businessProfile"] as? [String: Any] {
            try ensureAllowedKeys(
                in: businessProfile,
                path: "workspace.businessProfile",
                allowedKeys: [
                    "businessName",
                    "personName",
                    "email",
                    "phone",
                    "address",
                    "taxIdentifier",
                    "economicIdentifier",
                    "invoicePrefix",
                    "nextInvoiceNumber",
                    "currencyCode",
                    "paymentDetails",
                    "senderTaxLegalFields",
                    "paymentMethods",
                    "defaultPaymentMethodID",
                    "taxNote",
                    "defaultTermsDays",
                ]
            )
        }

        try validateArrayObjects(
            workspace["clients"],
            path: "workspace.clients",
            allowedKeys: [
                "id",
                "name",
                "email",
                "billingAddress",
                "defaultTermsDays",
                "preferredPaymentMethodID",
                "isArchived",
                "recipientTaxLegalFields",
            ]
        )
        try validateArrayObjects(
            workspace["projects"],
            path: "workspace.projects",
            allowedKeys: ["id", "clientID", "name", "currencyCode", "isArchived"]
        )
        try validateArrayObjects(
            workspace["buckets"],
            path: "workspace.buckets",
            allowedKeys: [
                "id",
                "projectID",
                "name",
                "status",
                "billingMode",
                "defaultHourlyRateMinorUnits",
                "fixedAmountMinorUnits",
                "retainerAmountMinorUnits",
                "retainerPeriodLabel",
                "retainerIncludedMinutes",
                "retainerOverageRateMinorUnits",
            ]
        )
        try validateArrayObjects(
            workspace["timeEntries"],
            path: "workspace.timeEntries",
            allowedKeys: [
                "id",
                "bucketID",
                "date",
                "startMinuteOfDay",
                "endMinuteOfDay",
                "durationMinutes",
                "description",
                "isBillable",
                "hourlyRateMinorUnits",
            ]
        )
        try validateArrayObjects(
            workspace["fixedCosts"],
            path: "workspace.fixedCosts",
            allowedKeys: ["id", "bucketID", "date", "description", "amountMinorUnits"]
        )
        try validateInvoices(workspace["invoices"])
        try validateArrayObjects(
            workspace["invoiceLineItems"],
            path: "workspace.invoiceLineItems",
            allowedKeys: ["id", "invoiceID", "sortOrder", "description", "quantityLabel", "amountMinorUnits"]
        )
    }

    private static func validateInvoices(_ value: Any?) throws {
        guard let invoices = value as? [Any] else {
            return
        }

        for (index, element) in invoices.enumerated() {
            guard let invoice = element as? [String: Any] else {
                continue
            }

            let path = "workspace.invoices[\(index)]"
            try ensureAllowedKeys(
                in: invoice,
                path: path,
                allowedKeys: [
                    "id",
                    "projectID",
                    "bucketID",
                    "number",
                    "businessSnapshot",
                    "clientSnapshot",
                    "template",
                    "issueDate",
                    "dueDate",
                    "servicePeriod",
                    "status",
                    "totalMinorUnits",
                    "currencyCode",
                    "note",
                ]
            )

            if let businessSnapshot = invoice["businessSnapshot"] as? [String: Any] {
                try ensureAllowedKeys(
                    in: businessSnapshot,
                    path: "\(path).businessSnapshot",
                    allowedKeys: [
                        "businessName",
                        "personName",
                        "email",
                        "phone",
                        "address",
                        "taxIdentifier",
                        "economicIdentifier",
                        "paymentDetails",
                        "senderTaxLegalFields",
                        "selectedPaymentMethod",
                        "taxNote",
                    ]
                )
            }

            if let clientSnapshot = invoice["clientSnapshot"] as? [String: Any] {
                try ensureAllowedKeys(
                    in: clientSnapshot,
                    path: "\(path).clientSnapshot",
                    allowedKeys: ["name", "email", "billingAddress", "recipientTaxLegalFields"]
                )
            }
        }
    }

    private static func validateArrayObjects(
        _ value: Any?,
        path: String,
        allowedKeys: Set<String>
    ) throws {
        guard let elements = value as? [Any] else {
            return
        }

        for (index, element) in elements.enumerated() {
            guard let object = element as? [String: Any] else {
                continue
            }

            try ensureAllowedKeys(
                in: object,
                path: "\(path)[\(index)]",
                allowedKeys: allowedKeys
            )
        }
    }

    private static func ensureAllowedKeys(
        in object: [String: Any],
        path: String,
        allowedKeys: Set<String>
    ) throws {
        for key in object.keys where !allowedKeys.contains(key) {
            throw WorkspaceArchiveError.unknownField("\(path).\(key)")
        }
    }
}

enum WorkspaceArchiveDateCoding {
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

    static func dateOnlyString(from date: Date) -> String {
        dateOnlyFormatter().string(from: date)
    }

    static func date(fromDateOnly value: String) -> Date? {
        let formatter = dateOnlyFormatter()
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            return nil
        }
        return date
    }

    static func validateDateOnly(_ value: String, field: String) throws {
        guard date(fromDateOnly: value) != nil else {
            throw WorkspaceArchiveError.invalidDate(field: field, value: value)
        }
    }

    private static func dateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
}
