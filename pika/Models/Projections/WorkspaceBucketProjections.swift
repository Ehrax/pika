import Foundation

enum WorkspaceBucketEntryKind: Equatable {
    case time
    case fixedCost
}

struct WorkspaceBucketEntryRowProjection: Equatable, Identifiable {
    let id: UUID
    let kind: WorkspaceBucketEntryKind
    let dateLabel: String
    let timeLabel: String
    let description: String
    let hoursLabel: String
    let amountLabel: String
    let isBillable: Bool
}

struct WorkspaceInlineEntryDraftProjection: Equatable {
    let timeInput: String
    let description: String
    let isBillable: Bool
    let hourlyRateMinorUnits: Int
    let durationMinutes: Int?
    let hoursLabel: String
    let amountLabel: String

    init(
        timeInput: String,
        description: String,
        isBillable: Bool,
        hourlyRateMinorUnits: Int,
        formatter: MoneyFormatting
    ) {
        self.timeInput = timeInput
        self.description = description
        self.isBillable = isBillable
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
        durationMinutes = WorkspaceEntryDurationParser.minutes(from: timeInput)

        if let durationMinutes {
            hoursLabel = Self.hoursLabel(minutes: durationMinutes)
            if isBillable {
                amountLabel = formatter.string(fromMinorUnits: durationMinutes * hourlyRateMinorUnits / 60)
            } else {
                amountLabel = "n/b"
            }
        } else {
            hoursLabel = "-"
            amountLabel = isBillable ? formatter.string(fromMinorUnits: 0) : "n/b"
        }
    }

    private static func hoursLabel(minutes: Int) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(minutes) / 60)
    }
}

extension WorkspaceBucket {
    func entryRows(formatter: MoneyFormatting) -> [WorkspaceBucketEntryRowProjection] {
        if hasRowLevelEntries {
            return rowLevelEntryRows(formatter: formatter)
        }

        return legacyEntryRows(formatter: formatter)
    }

    private func rowLevelEntryRows(formatter: MoneyFormatting) -> [WorkspaceBucketEntryRowProjection] {
        let timeRows = timeEntries.map { entry in
            WorkspaceBucketEntryRowSortingCandidate(
                date: entry.date,
                timeSortKey: entry.timeRangeLabel,
                row: WorkspaceBucketEntryRowProjection(
                    id: entry.id,
                    kind: .time,
                    dateLabel: Self.dateFormatter.string(from: entry.date),
                    timeLabel: entry.timeRangeLabel,
                    description: entry.description,
                    hoursLabel: Self.hoursLabel(minutes: entry.durationMinutes),
                    amountLabel: entry.isBillable ? formatter.string(fromMinorUnits: entry.billableAmountMinorUnits) : "n/b",
                    isBillable: entry.isBillable
                )
            )
        }

        let fixedRows = fixedCostEntries.map { entry in
            WorkspaceBucketEntryRowSortingCandidate(
                date: entry.date,
                timeSortKey: "99:fixed-cost",
                row: WorkspaceBucketEntryRowProjection(
                    id: entry.id,
                    kind: .fixedCost,
                    dateLabel: Self.dateFormatter.string(from: entry.date),
                    timeLabel: "Fixed cost",
                    description: entry.description,
                    hoursLabel: "-",
                    amountLabel: formatter.string(fromMinorUnits: entry.amountMinorUnits),
                    isBillable: entry.amountMinorUnits > 0
                )
            )
        }

        return (timeRows + fixedRows).sorted { left, right in
            if left.date == right.date {
                return left.timeSortKey < right.timeSortKey
            }

            return left.date < right.date
        }.map(\.row)
    }

    private func legacyEntryRows(formatter: MoneyFormatting) -> [WorkspaceBucketEntryRowProjection] {
        var rows: [WorkspaceBucketEntryRowProjection] = []

        if billableMinutes > 0 || billableTimeMinorUnits > 0 {
            rows.append(WorkspaceBucketEntryRowProjection(
                id: id,
                kind: .time,
                dateLabel: "-",
                timeLabel: "Billable",
                description: "Billable time",
                hoursLabel: Self.hoursLabel(minutes: billableMinutes),
                amountLabel: formatter.string(fromMinorUnits: billableTimeMinorUnits),
                isBillable: true
            ))
        }

        if fixedCostMinorUnits > 0 {
            let suffix = id.uuidString.replacingOccurrences(of: "-", with: "").suffix(12)
            rows.append(WorkspaceBucketEntryRowProjection(
                id: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? id,
                kind: .fixedCost,
                dateLabel: "-",
                timeLabel: "Fixed cost",
                description: "Fixed costs",
                hoursLabel: "-",
                amountLabel: formatter.string(fromMinorUnits: fixedCostMinorUnits),
                isBillable: true
            ))
        }

        if nonBillableMinutes > 0 {
            let suffix = id.uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
            rows.append(WorkspaceBucketEntryRowProjection(
                id: UUID(uuidString: "11111111-1111-1111-1111-\(suffix)") ?? id,
                kind: .time,
                dateLabel: "-",
                timeLabel: "Non-billable",
                description: "Non-billable time",
                hoursLabel: Self.hoursLabel(minutes: nonBillableMinutes),
                amountLabel: "n/b",
                isBillable: false
            ))
        }

        return rows
    }

    private static func hoursLabel(minutes: Int) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(minutes) / 60)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

private struct WorkspaceBucketEntryRowSortingCandidate {
    let date: Date
    let timeSortKey: String
    let row: WorkspaceBucketEntryRowProjection
}
