import Foundation

struct WorkspaceInvoice: Codable, Equatable, Identifiable {
    let id: UUID
    var number: String
    var businessSnapshot: BusinessProfileProjection? = nil
    var clientSnapshot: WorkspaceClient? = nil
    var clientID: UUID? = nil
    var clientName: String
    var projectID: UUID? = nil
    var projectName: String = ""
    var bucketID: UUID? = nil
    var bucketName: String = ""
    var template: InvoiceTemplate = .kleinunternehmerClassic
    var issueDate: Date
    var dueDate: Date
    var servicePeriod: String = ""
    var status: InvoiceStatus
    var totalMinorUnits: Int
    var lineItems: [WorkspaceInvoiceLineItemSnapshot] = []
    var currencyCode: String = ""
    var note: String? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case businessSnapshot
        case clientSnapshot
        case clientID
        case clientName
        case projectID
        case projectName
        case bucketID
        case bucketName
        case template
        case issueDate
        case dueDate
        case servicePeriod
        case status
        case totalMinorUnits
        case lineItems
        case currencyCode
        case note
    }

    init(
        id: UUID,
        number: String,
        businessSnapshot: BusinessProfileProjection? = nil,
        clientSnapshot: WorkspaceClient? = nil,
        clientID: UUID? = nil,
        clientName: String,
        projectID: UUID? = nil,
        projectName: String = "",
        bucketID: UUID? = nil,
        bucketName: String = "",
        template: InvoiceTemplate = .kleinunternehmerClassic,
        issueDate: Date,
        dueDate: Date,
        servicePeriod: String = "",
        status: InvoiceStatus,
        totalMinorUnits: Int,
        lineItems: [WorkspaceInvoiceLineItemSnapshot] = [],
        currencyCode: String = "",
        note: String? = nil
    ) {
        self.id = id
        self.number = number
        self.businessSnapshot = businessSnapshot
        self.clientSnapshot = clientSnapshot
        self.clientID = clientID
        self.clientName = clientName
        self.projectID = projectID
        self.projectName = projectName
        self.bucketID = bucketID
        self.bucketName = bucketName
        self.template = template
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.servicePeriod = servicePeriod
        self.status = status
        self.totalMinorUnits = totalMinorUnits
        self.lineItems = lineItems
        self.currencyCode = currencyCode
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decode(String.self, forKey: .number)
        businessSnapshot = try container.decodeIfPresent(BusinessProfileProjection.self, forKey: .businessSnapshot)
        clientSnapshot = try container.decodeIfPresent(WorkspaceClient.self, forKey: .clientSnapshot)
        clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        clientName = try container.decode(String.self, forKey: .clientName)
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? ""
        bucketID = try container.decodeIfPresent(UUID.self, forKey: .bucketID)
        bucketName = try container.decodeIfPresent(String.self, forKey: .bucketName) ?? ""
        template = try container.decodeIfPresent(InvoiceTemplate.self, forKey: .template) ?? .kleinunternehmerClassic
        issueDate = try container.decode(Date.self, forKey: .issueDate)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        servicePeriod = try container.decodeIfPresent(String.self, forKey: .servicePeriod) ?? ""
        status = try container.decode(InvoiceStatus.self, forKey: .status)
        totalMinorUnits = try container.decode(Int.self, forKey: .totalMinorUnits)
        lineItems = try container.decodeIfPresent([WorkspaceInvoiceLineItemSnapshot].self, forKey: .lineItems) ?? []
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    func matches(
        projectID expectedProjectID: WorkspaceProject.ID,
        projectName expectedProjectName: String,
        bucketID expectedBucketID: WorkspaceBucket.ID,
        bucketName expectedBucketName: String
    ) -> Bool {
        let invoiceProjectName = projectName.isEmpty ? expectedProjectName : projectName
        let projectMatches = projectID == expectedProjectID || invoiceProjectName == expectedProjectName
        let bucketMatches = bucketID == expectedBucketID || bucketName == expectedBucketName
        return projectMatches && bucketMatches
    }
}

struct WorkspaceInvoiceLineItemSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    var description: String
    var quantityLabel: String
    var amountMinorUnits: Int

    init(
        id: UUID = UUID(),
        description: String,
        quantityLabel: String,
        amountMinorUnits: Int
    ) {
        self.id = id
        self.description = description
        self.quantityLabel = quantityLabel
        self.amountMinorUnits = amountMinorUnits
    }
}

struct WorkspaceActivity: Codable, Equatable, Identifiable {
    let id: UUID
    var message: String
    var detail: String
    var occurredAt: Date

    init(id: UUID = UUID(), message: String, detail: String, occurredAt: Date) {
        self.id = id
        self.message = message
        self.detail = detail
        self.occurredAt = occurredAt
    }
}

struct ProjectOverviewSummary: Equatable {
    var projectCount: Int
    var openMinorUnits: Int
    var readyMinorUnits: Int
    var overdueMinorUnits: Int
}
