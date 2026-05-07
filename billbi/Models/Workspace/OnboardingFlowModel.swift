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

enum OnboardingReadyBadgeState: Equatable {
    case success
    case neutral
}

struct OnboardingReadySummary: Equatable {
    var cards: [OnboardingSummaryCard]
    var badgeState: OnboardingReadyBadgeState
    var badgeTitle: String
    var title: String
    var subtitle: String
    var tips: [String]
    var primaryCTA: OnboardingPrimaryCTA
}

enum OnboardingContinueAction: Equatable {
    case advanceOnly
    case saveBusiness(OnboardingBusinessDraft)
    case saveClient(OnboardingClientDraft)
    case saveProject(OnboardingProjectDraft)
    case complete(OnboardingPrimaryCTA)
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

    func continueAction(
        workspace: WorkspaceSnapshot,
        businessDraft: OnboardingBusinessDraft,
        clientDraft: OnboardingClientDraft,
        projectDraft: OnboardingProjectDraft
    ) -> OnboardingContinueAction {
        switch step {
        case .welcome:
            return .advanceOnly
        case .business:
            return businessDraft.businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .advanceOnly
                : .saveBusiness(businessDraft)
        case .client:
            return clientDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .advanceOnly
                : .saveClient(clientDraft)
        case .project:
            let projectName = projectDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !projectName.isEmpty,
                  let clientID = projectDraft.clientID ?? workspace.clients.first?.id
            else {
                return .advanceOnly
            }
            var draft = projectDraft
            draft.clientID = clientID
            return .saveProject(draft)
        case .ready:
            return .complete(Self.readySummary(for: workspace).primaryCTA)
        }
    }

    static func summaryCards(for workspace: WorkspaceSnapshot) -> [OnboardingSummaryCard] {
        readySummary(for: workspace).cards
    }

    static func primaryCTA(for workspace: WorkspaceSnapshot) -> OnboardingPrimaryCTA {
        readySummary(for: workspace).primaryCTA
    }

    static func readySummary(for workspace: WorkspaceSnapshot) -> OnboardingReadySummary {
        let cards = readySummaryCards(for: workspace)
        let projectHandoff = readyProjectHandoff(for: workspace)
        return OnboardingReadySummary(
            cards: cards,
            badgeState: cards.isEmpty ? .neutral : .success,
            badgeTitle: cards.isEmpty ? String(localized: "SETUP SKIPPED") : String(localized: "READY"),
            title: readyTitle(for: workspace),
            subtitle: readySubtitle(for: workspace, cards: cards),
            tips: readyTips(for: workspace, cards: cards),
            primaryCTA: projectHandoff.map { .project(projectID: $0.projectID, bucketID: $0.bucketID) } ?? .dashboard
        )
    }

    private static func readySummaryCards(for workspace: WorkspaceSnapshot) -> [OnboardingSummaryCard] {
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

    private static func readyTitle(for workspace: WorkspaceSnapshot) -> String {
        let personName = workspace.businessProfile.personName.trimmingCharacters(in: .whitespacesAndNewlines)
        return personName.isEmpty ? String(localized: "You're ready.") : String(localized: "You're ready, \(personName).")
    }

    private static func readySubtitle(for workspace: WorkspaceSnapshot, cards: [OnboardingSummaryCard]) -> String {
        if cards.contains(.project),
           let project = workspace.activeProjects.first
        {
            return String(localized: "\(project.name) is ready with \(project.buckets.first?.name ?? String(localized: "General")).")
        }
        if cards.contains(.client),
           let client = workspace.clients.first
        {
            return String(localized: "\(client.name) is saved. Add a project when you're ready.")
        }
        if cards.contains(.business) {
            return String(localized: "\(workspace.businessProfile.businessName) is saved. Add clients and projects next.")
        }
        return String(localized: "You can start from the dashboard and fill details later.")
    }

    private static func readyTips(for workspace: WorkspaceSnapshot, cards: [OnboardingSummaryCard]) -> [String] {
        if !cards.contains(.business) {
            return [
                String(localized: "Add your business profile in Settings"),
                String(localized: "Create your first client"),
                String(localized: "Open a project with a starter bucket"),
            ]
        }
        if !cards.contains(.client) {
            return [
                String(localized: "Create your first client"),
                String(localized: "Open a project"),
                String(localized: "Review invoice details before finalizing"),
            ]
        }
        if !cards.contains(.project) {
            return [
                String(localized: "Open a project for \(workspace.clients.first?.name ?? String(localized: "this client"))"),
                String(localized: "Use buckets for billable work"),
                String(localized: "Review invoice details before finalizing"),
            ]
        }
        return [
            String(localized: "Log time in the first bucket"),
            String(localized: "Mark work ready when it is invoiceable"),
            String(localized: "Finalize invoices after details are complete"),
        ]
    }

    private static func readyProjectHandoff(for workspace: WorkspaceSnapshot) -> (projectID: WorkspaceProject.ID, bucketID: WorkspaceBucket.ID)? {
        guard let project = workspace.activeProjects.first(where: { !$0.buckets.isEmpty }),
              let bucket = project.buckets.first
        else {
            return nil
        }
        return (project.id, bucket.id)
    }
}
