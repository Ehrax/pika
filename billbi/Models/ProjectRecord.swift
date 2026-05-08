import Foundation
import SwiftData

@Model
final class BusinessProfileRecord {
    var id: UUID = UUID()
    var businessName: String = ""
    var personName: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var taxIdentifier: String = ""
    var economicIdentifier: String = ""
    var senderTaxLegalFieldsData: String = ""
    var invoicePrefix: String = "INV"
    var nextInvoiceNumber: Int = 1
    var currencyCode: String = "EUR"
    var paymentDetails: String = ""
    var taxNote: String = ""
    var defaultTermsDays: Int = 14
    var onboardingCompleted: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        businessName: String = "",
        personName: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        taxIdentifier: String = "",
        economicIdentifier: String = "",
        senderTaxLegalFieldsData: String = "",
        invoicePrefix: String = "INV",
        nextInvoiceNumber: Int = 1,
        currencyCode: String = "EUR",
        paymentDetails: String = "",
        taxNote: String = "",
        defaultTermsDays: Int = 14,
        onboardingCompleted: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.businessName = businessName
        self.personName = personName
        self.email = email
        self.phone = phone
        self.address = address
        self.taxIdentifier = taxIdentifier
        self.economicIdentifier = economicIdentifier
        self.senderTaxLegalFieldsData = senderTaxLegalFieldsData
        self.invoicePrefix = invoicePrefix
        self.nextInvoiceNumber = nextInvoiceNumber
        self.currencyCode = currencyCode
        self.paymentDetails = paymentDetails
        self.taxNote = taxNote
        self.defaultTermsDays = defaultTermsDays
        self.onboardingCompleted = onboardingCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ClientRecord {
    var id: UUID = UUID()
    var name: String = ""
    var email: String = ""
    var billingAddress: String = ""
    var defaultTermsDays: Int = 14
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String = "",
        email: String = "",
        billingAddress: String = "",
        defaultTermsDays: Int = 14,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.billingAddress = billingAddress
        self.defaultTermsDays = defaultTermsDays
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ProjectRecord {
    var id: UUID = UUID()
    var clientID: UUID = UUID()
    var name: String = ""
    var currencyCode: String = "EUR"
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var client: ClientRecord? = nil

    init(
        id: UUID = UUID(),
        clientID: UUID,
        name: String = "",
        currencyCode: String = "EUR",
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        client: ClientRecord? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.name = name
        self.currencyCode = currencyCode
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.client = client
    }
}

@Model
final class BucketRecord {
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var name: String = ""
    var statusRaw: String = BucketStatus.open.rawValue
    var defaultHourlyRateMinorUnits: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var project: ProjectRecord? = nil

    var status: BucketStatus {
        get { BucketStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        projectID: UUID,
        name: String = "",
        statusRaw: String = BucketStatus.open.rawValue,
        defaultHourlyRateMinorUnits: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        project: ProjectRecord? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.statusRaw = statusRaw
        self.defaultHourlyRateMinorUnits = defaultHourlyRateMinorUnits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.project = project
    }
}

@Model
final class TimeEntryRecord {
    var id: UUID = UUID()
    var bucketID: UUID = UUID()
    var workDate: Date = Date()
    var startMinuteOfDay: Int?
    var endMinuteOfDay: Int?
    var durationMinutes: Int = 0
    var descriptionText: String = ""
    var isBillable: Bool = true
    var hourlyRateMinorUnits: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var bucket: BucketRecord? = nil

    init(
        id: UUID = UUID(),
        bucketID: UUID,
        workDate: Date = .now,
        startMinuteOfDay: Int? = nil,
        endMinuteOfDay: Int? = nil,
        durationMinutes: Int = 0,
        descriptionText: String = "",
        isBillable: Bool = true,
        hourlyRateMinorUnits: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        bucket: BucketRecord? = nil
    ) {
        self.id = id
        self.bucketID = bucketID
        self.workDate = workDate
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
        self.durationMinutes = durationMinutes
        self.descriptionText = descriptionText
        self.isBillable = isBillable
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.bucket = bucket
    }
}

@Model
final class FixedCostRecord {
    var id: UUID = UUID()
    var bucketID: UUID = UUID()
    var date: Date = Date()
    var descriptionText: String = ""
    var quantity: Int = 1
    var unitPriceMinorUnits: Int = 0
    var isBillable: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var bucket: BucketRecord? = nil

    init(
        id: UUID = UUID(),
        bucketID: UUID,
        date: Date = .now,
        descriptionText: String = "",
        quantity: Int = 1,
        unitPriceMinorUnits: Int = 0,
        isBillable: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        bucket: BucketRecord? = nil
    ) {
        self.id = id
        self.bucketID = bucketID
        self.date = date
        self.descriptionText = descriptionText
        self.quantity = quantity
        self.unitPriceMinorUnits = unitPriceMinorUnits
        self.isBillable = isBillable
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.bucket = bucket
    }
}

@Model
final class InvoiceRecord {
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var bucketID: UUID = UUID()
    var number: String = ""
    var templateRaw: String = InvoiceTemplate.kleinunternehmerClassic.rawValue
    var issueDate: Date = Date()
    var dueDate: Date = Date()
    var servicePeriod: String = ""
    var statusRaw: String = InvoiceStatus.finalized.rawValue
    var totalMinorUnits: Int = 0
    var currencyCode: String = "EUR"
    var note: String = ""
    var businessName: String = ""
    var businessPersonName: String = ""
    var businessEmail: String = ""
    var businessPhone: String = ""
    var businessAddress: String = ""
    var businessTaxIdentifier: String = ""
    var businessEconomicIdentifier: String = ""
    var businessPaymentDetails: String = ""
    var businessTaxNote: String = ""
    var clientName: String = ""
    var clientEmail: String = ""
    var clientBillingAddress: String = ""
    var projectName: String = ""
    var bucketName: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var project: ProjectRecord? = nil
    var bucket: BucketRecord? = nil

    var template: InvoiceTemplate {
        get { InvoiceTemplate(rawValue: templateRaw) ?? .kleinunternehmerClassic }
        set { templateRaw = newValue.rawValue }
    }

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .finalized }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        projectID: UUID,
        bucketID: UUID,
        number: String = "",
        templateRaw: String = InvoiceTemplate.kleinunternehmerClassic.rawValue,
        issueDate: Date = .now,
        dueDate: Date = .now,
        servicePeriod: String = "",
        statusRaw: String = InvoiceStatus.finalized.rawValue,
        totalMinorUnits: Int = 0,
        currencyCode: String = "EUR",
        note: String = "",
        businessName: String = "",
        businessPersonName: String = "",
        businessEmail: String = "",
        businessPhone: String = "",
        businessAddress: String = "",
        businessTaxIdentifier: String = "",
        businessEconomicIdentifier: String = "",
        businessPaymentDetails: String = "",
        businessTaxNote: String = "",
        clientName: String = "",
        clientEmail: String = "",
        clientBillingAddress: String = "",
        projectName: String = "",
        bucketName: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        project: ProjectRecord? = nil,
        bucket: BucketRecord? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.bucketID = bucketID
        self.number = number
        self.templateRaw = templateRaw
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.servicePeriod = servicePeriod
        self.statusRaw = statusRaw
        self.totalMinorUnits = totalMinorUnits
        self.currencyCode = currencyCode
        self.note = note
        self.businessName = businessName
        self.businessPersonName = businessPersonName
        self.businessEmail = businessEmail
        self.businessPhone = businessPhone
        self.businessAddress = businessAddress
        self.businessTaxIdentifier = businessTaxIdentifier
        self.businessEconomicIdentifier = businessEconomicIdentifier
        self.businessPaymentDetails = businessPaymentDetails
        self.businessTaxNote = businessTaxNote
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.clientBillingAddress = clientBillingAddress
        self.projectName = projectName
        self.bucketName = bucketName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.project = project
        self.bucket = bucket
    }
}

@Model
final class InvoiceLineItemRecord {
    var id: UUID = UUID()
    var invoiceID: UUID = UUID()
    var sortOrder: Int = 0
    var descriptionText: String = ""
    var quantityLabel: String = ""
    var amountMinorUnits: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var invoice: InvoiceRecord? = nil

    init(
        id: UUID = UUID(),
        invoiceID: UUID,
        sortOrder: Int = 0,
        descriptionText: String = "",
        quantityLabel: String = "",
        amountMinorUnits: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        invoice: InvoiceRecord? = nil
    ) {
        self.id = id
        self.invoiceID = invoiceID
        self.sortOrder = sortOrder
        self.descriptionText = descriptionText
        self.quantityLabel = quantityLabel
        self.amountMinorUnits = amountMinorUnits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.invoice = invoice
    }
}

enum BillbiPersistenceSchema {
    static func makeSchema() -> Schema {
        Schema([
            BusinessProfileRecord.self,
            ClientRecord.self,
            ProjectRecord.self,
            BucketRecord.self,
            TimeEntryRecord.self,
            FixedCostRecord.self,
            InvoiceRecord.self,
            InvoiceLineItemRecord.self,
        ])
    }
}
