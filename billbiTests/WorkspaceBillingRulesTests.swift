import Foundation
import Testing
@testable import billbi

struct WorkspaceBillingRulesTests {
    @Test func hourlyBucketTotalsIncludeBillableTimeAndFixedCharges() {
        let bucket = WorkspaceBucket(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000004801")!,
            name: "Infrastructure support",
            status: .open,
            totalMinorUnits: 0,
            billableMinutes: 0,
            fixedCostMinorUnits: 0,
            defaultHourlyRateMinorUnits: 12_000,
            timeEntries: [
                WorkspaceTimeEntry(
                    date: Date.billbiDate(year: 2026, month: 5, day: 1),
                    startTime: "09:00",
                    endTime: "11:30",
                    durationMinutes: 150,
                    description: "Provisioning",
                    hourlyRateMinorUnits: 12_000
                ),
                WorkspaceTimeEntry(
                    date: Date.billbiDate(year: 2026, month: 5, day: 1),
                    startTime: "11:30",
                    endTime: "12:00",
                    durationMinutes: 30,
                    description: "Internal notes",
                    isBillable: false,
                    hourlyRateMinorUnits: 12_000
                ),
            ],
            fixedCostEntries: [
                WorkspaceFixedCostEntry(
                    date: Date.billbiDate(year: 2026, month: 5, day: 1),
                    description: "Client hosting",
                    amountMinorUnits: 4_500
                ),
            ]
        )

        #expect(bucket.billingMode == .hourly)
        #expect(bucket.effectiveBillableMinutes == 150)
        #expect(bucket.effectiveBillableTimeMinorUnits == 30_000)
        #expect(bucket.effectiveFixedChargeMinorUnits == 4_500)
        #expect(bucket.effectiveTotalMinorUnits == 34_500)
    }

    @Test func fixedBucketUsesAgreedAmountWithoutRowLevelEntries() {
        let bucket = WorkspaceBucket(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000004802")!,
            name: "Brand identity package",
            status: .ready,
            billingMode: .fixed,
            totalMinorUnits: 0,
            billableMinutes: 600,
            fixedCostMinorUnits: 9_000,
            defaultHourlyRateMinorUnits: 15_000,
            fixedAmountMinorUnits: 250_000,
            timeEntries: [
                WorkspaceTimeEntry(
                    date: Date.billbiDate(year: 2026, month: 5, day: 2),
                    startTime: "09:00",
                    endTime: "11:00",
                    durationMinutes: 120,
                    description: "Supporting notes",
                    hourlyRateMinorUnits: 15_000
                ),
            ],
            fixedCostEntries: [
                WorkspaceFixedCostEntry(
                    date: Date.billbiDate(year: 2026, month: 5, day: 2),
                    description: "Ignored charge",
                    amountMinorUnits: 9_000
                ),
            ]
        )

        #expect(bucket.effectiveBillableTimeMinorUnits == 0)
        #expect(bucket.effectiveFixedChargeMinorUnits == 0)
        #expect(bucket.effectiveTotalMinorUnits == 250_000)
        #expect(bucket.invoiceLineItemSnapshots().map(\.description) == ["Brand identity package"])
        #expect(bucket.invoiceLineItemSnapshots().map(\.quantityLabel) == ["1 item"])
        #expect(bucket.invoiceLineItemSnapshots().map(\.amountMinorUnits) == [250_000])
    }

    @Test func retainerBucketTotalsIncludeBaseOverageAndFixedCharges() {
        let bucket = WorkspaceBucket(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000004803")!,
            name: "Monthly support",
            status: .ready,
            billingMode: .retainer,
            totalMinorUnits: 0,
            billableMinutes: 0,
            fixedCostMinorUnits: 0,
            retainerAmountMinorUnits: 180_000,
            retainerPeriodLabel: "May 2026",
            retainerIncludedMinutes: 8 * 60,
            retainerOverageRateMinorUnits: 15_000,
            timeEntries: [
                WorkspaceTimeEntry(
                    date: Date.billbiDate(year: 2026, month: 5, day: 3),
                    startTime: "09:00",
                    endTime: "19:00",
                    durationMinutes: 10 * 60,
                    description: "Support day",
                    hourlyRateMinorUnits: 0
                ),
            ],
            fixedCostEntries: [
                WorkspaceFixedCostEntry(
                    date: Date.billbiDate(year: 2026, month: 5, day: 3),
                    description: "Client hosting",
                    amountMinorUnits: 6_500
                ),
            ]
        )

        #expect(bucket.retainerOverageMinutes == 120)
        #expect(bucket.retainerOverageMinorUnits == 30_000)
        #expect(bucket.effectiveFixedChargeMinorUnits == 6_500)
        #expect(bucket.effectiveTotalMinorUnits == 216_500)
        #expect(bucket.invoiceLineItemSnapshots().map(\.description) == [
            "Monthly support",
            "Retainer overage",
            "Client hosting",
        ])
        #expect(bucket.invoiceLineItemSnapshots().map(\.quantityLabel) == [
            "May 2026",
            "2h",
            "1 item",
        ])
        #expect(bucket.invoiceLineItemSnapshots().map(\.amountMinorUnits) == [
            180_000,
            30_000,
            6_500,
        ])
    }
}
