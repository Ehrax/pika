import Foundation

extension WorkspaceBucket {
    mutating func updateEntryDate(rowID: UUID, kind: WorkspaceBucketEntryKind, date: Date) -> Bool {
        switch kind {
        case .time:
            guard let index = timeEntries.firstIndex(where: { $0.id == rowID }) else {
                return false
            }

            timeEntries[index].date = date
            return true

        case .fixedCost:
            guard let index = fixedCostEntries.firstIndex(where: { $0.id == rowID }) else {
                return false
            }

            fixedCostEntries[index].date = date
            return true
        }
    }

    mutating func deleteEntry(rowID: UUID, kind: WorkspaceBucketEntryKind, isBillable: Bool) -> Bool {
        let hadRowLevelEntries = hasRowLevelEntries

        switch kind {
        case .time:
            if let index = timeEntries.firstIndex(where: { $0.id == rowID }) {
                timeEntries.remove(at: index)
                clearLegacyTotalsIfLastRowLevelEntryWasDeleted(hadRowLevelEntries: hadRowLevelEntries)
                return true
            }

            guard !hasRowLevelEntries else { return false }
            if isBillable, rowID == id, billableMinutes > 0 {
                totalMinorUnits = fixedCostMinorUnits
                billableMinutes = 0
                return true
            }

            if !isBillable, nonBillableMinutes > 0 {
                nonBillableMinutes = 0
                return true
            }

            return false

        case .fixedCost:
            if let index = fixedCostEntries.firstIndex(where: { $0.id == rowID }) {
                fixedCostEntries.remove(at: index)
                clearLegacyTotalsIfLastRowLevelEntryWasDeleted(hadRowLevelEntries: hadRowLevelEntries)
                return true
            }

            guard !hasRowLevelEntries, fixedCostMinorUnits > 0 else { return false }
            totalMinorUnits = max(totalMinorUnits - fixedCostMinorUnits, 0)
            fixedCostMinorUnits = 0
            return true
        }
    }

    mutating func clearLegacyTotalsIfLastRowLevelEntryWasDeleted(hadRowLevelEntries: Bool) {
        guard hadRowLevelEntries, !hasRowLevelEntries else { return }
        totalMinorUnits = 0
        billableMinutes = 0
        fixedCostMinorUnits = 0
        nonBillableMinutes = 0
    }

    mutating func backfillLegacyRowsForEditing(on date: Date) {
        guard billingMode == .hourly, !hasRowLevelEntries else { return }

        if billableMinutes > 0 {
            timeEntries.append(WorkspaceTimeEntry(date: date, startTime: "Logged", endTime: "", durationMinutes: billableMinutes, description: "Billable time", hourlyRateMinorUnits: hourlyRateMinorUnits ?? 0))
        }
        if nonBillableMinutes > 0 {
            timeEntries.append(WorkspaceTimeEntry(date: date, startTime: "Logged", endTime: "", durationMinutes: nonBillableMinutes, description: "Non-billable time", isBillable: false, hourlyRateMinorUnits: hourlyRateMinorUnits ?? 0))
        }
        if fixedCostMinorUnits > 0 {
            fixedCostEntries.append(WorkspaceFixedCostEntry(
                date: date,
                description: String(localized: "Fixed Charges"),
                amountMinorUnits: fixedCostMinorUnits
            ))
        }
    }

    func invoiceLineItemSnapshots() -> [WorkspaceInvoiceLineItemSnapshot] {
        switch billingMode {
        case .hourly:
            return hourlyInvoiceLineItemSnapshots()
        case .fixed:
            guard effectiveFixedAmountMinorUnits > 0 else { return [] }
            return [
                WorkspaceInvoiceLineItemSnapshot(
                    description: name,
                    quantityLabel: "1 item",
                    amountMinorUnits: effectiveFixedAmountMinorUnits
                ),
            ]
        case .retainer:
            return retainerInvoiceLineItemSnapshots()
        }
    }

    private func hourlyInvoiceLineItemSnapshots() -> [WorkspaceInvoiceLineItemSnapshot] {
        var items: [WorkspaceInvoiceLineItemSnapshot] = []
        if billableTimeMinorUnits > 0 {
            items.append(WorkspaceInvoiceLineItemSnapshot(description: name, quantityLabel: billableHoursLabel, amountMinorUnits: billableTimeMinorUnits))
        }
        if effectiveFixedChargeMinorUnits > 0 {
            let fixedCostDescription: String
            if fixedCostEntries.count == 1,
               let description = fixedCostEntries.first?.description.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                fixedCostDescription = description
            } else {
                fixedCostDescription = String(localized: "Fixed Charges")
            }
            items.append(WorkspaceInvoiceLineItemSnapshot(description: fixedCostDescription, quantityLabel: fixedCostEntries.isEmpty ? "1 item" : fixedCostEntries.count.formattedItemCount, amountMinorUnits: effectiveFixedChargeMinorUnits))
        }
        return items
    }

    private func retainerInvoiceLineItemSnapshots() -> [WorkspaceInvoiceLineItemSnapshot] {
        var items: [WorkspaceInvoiceLineItemSnapshot] = []
        if effectiveRetainerAmountMinorUnits > 0 {
            let period = retainerPeriodLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(WorkspaceInvoiceLineItemSnapshot(
                description: name,
                quantityLabel: period.isEmpty ? String(localized: "Retainer") : period,
                amountMinorUnits: effectiveRetainerAmountMinorUnits
            ))
        }
        if retainerOverageMinorUnits > 0 {
            items.append(WorkspaceInvoiceLineItemSnapshot(
                description: String(localized: "Retainer overage"),
                quantityLabel: Self.billingHoursLabel(minutes: retainerOverageMinutes),
                amountMinorUnits: retainerOverageMinorUnits
            ))
        }
        if effectiveFixedChargeMinorUnits > 0 {
            let fixedChargeDescription: String
            if fixedCostEntries.count == 1,
               let description = fixedCostEntries.first?.description.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                fixedChargeDescription = description
            } else {
                fixedChargeDescription = String(localized: "Fixed Charges")
            }
            items.append(WorkspaceInvoiceLineItemSnapshot(
                description: fixedChargeDescription,
                quantityLabel: fixedCostEntries.isEmpty ? "1 item" : fixedCostEntries.count.formattedItemCount,
                amountMinorUnits: effectiveFixedChargeMinorUnits
            ))
        }
        return items
    }
}

private extension Int {
    var formattedItemCount: String { self == 1 ? "1 item" : "\(self) items" }
}
