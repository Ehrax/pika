import Foundation

enum DashboardRevenueRange: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case fourteenDays = "14D"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case twelveMonths = "12M"
    case all = "All"

    var id: String { rawValue }

    private var bucketCount: Int? {
        switch self {
        case .sevenDays:
            7
        case .fourteenDays:
            14
        case .oneMonth:
            30
        case .threeMonths:
            3
        case .sixMonths:
            6
        case .twelveMonths:
            12
        case .all:
            nil
        }
    }

    private var component: Calendar.Component {
        switch self {
        case .sevenDays, .fourteenDays, .oneMonth:
            .day
        case .threeMonths, .sixMonths, .twelveMonths, .all:
            .month
        }
    }

    func visiblePoints(from points: [RevenuePoint], endingAt endDate: Date) -> [RevenuePoint] {
        guard !points.isEmpty else { return [] }

        let calendar = Calendar.billbiGregorian
        let endBucket = bucketStart(for: endDate, component: component, calendar: calendar)
        let startBucket: Date

        if let bucketCount {
            startBucket = calendar.date(byAdding: component, value: -(bucketCount - 1), to: endBucket) ?? endBucket
        } else {
            let earliest = points.map(\.date).min() ?? endBucket
            startBucket = bucketStart(for: earliest, component: component, calendar: calendar)
        }

        let groupedAmounts = Dictionary(grouping: points) { point in
            bucketStart(for: point.date, component: component, calendar: calendar)
        }
        .mapValues { points in
            points.map(\.amountMinorUnits).reduce(0, +)
        }

        return bucketStarts(from: startBucket, through: endBucket, component: component, calendar: calendar).map { date in
            RevenuePoint(
                date: date,
                label: label(for: date, component: component),
                amountMinorUnits: groupedAmounts[date, default: 0]
            )
        }
    }

    private func bucketStart(for date: Date, component: Calendar.Component, calendar: Calendar) -> Date {
        switch component {
        case .day:
            return calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? date
        default:
            return date
        }
    }

    private func bucketStarts(
        from startDate: Date,
        through endDate: Date,
        component: Calendar.Component,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        var cursor = startDate

        while cursor <= endDate {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            cursor = next
        }

        return dates
    }

    private func label(for date: Date, component: Calendar.Component) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.billbiGregorian
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = component == .day ? "MMM d" : "MMM yy"
        return formatter.string(from: date)
    }
}
