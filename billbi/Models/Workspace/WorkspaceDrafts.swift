import Foundation

struct InvoiceFinalizationDraft: Equatable {
    var recipientName: String
    var recipientEmail: String
    var recipientBillingAddress: String
    var invoiceNumber: String
    var template: InvoiceTemplate
    var issueDate: Date
    var dueDate: Date
    var servicePeriod: String
    var currencyCode: String
    var taxNote: String
}

enum InvoiceFinalizationField: CaseIterable, Equatable {
    case recipientName
    case recipientEmail
    case recipientBillingAddress
    case invoiceNumber
    case template
    case issueDate
    case dueDate
    case servicePeriod
    case currencyCode
    case taxNote

    var isEditable: Bool {
        switch self {
        case .template, .issueDate, .dueDate:
            true
        case .recipientName,
             .recipientEmail,
             .recipientBillingAddress,
             .invoiceNumber,
             .servicePeriod,
             .currencyCode,
             .taxNote:
            false
        }
    }

    static var editableFields: [Self] {
        allCases.filter(\.isEditable)
    }

    static var readOnlyFields: [Self] {
        allCases.filter { !$0.isEditable }
    }
}

struct WorkspaceTimeEntryDraft: Equatable {
    var date: Date
    var timeInput: String
    var description: String
    var isBillable: Bool
}

struct WorkspaceFixedCostDraft: Equatable {
    var date: Date
    var description: String
    var amountMinorUnits: Int
}

struct WorkspaceProjectDraft: Equatable {
    var name: String
    var clientID: WorkspaceClient.ID
    var currencyCode: String
    var firstBucketName: String
    var hourlyRateMinorUnits: Int
}

struct WorkspaceProjectUpdateDraft: Equatable {
    var name: String
    var clientID: WorkspaceClient.ID
    var currencyCode: String
}

struct WorkspaceBucketDraft: Equatable {
    var name: String
    var billingMode: WorkspaceBucketBillingMode = .hourly
    var hourlyRateMinorUnits: Int
    var fixedAmountMinorUnits: Int? = nil
    var retainerAmountMinorUnits: Int? = nil
    var retainerPeriodLabel: String = ""
    var retainerIncludedMinutes: Int? = nil
    var retainerOverageRateMinorUnits: Int? = nil
}

struct WorkspaceClientDraft: Equatable {
    var name: String
    var email: String
    var billingAddress: String
    var defaultTermsDays: Int
}

struct WorkspaceBusinessProfileDraft: Equatable {
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
    var paymentMethods: [WorkspacePaymentMethod]
    var defaultPaymentMethodID: UUID?
    var taxNote: String
    var defaultTermsDays: Int
    var senderTaxLegalFields: [WorkspaceTaxLegalField]

    init(
        businessName: String,
        personName: String = "",
        email: String,
        phone: String,
        address: String,
        taxIdentifier: String,
        economicIdentifier: String = "",
        countryCode: String = "",
        invoicePrefix: String,
        nextInvoiceNumber: Int,
        currencyCode: String,
        paymentDetails: String,
        paymentMethods: [WorkspacePaymentMethod] = [],
        defaultPaymentMethodID: UUID? = nil,
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
        self.paymentMethods = paymentMethods
        self.defaultPaymentMethodID = defaultPaymentMethodID
        self.taxNote = taxNote
        self.defaultTermsDays = defaultTermsDays
        self.senderTaxLegalFields = senderTaxLegalFields
    }

    init(profile: BusinessProfileProjection) {
        self.init(
            businessName: profile.businessName,
            personName: profile.personName,
            email: profile.email,
            phone: profile.phone,
            address: profile.address,
            taxIdentifier: profile.taxIdentifier,
            economicIdentifier: profile.economicIdentifier,
            countryCode: profile.countryCode,
            invoicePrefix: profile.invoicePrefix,
            nextInvoiceNumber: profile.nextInvoiceNumber,
            currencyCode: profile.currencyCode,
            paymentDetails: profile.paymentDetails,
            paymentMethods: profile.paymentMethods,
            defaultPaymentMethodID: profile.defaultPaymentMethodID,
            taxNote: profile.taxNote,
            defaultTermsDays: profile.defaultTermsDays,
            senderTaxLegalFields: profile.senderTaxLegalFields
        )
    }
}
