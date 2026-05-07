import Foundation

struct WorkspaceSnapshot: Codable, Equatable {
    static let empty = WorkspaceSnapshot(
        onboardingCompleted: false,
        businessProfile: BusinessProfileProjection(
            businessName: "",
            email: "",
            phone: "",
            address: "",
            invoicePrefix: "INV",
            nextInvoiceNumber: 1,
            currencyCode: "EUR",
            paymentDetails: "",
            taxNote: "",
            defaultTermsDays: 14
        ),
        clients: [],
        projects: [],
        activity: []
    )

    var onboardingCompleted: Bool
    var businessProfile: BusinessProfileProjection
    var clients: [WorkspaceClient]
    var projects: [WorkspaceProject]
    var activity: [WorkspaceActivity]

    private enum CodingKeys: String, CodingKey {
        case onboardingCompleted
        case businessProfile
        case clients
        case projects
        case activity
    }

    init(
        onboardingCompleted: Bool = false,
        businessProfile: BusinessProfileProjection,
        clients: [WorkspaceClient],
        projects: [WorkspaceProject],
        activity: [WorkspaceActivity]
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.businessProfile = businessProfile
        self.clients = clients
        self.projects = projects
        self.activity = activity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        businessProfile = try container.decode(BusinessProfileProjection.self, forKey: .businessProfile)
        clients = try container.decode([WorkspaceClient].self, forKey: .clients)
        projects = try container.decode([WorkspaceProject].self, forKey: .projects)
        activity = try container.decode([WorkspaceActivity].self, forKey: .activity)
    }

    var activeProjects: [WorkspaceProject] {
        projects.filter { !$0.isArchived }
    }

    var archivedProjects: [WorkspaceProject] {
        projects.filter(\.isArchived)
    }

    mutating func normalizeMissingHourlyRates(defaultRateMinorUnits: Int = 8_000) {
        for projectIndex in projects.indices {
            let fallbackRate = projects[projectIndex].defaultHourlyRateMinorUnits ?? defaultRateMinorUnits

            for bucketIndex in projects[projectIndex].buckets.indices {
                let bucketRate = projects[projectIndex].buckets[bucketIndex].hourlyRateMinorUnits
                if projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits.map({ $0 <= 0 }) == true {
                    projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = bucketRate ?? fallbackRate
                } else if bucketRate == nil {
                    projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = fallbackRate
                }

                for entryIndex in projects[projectIndex].buckets[bucketIndex].timeEntries.indices {
                    let entry = projects[projectIndex].buckets[bucketIndex].timeEntries[entryIndex]
                    if entry.isBillable && entry.hourlyRateMinorUnits <= 0 {
                        projects[projectIndex].buckets[bucketIndex].timeEntries[entryIndex].hourlyRateMinorUnits = fallbackRate
                    }
                }
            }
        }
    }

    var recentActivity: [WorkspaceActivity] {
        activity.sorted { left, right in
            if left.occurredAt == right.occurredAt {
                return left.message < right.message
            }

            return left.occurredAt > right.occurredAt
        }
    }

    func project(named name: String) -> WorkspaceProject? {
        projects.first { $0.name == name }
    }

}

extension Date {
    static func billbiDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.billbiGregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
