import Foundation
import Testing
@testable import billbi

struct DomainEngineTests {
    @Test func bucketStatusesCoverWorkflowStates() {
        #expect(BucketStatus.allCases == [.open, .ready, .finalized, .archived])
        #expect(BucketStatus.finalized.isInvoiceLocked)
        #expect(BucketStatus.archived.isInvoiceLocked)
        #expect(BucketStatus.open.eventLabel == "open")
        #expect(BucketStatus.ready.eventLabel == "ready")
    }

    @Test func invoiceOverdueIsDerivedFromDueDateAndUnpaidStatus() {
        let dueDate = Date(timeIntervalSince1970: 1_767_225_600)
        let afterDueDate = Date(timeIntervalSince1970: 1_767_312_000)
        let beforeDueDate = Date(timeIntervalSince1970: 1_767_139_200)

        #expect(InvoiceStatus.finalized.isOverdue(dueDate: dueDate, on: afterDueDate))
        #expect(InvoiceStatus.sent.isOverdue(dueDate: dueDate, on: afterDueDate))
        #expect(!InvoiceStatus.paid.isOverdue(dueDate: dueDate, on: afterDueDate))
        #expect(!InvoiceStatus.cancelled.isOverdue(dueDate: dueDate, on: afterDueDate))
        #expect(!InvoiceStatus.sent.isOverdue(dueDate: dueDate, on: beforeDueDate))
    }

    @Test func bucketTotalsSeparateBillableAndNonBillableWork() {
        let bucket = InvoiceBucket(
            name: "April sprint",
            status: .open,
            timeEntries: [
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_664_000),
                    description: "Implementation",
                    durationMinutes: 90,
                    rateMinorUnits: 12_500,
                    isBillable: true
                ),
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_667_600),
                    description: "Admin",
                    durationMinutes: 30,
                    rateMinorUnits: 12_500,
                    isBillable: false
                ),
            ],
            fixedCosts: [
                FixedCostEntry(
                    date: Date(timeIntervalSince1970: 1_775_750_400),
                    description: "Stock photography",
                    quantity: 2,
                    unitPriceMinorUnits: 1_500,
                    isBillable: true
                ),
                FixedCostEntry(
                    date: Date(timeIntervalSince1970: 1_775_754_000),
                    description: "Internal tool",
                    quantity: 1,
                    unitPriceMinorUnits: 4_000,
                    isBillable: false
                ),
            ]
        )

        #expect(bucket.totals.billableMinutes == 90)
        #expect(bucket.totals.nonBillableMinutes == 30)
        #expect(bucket.totals.timeSubtotalMinorUnits == 18_750)
        #expect(bucket.totals.fixedSubtotalMinorUnits == 3_000)
        #expect(bucket.totals.totalMinorUnits == 21_750)
    }

    @Test func timeEntryAmountRoundsFractionalMinorUnits() {
        let roundsUp = TimeEntry(
            date: Date(timeIntervalSince1970: 1_775_664_000),
            description: "One minute",
            durationMinutes: 1,
            rateMinorUnits: 100,
            isBillable: true
        )
        let roundsDown = TimeEntry(
            date: Date(timeIntervalSince1970: 1_775_664_000),
            description: "Below half",
            durationMinutes: 1,
            rateMinorUnits: 29,
            isBillable: true
        )
        let roundsHalfUp = TimeEntry(
            date: Date(timeIntervalSince1970: 1_775_664_000),
            description: "Half",
            durationMinutes: 1,
            rateMinorUnits: 30,
            isBillable: true
        )

        #expect(roundsUp.amountMinorUnits == 2)
        #expect(roundsDown.amountMinorUnits == 0)
        #expect(roundsHalfUp.amountMinorUnits == 1)
    }

    @Test func bucketCanOnlyBeMarkedReadyWhenInvoiceableAndEditable() {
        let billableBucket = InvoiceBucket(
            name: "Ready work",
            status: .open,
            timeEntries: [
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_664_000),
                    description: "Design",
                    durationMinutes: 60,
                    rateMinorUnits: 10_000,
                    isBillable: true
                ),
            ]
        )
        let nonBillableBucket = InvoiceBucket(
            name: "Internal",
            status: .open,
            timeEntries: [
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_664_000),
                    description: "Planning",
                    durationMinutes: 60,
                    rateMinorUnits: 10_000,
                    isBillable: false
                ),
            ]
        )

        #expect(billableBucket.canMarkReady)
        #expect(!billableBucket.withStatus(.ready).canMarkReady)
        #expect(!billableBucket.withStatus(.finalized).canMarkReady)
        #expect(!billableBucket.withStatus(.archived).canMarkReady)
        #expect(!nonBillableBucket.canMarkReady)
    }

    @Test func markReadyReturnsReadyBucketAndActivityEvents() throws {
        let bucket = InvoiceBucket(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            name: "Ready work",
            status: .open,
            timeEntries: [
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_664_000),
                    description: "Design",
                    durationMinutes: 60,
                    rateMinorUnits: 10_000,
                    isBillable: true
                ),
            ]
        )

        let result = try bucket.markReady()

        #expect(result.bucket.status == .ready)
        #expect(result.bucket.id == bucket.id)
        #expect(result.activityEvents == [
            .bucketReady(bucketID: bucket.id, bucketName: "Ready work"),
            .statusChanged(entityID: bucket.id, from: "open", to: "ready"),
        ])
    }

    @Test func markReadyFailsForZeroTotalAndLockedBuckets() {
        let nonBillableBucket = InvoiceBucket(
            name: "Internal",
            status: .open,
            timeEntries: [
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_664_000),
                    description: "Planning",
                    durationMinutes: 60,
                    rateMinorUnits: 10_000,
                    isBillable: false
                ),
            ]
        )
        let billableBucket = InvoiceBucket(
            name: "Ready work",
            status: .open,
            timeEntries: [
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_664_000),
                    description: "Design",
                    durationMinutes: 60,
                    rateMinorUnits: 10_000,
                    isBillable: true
                ),
            ]
        )

        #expect(throws: InvoiceBucket.MarkReadyError.notInvoiceable) {
            try nonBillableBucket.markReady()
        }
        #expect(throws: InvoiceBucket.MarkReadyError.lockedStatus(.ready)) {
            try billableBucket.withStatus(.ready).markReady()
        }
        #expect(throws: InvoiceBucket.MarkReadyError.lockedStatus(.finalized)) {
            try billableBucket.withStatus(.finalized).markReady()
        }
        #expect(throws: InvoiceBucket.MarkReadyError.lockedStatus(.archived)) {
            try billableBucket.withStatus(.archived).markReady()
        }
    }

    @Test func invoiceFinalizationSnapshotsContextAndBillableLines() throws {
        var client = ClientSnapshot(name: "Happ.ines", email: "billing@example.com", billingAddress: "Rua Nova 1")
        var project = ProjectSnapshot(name: "Website refresh", currencyCode: "EUR")
        var bucket = InvoiceBucket(
            name: "April sprint",
            status: .ready,
            timeEntries: [
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_664_000),
                    description: "Implementation",
                    durationMinutes: 120,
                    rateMinorUnits: 15_000,
                    isBillable: true
                ),
                TimeEntry(
                    date: Date(timeIntervalSince1970: 1_775_667_600),
                    description: "Internal planning",
                    durationMinutes: 60,
                    rateMinorUnits: 15_000,
                    isBillable: false
                ),
            ],
            fixedCosts: [
                FixedCostEntry(
                    date: Date(timeIntervalSince1970: 1_775_750_400),
                    description: "Hosting",
                    quantity: 1,
                    unitPriceMinorUnits: 2_500,
                    isBillable: true
                ),
            ]
        )

        let result = try Invoice.finalize(
            number: "EHX-2026-004",
            business: BusinessSnapshot(name: "Ehrax Studio", email: "hello@example.com", address: "Lisbon"),
            client: client,
            project: project,
            bucket: bucket,
            issueDate: Date(timeIntervalSince1970: 1_777_392_000),
            dueDate: Date(timeIntervalSince1970: 1_779_984_000)
        )

        let invoice = result.invoice
        client.name = "Changed client"
        project.name = "Changed project"
        bucket.timeEntries[0].description = "Changed work"

        #expect(result.finalizedBucket.status == .finalized)
        #expect(result.finalizedBucket.id == bucket.id)
        #expect(result.activityEvents == [
            .invoiceFinalized(invoiceID: invoice.id, invoiceNumber: "EHX-2026-004"),
            .statusChanged(entityID: bucket.id, from: "ready", to: "finalized"),
        ])
        #expect(invoice.status == .finalized)
        #expect(invoice.client.name == "Happ.ines")
        #expect(invoice.project.name == "Website refresh")
        #expect(invoice.bucketName == "April sprint")
        #expect(invoice.lines.map(\.description) == ["Implementation", "Hosting"])
        #expect(invoice.lines.map(\.quantity) == [.minutes(120), .units(1)])
        #expect(invoice.totalMinorUnits == 32_500)
    }

    @Test func invoiceNumberFormatterPadsSequenceWithPrefixAndYear() {
        let formatter = InvoiceNumberFormatter(prefix: "EHX")

        #expect(formatter.string(year: 2026, sequence: 4) == "EHX-2026-004")
        #expect(formatter.string(year: 2026, sequence: 42) == "EHX-2026-042")
    }

    @Test func activityEventsExposeStableTelemetryNames() {
        let bucketID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let invoiceID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        #expect(ActivityEvent.bucketReady(bucketID: bucketID, bucketName: "April").eventName == "bucket.ready")
        #expect(ActivityEvent.invoiceFinalized(invoiceID: invoiceID, invoiceNumber: "EHX-2026-004").eventName == "invoice.finalized")
        #expect(ActivityEvent.statusChanged(entityID: invoiceID, from: "sent", to: "paid").eventName == "status.changed")
        #expect(ActivityEvent.bucketReady(bucketID: bucketID, bucketName: "April").category == .workflow)
    }

    @Test func activityEventsExposeUserVisibleMessages() {
        let bucketID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let invoiceID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        #expect(ActivityEvent.bucketReady(bucketID: bucketID, bucketName: "April").message == "April marked ready")
        #expect(ActivityEvent.invoiceFinalized(invoiceID: invoiceID, invoiceNumber: "EHX-2026-004").message == "Invoice EHX-2026-004 finalized")
        #expect(ActivityEvent.statusChanged(entityID: invoiceID, from: "sent", to: "paid").message == "Status changed from sent to paid")
    }
}
