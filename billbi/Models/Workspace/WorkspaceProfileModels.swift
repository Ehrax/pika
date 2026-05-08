import Foundation

struct BusinessProfileProjection: Codable, Equatable {
    var businessName: String
    var personName: String
    var email: String
    var phone: String
    var address: String
    var taxIdentifier: String
    var economicIdentifier: String
    var countryCode: String
    var invoicePrefix: String
    var nextInvoiceNumber: Int
    var currencyCode: String
    var paymentDetails: String
    var taxNote: String
    var defaultTermsDays: Int
    var senderTaxLegalFields: [WorkspaceTaxLegalField]

    private enum CodingKeys: String, CodingKey {
        case businessName
        case personName
        case email
        case phone
        case address
        case taxIdentifier
        case economicIdentifier
        case countryCode
        case invoicePrefix
        case nextInvoiceNumber
        case currencyCode
        case paymentDetails
        case taxNote
        case defaultTermsDays
        case senderTaxLegalFields
    }

    init(
        businessName: String,
        personName: String = "",
        email: String,
        phone: String = "",
        address: String,
        taxIdentifier: String = "",
        economicIdentifier: String = "",
        countryCode: String = "",
        invoicePrefix: String,
        nextInvoiceNumber: Int,
        currencyCode: String,
        paymentDetails: String,
        taxNote: String,
        defaultTermsDays: Int,
        senderTaxLegalFields: [WorkspaceTaxLegalField] = []
    ) {
        self.businessName = businessName
        self.personName = personName
        self.email = email
        self.phone = phone
        self.address = address
        self.taxIdentifier = taxIdentifier
        self.economicIdentifier = economicIdentifier
        self.countryCode = countryCode
        self.invoicePrefix = invoicePrefix
        self.nextInvoiceNumber = nextInvoiceNumber
        self.currencyCode = currencyCode
        self.paymentDetails = paymentDetails
        self.taxNote = taxNote
        self.defaultTermsDays = defaultTermsDays
        self.senderTaxLegalFields = senderTaxLegalFields.isEmpty
            ? .migratedSenderFields(taxIdentifier: taxIdentifier, economicIdentifier: economicIdentifier)
            : senderTaxLegalFields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        businessName = try container.decode(String.self, forKey: .businessName)
        personName = try container.decodeIfPresent(String.self, forKey: .personName) ?? ""
        email = try container.decode(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        address = try container.decode(String.self, forKey: .address)
        taxIdentifier = try container.decodeIfPresent(String.self, forKey: .taxIdentifier) ?? ""
        economicIdentifier = try container.decodeIfPresent(String.self, forKey: .economicIdentifier) ?? ""
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode) ?? ""
        invoicePrefix = try container.decode(String.self, forKey: .invoicePrefix)
        nextInvoiceNumber = try container.decode(Int.self, forKey: .nextInvoiceNumber)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        paymentDetails = try container.decode(String.self, forKey: .paymentDetails)
        taxNote = try container.decode(String.self, forKey: .taxNote)
        defaultTermsDays = try container.decode(Int.self, forKey: .defaultTermsDays)
        let decodedSenderFields = try container.decodeIfPresent([WorkspaceTaxLegalField].self, forKey: .senderTaxLegalFields) ?? []
        senderTaxLegalFields = decodedSenderFields.isEmpty
            ? .migratedSenderFields(taxIdentifier: taxIdentifier, economicIdentifier: economicIdentifier)
            : decodedSenderFields
    }
}

struct WorkspaceClient: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var billingAddress: String
    var defaultTermsDays: Int
    var isArchived: Bool

    init(
        id: UUID,
        name: String,
        email: String,
        billingAddress: String,
        defaultTermsDays: Int,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.billingAddress = billingAddress
        self.defaultTermsDays = defaultTermsDays
        self.isArchived = isArchived
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case billingAddress
        case defaultTermsDays
        case isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        billingAddress = try container.decode(String.self, forKey: .billingAddress)
        defaultTermsDays = try container.decode(Int.self, forKey: .defaultTermsDays)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}
