import Foundation

enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome
    case business
    case client
    case project
    case ready

    var displayIndex: Int { rawValue + 1 }
}

enum OnboardingSummaryCard: Equatable {
    case business
    case client
    case project
    case bucket
}

enum OnboardingPrimaryCTA: Equatable {
    case dashboard
    case project(projectID: WorkspaceProject.ID, bucketID: WorkspaceBucket.ID)
}

struct OnboardingBusinessDraft: Equatable {
    var businessName: String = ""
    var personName: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var taxIdentifier: String = ""
    var website: String = ""
    var currencyCode: String = "EUR"
    var defaultHourlyRateMinorUnits: Int = 8_000
    var paymentTerms: String = ""
    var paymentDetails: String = ""
    var defaultTermsDays: Int = 14

    init(
        businessName: String = "",
        personName: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        taxIdentifier: String = "",
        website: String = "",
        currencyCode: String = "EUR",
        defaultHourlyRateMinorUnits: Int = 8_000,
        paymentTerms: String = "",
        paymentDetails: String = "",
        defaultTermsDays: Int = 14
    ) {
        self.businessName = businessName
        self.personName = personName
        self.email = email
        self.phone = phone
        self.address = address
        self.taxIdentifier = taxIdentifier
        self.website = website
        self.currencyCode = currencyCode
        self.defaultHourlyRateMinorUnits = defaultHourlyRateMinorUnits
        self.paymentTerms = paymentTerms
        self.paymentDetails = paymentDetails
        self.defaultTermsDays = defaultTermsDays
    }

    init(profile: BusinessProfileProjection) {
        self.init(
            businessName: profile.businessName,
            personName: profile.personName,
            email: profile.email,
            phone: profile.phone,
            address: profile.address,
            taxIdentifier: profile.taxIdentifier,
            currencyCode: profile.currencyCode,
            paymentDetails: profile.paymentDetails,
            defaultTermsDays: profile.defaultTermsDays
        )
    }
}

struct OnboardingClientDraft: Equatable {
    var name: String = ""
    var email: String = ""
    var billingAddress: String = ""
    var contactPerson: String = ""
    var phone: String = ""
    var vatNumber: String = ""
    var rateOverrideMinorUnits: Int?

    init(
        name: String = "",
        email: String = "",
        billingAddress: String = "",
        contactPerson: String = "",
        phone: String = "",
        vatNumber: String = "",
        rateOverrideMinorUnits: Int? = nil
    ) {
        self.name = name
        self.email = email
        self.billingAddress = billingAddress
        self.contactPerson = contactPerson
        self.phone = phone
        self.vatNumber = vatNumber
        self.rateOverrideMinorUnits = rateOverrideMinorUnits
    }
}

struct OnboardingProjectDraft: Equatable {
    var name: String = ""
    var clientID: WorkspaceClient.ID?
    var currencyCode: String = ""
    var firstBucketName: String = ""
    var hourlyRateMinorUnits: Int = 8_000

    init(
        name: String = "",
        clientID: WorkspaceClient.ID? = nil,
        currencyCode: String = "",
        firstBucketName: String = "",
        hourlyRateMinorUnits: Int = 8_000
    ) {
        self.name = name
        self.clientID = clientID
        self.currencyCode = currencyCode
        self.firstBucketName = firstBucketName
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
    }
}

struct OnboardingFlowModel: Equatable {
    var step: OnboardingStep = .welcome

    mutating func advance() {
        guard let nextStep = OnboardingStep(rawValue: step.rawValue + 1) else {
            return
        }
        step = nextStep
    }

    mutating func back() {
        guard let previousStep = OnboardingStep(rawValue: step.rawValue - 1) else {
            return
        }
        step = previousStep
    }

    static func summaryCards(for workspace: WorkspaceSnapshot) -> [OnboardingSummaryCard] {
        var cards: [OnboardingSummaryCard] = []
        if !workspace.businessProfile.businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cards.append(.business)
        }
        if workspace.clients.first(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) != nil {
            cards.append(.client)
        }
        if let project = workspace.activeProjects.first,
           !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            cards.append(.project)
            if project.buckets.first != nil {
                cards.append(.bucket)
            }
        }
        return cards
    }

    static func primaryCTA(for workspace: WorkspaceSnapshot) -> OnboardingPrimaryCTA {
        .dashboard
    }
}
