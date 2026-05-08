import Foundation

struct WorkspaceProject: Codable, Equatable, Identifiable {
    let id: UUID
    var clientID: UUID? = nil
    var name: String
    var clientName: String
    var currencyCode: String
    var isArchived: Bool
    var buckets: [WorkspaceBucket]
    var invoices: [WorkspaceInvoice]

    var bucketCount: Int {
        buckets.count
    }

    var readyBucketCount: Int {
        buckets.filter { $0.status == .ready }.count
    }

    var openBucketCount: Int {
        buckets.filter { $0.status == .open }.count
    }

    var finalizedBucketCount: Int {
        buckets.filter { $0.status == .finalized }.count
    }

    var totalBucketMinorUnits: Int {
        buckets.map(\.effectiveTotalMinorUnits).reduce(0, +)
    }

    var openBucketMinorUnits: Int {
        buckets
            .filter { $0.status == .open }
            .map(\.effectiveTotalMinorUnits)
            .reduce(0, +)
    }

    var readyToInvoiceMinorUnits: Int {
        buckets
            .filter { $0.status == .ready }
            .map(\.effectiveTotalMinorUnits)
            .reduce(0, +)
    }

    func overdueInvoiceCount(on date: Date) -> Int {
        invoices.filter { $0.status.isOverdue(dueDate: $0.dueDate, on: date) }.count
    }

    var defaultHourlyRateMinorUnits: Int? {
        buckets.lazy.compactMap(\.hourlyRateMinorUnits).first
    }
}

enum WorkspaceBucketBillingMode: String, Codable, Equatable, CaseIterable {
    case hourly
    case fixed
    case retainer

    var displayTitle: String {
        switch self {
        case .hourly:
            String(localized: "Hourly")
        case .fixed:
            String(localized: "Fixed")
        case .retainer:
            String(localized: "Retainer")
        }
    }
}

struct WorkspaceBucket: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var status: BucketStatus
    var billingMode: WorkspaceBucketBillingMode = .hourly
    var updatedAt: Date?
    var totalMinorUnits: Int
    var billableMinutes: Int
    var fixedCostMinorUnits: Int
    var nonBillableMinutes: Int = 0
    var defaultHourlyRateMinorUnits: Int? = nil
    var fixedAmountMinorUnits: Int? = nil
    var retainerAmountMinorUnits: Int? = nil
    var retainerPeriodLabel: String = ""
    var retainerIncludedMinutes: Int? = nil
    var retainerOverageRateMinorUnits: Int? = nil
    var timeEntries: [WorkspaceTimeEntry] = []
    var fixedCostEntries: [WorkspaceFixedCostEntry] = []

    init(
        id: UUID,
        name: String,
        status: BucketStatus,
        billingMode: WorkspaceBucketBillingMode = .hourly,
        updatedAt: Date? = nil,
        totalMinorUnits: Int,
        billableMinutes: Int,
        fixedCostMinorUnits: Int,
        nonBillableMinutes: Int = 0,
        defaultHourlyRateMinorUnits: Int? = nil,
        fixedAmountMinorUnits: Int? = nil,
        retainerAmountMinorUnits: Int? = nil,
        retainerPeriodLabel: String = "",
        retainerIncludedMinutes: Int? = nil,
        retainerOverageRateMinorUnits: Int? = nil,
        timeEntries: [WorkspaceTimeEntry] = [],
        fixedCostEntries: [WorkspaceFixedCostEntry] = []
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.billingMode = billingMode
        self.updatedAt = updatedAt
        self.totalMinorUnits = totalMinorUnits
        self.billableMinutes = billableMinutes
        self.fixedCostMinorUnits = fixedCostMinorUnits
        self.nonBillableMinutes = nonBillableMinutes
        self.defaultHourlyRateMinorUnits = defaultHourlyRateMinorUnits
        self.fixedAmountMinorUnits = fixedAmountMinorUnits
        self.retainerAmountMinorUnits = retainerAmountMinorUnits
        self.retainerPeriodLabel = retainerPeriodLabel
        self.retainerIncludedMinutes = retainerIncludedMinutes
        self.retainerOverageRateMinorUnits = retainerOverageRateMinorUnits
        self.timeEntries = timeEntries
        self.fixedCostEntries = fixedCostEntries
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case billingMode
        case updatedAt
        case totalMinorUnits
        case billableMinutes
        case fixedCostMinorUnits
        case nonBillableMinutes
        case defaultHourlyRateMinorUnits
        case fixedAmountMinorUnits
        case retainerAmountMinorUnits
        case retainerPeriodLabel
        case retainerIncludedMinutes
        case retainerOverageRateMinorUnits
        case timeEntries
        case fixedCostEntries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(BucketStatus.self, forKey: .status)
        billingMode = try container.decodeIfPresent(WorkspaceBucketBillingMode.self, forKey: .billingMode) ?? .hourly
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        totalMinorUnits = try container.decode(Int.self, forKey: .totalMinorUnits)
        billableMinutes = try container.decode(Int.self, forKey: .billableMinutes)
        fixedCostMinorUnits = try container.decode(Int.self, forKey: .fixedCostMinorUnits)
        nonBillableMinutes = try container.decodeIfPresent(Int.self, forKey: .nonBillableMinutes) ?? 0
        defaultHourlyRateMinorUnits = try container.decodeIfPresent(Int.self, forKey: .defaultHourlyRateMinorUnits)
        fixedAmountMinorUnits = try container.decodeIfPresent(Int.self, forKey: .fixedAmountMinorUnits)
        retainerAmountMinorUnits = try container.decodeIfPresent(Int.self, forKey: .retainerAmountMinorUnits)
        retainerPeriodLabel = try container.decodeIfPresent(String.self, forKey: .retainerPeriodLabel) ?? ""
        retainerIncludedMinutes = try container.decodeIfPresent(Int.self, forKey: .retainerIncludedMinutes)
        retainerOverageRateMinorUnits = try container.decodeIfPresent(Int.self, forKey: .retainerOverageRateMinorUnits)
        timeEntries = try container.decodeIfPresent([WorkspaceTimeEntry].self, forKey: .timeEntries) ?? []
        fixedCostEntries = try container.decodeIfPresent([WorkspaceFixedCostEntry].self, forKey: .fixedCostEntries) ?? []
    }

    var billableHoursLabel: String {
        Self.billingHoursLabel(minutes: effectiveBillableMinutes)
    }

    var nonBillableHoursLabel: String {
        Self.billingHoursLabel(minutes: effectiveNonBillableMinutes)
    }

    var billableTimeMinorUnits: Int {
        effectiveBillableTimeMinorUnits
    }

    var effectiveBillableMinutes: Int {
        guard hasRowLevelEntries else { return billableMinutes }
        return timeEntries
            .filter(\.isBillable)
            .map(\.durationMinutes)
            .reduce(0, +)
    }

    var effectiveNonBillableMinutes: Int {
        guard hasRowLevelEntries else { return nonBillableMinutes }
        return timeEntries
            .filter { !$0.isBillable }
            .map(\.durationMinutes)
            .reduce(0, +)
    }

    var effectiveFixedCostMinorUnits: Int {
        effectiveFixedChargeMinorUnits
    }

    var effectiveFixedChargeMinorUnits: Int {
        guard billingMode != .fixed else { return 0 }
        guard hasRowLevelEntries else { return fixedCostMinorUnits }
        return fixedCostEntries.map(\.amountMinorUnits).reduce(0, +)
    }

    var effectiveBillableTimeMinorUnits: Int {
        guard billingMode == .hourly else { return 0 }
        guard hasRowLevelEntries else {
            return max(totalMinorUnits - fixedCostMinorUnits, 0)
        }

        return timeEntries.map(\.billableAmountMinorUnits).reduce(0, +)
    }

    var effectiveFixedAmountMinorUnits: Int {
        guard billingMode == .fixed else { return 0 }
        return fixedAmountMinorUnits ?? totalMinorUnits
    }

    var effectiveRetainerAmountMinorUnits: Int {
        guard billingMode == .retainer else { return 0 }
        return retainerAmountMinorUnits ?? totalMinorUnits
    }

    var retainerOverageMinutes: Int {
        guard billingMode == .retainer,
              let included = retainerIncludedMinutes,
              included >= 0,
              retainerOverageRateMinorUnits.map({ $0 > 0 }) == true
        else {
            return 0
        }

        return max(effectiveBillableMinutes - included, 0)
    }

    var retainerOverageMinorUnits: Int {
        guard let rate = retainerOverageRateMinorUnits, rate > 0 else { return 0 }
        return retainerOverageMinutes * rate / 60
    }

    var effectiveTotalMinorUnits: Int {
        switch billingMode {
        case .hourly:
            guard hasRowLevelEntries else { return totalMinorUnits }
            return effectiveBillableTimeMinorUnits + effectiveFixedChargeMinorUnits
        case .fixed:
            return effectiveFixedAmountMinorUnits
        case .retainer:
            return effectiveRetainerAmountMinorUnits + retainerOverageMinorUnits + effectiveFixedChargeMinorUnits
        }
    }

    var hasRowLevelEntries: Bool {
        !timeEntries.isEmpty || !fixedCostEntries.isEmpty
    }

    var hourlyRateMinorUnits: Int? {
        if let rate = timeEntries.first(where: { $0.isBillable && $0.hourlyRateMinorUnits > 0 })?.hourlyRateMinorUnits {
            return rate
        }

        if let defaultHourlyRateMinorUnits, defaultHourlyRateMinorUnits > 0 {
            return defaultHourlyRateMinorUnits
        }

        guard billableMinutes > 0 else { return nil }
        let inferredRate = billableTimeMinorUnits * 60 / billableMinutes
        return inferredRate > 0 ? inferredRate : nil
    }

    static func billingHoursLabel(minutes: Int) -> String {
        let hours = Double(minutes) / 60
        if minutes.isMultiple(of: 60) {
            return "\(Int(hours))h"
        }

        return String(format: "%.1fh", locale: Locale(identifier: "en_US_POSIX"), hours)
    }
}

struct WorkspaceTimeEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var date: Date
    var startTime: String
    var endTime: String
    var durationMinutes: Int
    var description: String
    var isBillable: Bool
    var hourlyRateMinorUnits: Int

    init(
        id: UUID = UUID(),
        date: Date,
        startTime: String,
        endTime: String,
        durationMinutes: Int,
        description: String,
        isBillable: Bool = true,
        hourlyRateMinorUnits: Int
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.description = description
        self.isBillable = isBillable
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
    }

    var timeRangeLabel: String {
        guard !endTime.isEmpty else { return startTime }
        return "\(startTime)-\(endTime)"
    }

    var billableAmountMinorUnits: Int {
        guard isBillable else { return 0 }
        return durationMinutes * hourlyRateMinorUnits / 60
    }
}

struct WorkspaceFixedCostEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var date: Date
    var description: String
    var amountMinorUnits: Int

    init(
        id: UUID = UUID(),
        date: Date,
        description: String,
        amountMinorUnits: Int
    ) {
        self.id = id
        self.date = date
        self.description = description
        self.amountMinorUnits = amountMinorUnits
    }
}
