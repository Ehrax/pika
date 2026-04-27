import Foundation

extension WorkspaceSnapshot {
    static let sample = WorkspaceSnapshot(
        businessProfile: BusinessProfileProjection(
            businessName: "Ehrax Studio",
            email: "hello@ehrax.dev",
            address: "Lisbon, Portugal",
            invoicePrefix: "EHX",
            nextInvoiceNumber: 5,
            currencyCode: "EUR",
            paymentDetails: "IBAN PT50 0000 0000 0000 0000 0000 0",
            taxNote: "VAT reverse charge where applicable.",
            defaultTermsDays: 14
        ),
        clients: [
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "Happ.ines",
                email: "billing@happines.example",
                billingAddress: "Rua da Alegria 42, Porto",
                defaultTermsDays: 14
            ),
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "Northstar Labs",
                email: "accounts@northstar.example",
                billingAddress: "12 Polaris Yard, Berlin",
                defaultTermsDays: 14
            ),
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "Acme Studio",
                email: "finance@acme.example",
                billingAddress: "5 Market Street, Dublin",
                defaultTermsDays: 30
            ),
        ],
        projects: [
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                name: "Launch sprint",
                clientName: "Happ.ines",
                currencyCode: "EUR",
                isArchived: false,
                buckets: [
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
                        name: "April sprint",
                        status: .ready,
                        totalMinorUnits: 250_000,
                        billableMinutes: 600,
                        fixedCostMinorUnits: 50_000,
                        nonBillableMinutes: 30,
                        timeEntries: [
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
                                date: Date.pikaDate(year: 2026, month: 4, day: 23),
                                startTime: "09:00",
                                endTime: "12:30",
                                durationMinutes: 210,
                                description: "API spec and auth token rotation",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
                                date: Date.pikaDate(year: 2026, month: 4, day: 23),
                                startTime: "13:30",
                                endTime: "17:00",
                                durationMinutes: 210,
                                description: "Bookings list endpoint",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000003")!,
                                date: Date.pikaDate(year: 2026, month: 4, day: 24),
                                startTime: "10:00",
                                endTime: "12:00",
                                durationMinutes: 120,
                                description: "Review session with Adi",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000004")!,
                                date: Date.pikaDate(year: 2026, month: 4, day: 24),
                                startTime: "14:00",
                                endTime: "15:00",
                                durationMinutes: 60,
                                description: "Map tiles and clustering",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000005")!,
                                date: Date.pikaDate(year: 2026, month: 4, day: 26),
                                startTime: "14:30",
                                endTime: "15:00",
                                durationMinutes: 30,
                                description: "Standup and handoff notes",
                                isBillable: false,
                                hourlyRateMinorUnits: 20_000
                            ),
                        ],
                        fixedCostEntries: [
                            WorkspaceFixedCostEntry(
                                id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
                                date: Date.pikaDate(year: 2026, month: 4, day: 26),
                                description: "Prototype hosting",
                                amountMinorUnits: 50_000
                            ),
                        ]
                    ),
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
                        name: "Discovery notes",
                        status: .open,
                        totalMinorUnits: 65_000,
                        billableMinutes: 390,
                        fixedCostMinorUnits: 0
                    ),
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
                        name: "Internal planning",
                        status: .open,
                        totalMinorUnits: 0,
                        billableMinutes: 0,
                        fixedCostMinorUnits: 0
                    ),
                ],
                invoices: []
            ),
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                name: "Mobile QA",
                clientName: "Northstar Labs",
                currencyCode: "EUR",
                isArchived: false,
                buckets: [
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000004")!,
                        name: "Regression pass",
                        status: .ready,
                        totalMinorUnits: 157_500,
                        billableMinutes: 630,
                        fixedCostMinorUnits: 0
                    ),
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000005")!,
                        name: "Follow-up checks",
                        status: .open,
                        totalMinorUnits: 30_000,
                        billableMinutes: 120,
                        fixedCostMinorUnits: 0
                    ),
                ],
                invoices: [
                    WorkspaceInvoice(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                        number: "EHX-2026-004",
                        clientName: "Northstar Labs",
                        projectName: "Mobile QA",
                        bucketName: "Regression pass",
                        issueDate: Date.pikaDate(year: 2026, month: 4, day: 20),
                        dueDate: Date.pikaDate(year: 2026, month: 5, day: 4),
                        status: .finalized,
                        totalMinorUnits: 120_000,
                        lineItems: [
                            WorkspaceInvoiceLineItemSnapshot(
                                description: "Regression pass QA",
                                quantityLabel: "8h",
                                amountMinorUnits: 120_000
                            ),
                        ]
                    ),
                ]
            ),
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                name: "Brand refresh",
                clientName: "Acme Studio",
                currencyCode: "EUR",
                isArchived: true,
                buckets: [
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000006")!,
                        name: "Visual language",
                        status: .finalized,
                        totalMinorUnits: 125_000,
                        billableMinutes: 600,
                        fixedCostMinorUnits: 25_000
                    ),
                ],
                invoices: [
                    WorkspaceInvoice(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
                        number: "EHX-2026-003",
                        clientName: "Acme Studio",
                        projectName: "Brand refresh",
                        bucketName: "Visual language",
                        issueDate: Date.pikaDate(year: 2026, month: 3, day: 16),
                        dueDate: Date.pikaDate(year: 2026, month: 4, day: 10),
                        status: .sent,
                        totalMinorUnits: 125_000,
                        lineItems: [
                            WorkspaceInvoiceLineItemSnapshot(
                                description: "Billable design time",
                                quantityLabel: "10h",
                                amountMinorUnits: 100_000
                            ),
                            WorkspaceInvoiceLineItemSnapshot(
                                description: "Fixed costs",
                                quantityLabel: "1 item",
                                amountMinorUnits: 25_000
                            ),
                        ]
                    ),
                ]
            ),
        ],
        activity: [
            WorkspaceActivity(message: "EHX-2026-004 finalized", detail: "Northstar Labs", occurredAt: Date.pikaDate(year: 2026, month: 4, day: 20)),
            WorkspaceActivity(message: "Regression pass marked ready", detail: "Mobile QA", occurredAt: Date.pikaDate(year: 2026, month: 4, day: 18)),
            WorkspaceActivity(message: "April sprint marked ready", detail: "Launch sprint", occurredAt: Date.pikaDate(year: 2026, month: 4, day: 17)),
        ]
    )
}

extension Date {
    static func pikaDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.pikaGregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
