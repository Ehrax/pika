import Foundation

#if DEBUG
enum WorkspaceSeedLibrary {
    static let demoWorkspace = WorkspaceSnapshot(
        businessProfile: BusinessProfileProjection(
            businessName: "ehrax.dev",
            personName: "Alexander Raspuitn",
            email: "hello@ehrax.dev",
            phone: "+49 151 44231139",
            address: "Donaustr. 52\n73529 Schwäbisch Gmünd",
            taxIdentifier: "DE123456789",
            invoicePrefix: "EHX",
            nextInvoiceNumber: 5,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE02 1001 1001 2125 8144 33\nBIC NTSBDEB1XXX",
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
                                date: Date.billbiDate(year: 2026, month: 4, day: 23),
                                startTime: "09:00",
                                endTime: "12:30",
                                durationMinutes: 210,
                                description: "API spec and auth token rotation",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
                                date: Date.billbiDate(year: 2026, month: 4, day: 23),
                                startTime: "13:30",
                                endTime: "17:00",
                                durationMinutes: 210,
                                description: "Bookings list endpoint",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000003")!,
                                date: Date.billbiDate(year: 2026, month: 4, day: 24),
                                startTime: "10:00",
                                endTime: "12:00",
                                durationMinutes: 120,
                                description: "Review session with Adi",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000004")!,
                                date: Date.billbiDate(year: 2026, month: 4, day: 24),
                                startTime: "14:00",
                                endTime: "15:00",
                                durationMinutes: 60,
                                description: "Map tiles and clustering",
                                hourlyRateMinorUnits: 20_000
                            ),
                            WorkspaceTimeEntry(
                                id: UUID(uuidString: "50000000-0000-0000-0000-000000000005")!,
                                date: Date.billbiDate(year: 2026, month: 4, day: 26),
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
                                date: Date.billbiDate(year: 2026, month: 4, day: 26),
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
                        issueDate: Date.billbiDate(year: 2026, month: 4, day: 20),
                        dueDate: Date.billbiDate(year: 2026, month: 5, day: 4),
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
                        issueDate: Date.billbiDate(year: 2026, month: 3, day: 16),
                        dueDate: Date.billbiDate(year: 2026, month: 4, day: 10),
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
            WorkspaceActivity(message: "EHX-2026-004 finalized", detail: "Northstar Labs", occurredAt: Date.billbiDate(year: 2026, month: 4, day: 20)),
            WorkspaceActivity(message: "Regression pass marked ready", detail: "Mobile QA", occurredAt: Date.billbiDate(year: 2026, month: 4, day: 18)),
            WorkspaceActivity(message: "April sprint marked ready", detail: "Launch sprint", occurredAt: Date.billbiDate(year: 2026, month: 4, day: 17)),
        ]
    )

    static let bikeparkThunersee = WorkspaceSnapshot(
        businessProfile: BusinessProfileProjection(
            businessName: "ehrax.dev",
            personName: "Alexander Rasputin",
            email: "alex@ehrax.dev",
            phone: "+49 151 44231139",
            address: "Donaustr. 52\n73529 Schwäbisch Gmünd\nGermany",
            taxIdentifier: "151/260/41486",
            economicIdentifier: "DE320253387",
            invoicePrefix: "EHX",
            nextInvoiceNumber: 1,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE02 1001 1001 2125 8144 33\nBIC NTSBDEB1XXX",
            taxNote: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
            defaultTermsDays: 14
        ),
        clients: [
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000101")!,
                name: "Verein Bikepark Thunersee",
                email: "info@bikepark-thunersee.ch",
                billingAddress: "Untere Ttüelmatt 4\n3624 Goldiwil\nSchweiz",
                defaultTermsDays: 14
            ),
        ],
        projects: [
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000101")!,
                name: "Play Bikepark",
                clientName: "Verein Bikepark Thunersee",
                currencyCode: "EUR",
                isArchived: false,
                buckets: [
                    WorkspaceBucket(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000101")!,
                        name: "Trailpass Launch",
                        status: .ready,
                        totalMinorUnits: 0,
                        billableMinutes: 0,
                        fixedCostMinorUnits: 0,
                        defaultHourlyRateMinorUnits: 5_000,
                        timeEntries: [
                            bikeparkTimeEntry(1, 2026, 3, 2, "09:30", "10:30", 60, "Initial MVP scaffold and webhook pipeline"),
                            bikeparkTimeEntry(2, 2026, 3, 2, "14:00", "19:30", 330, "Operational hardening and dev tooling"),
                            bikeparkTimeEntry(3, 2026, 3, 3, "09:00", "11:00", 120, "Replay-safe ingest and test organization"),
                            bikeparkTimeEntry(4, 2026, 3, 3, "11:00", "12:00", 60, "Webhook flow cleanup"),
                            bikeparkTimeEntry(5, 2026, 3, 3, "12:00", "13:00", 60, "Release verification pipeline"),
                            bikeparkTimeEntry(6, 2026, 3, 5, "12:00", "14:00", 120, "Invoice webhook support and safety fixes"),
                            bikeparkTimeEntry(7, 2026, 3, 9, "10:00", "12:00", 120, "Product type storage and classifier wiring"),
                            bikeparkTimeEntry(8, 2026, 3, 9, "17:00", "19:00", 120, "SKU classification cleanup"),
                            bikeparkTimeEntry(9, 2026, 3, 10, "13:00", "13:30", 30, "Payrexx product SKU alignment"),
                            bikeparkTimeEntry(10, 2026, 3, 13, "12:00", "15:00", 180, "Versioned API, mailer config, and ops alerts"),
                            bikeparkTimeEntry(11, 2026, 3, 16, "10:00", "14:00", 240, "Donation-based trailpass classification"),
                            bikeparkTimeEntry(12, 2026, 3, 16, "14:00", "15:00", 60, "Yearly trailpass template redesign"),
                            bikeparkTimeEntry(13, 2026, 3, 16, "15:00", "16:00", 60, "Customer details on PDFs and emails"),
                            bikeparkTimeEntry(14, 2026, 3, 17, "12:00", "16:00", 240, "Mandrill email delivery and customer records"),
                            bikeparkTimeEntry(15, 2026, 3, 18, "08:00", "09:00", 60, "Template preview server"),
                            bikeparkTimeEntry(16, 2026, 3, 18, "12:00", "13:00", 60, "Shared email and PDF layouts"),
                            bikeparkTimeEntry(17, 2026, 3, 18, "15:00", "16:00", 60, "Ticket failure and revocation states"),
                            bikeparkTimeEntry(18, 2026, 3, 18, "18:00", "23:00", 300, "Failure drills, validation, and safety hardening"),
                            bikeparkTimeEntry(19, 2026, 3, 19, "10:30", "19:00", 510, "Day pass flow, ticket IDs, and email copy"),
                            bikeparkTimeEntry(20, 2026, 3, 26, "14:00", "17:00", 180, "Production compose stack and runbook"),
                            bikeparkTimeEntry(21, 2026, 3, 27, "10:00", "12:00", 120, "Production operations cleanup"),
                            bikeparkTimeEntry(22, 2026, 3, 28, "10:00", "13:00", 90, "Backup automation prep"),
                            bikeparkTimeEntry(23, 2026, 3, 29, "12:00", "13:00", 60, "Backup automation scaffolding"),
                            bikeparkTimeEntry(24, 2026, 3, 30, "09:30", "11:30", 120, "Payrexx valid-until planning"),
                            bikeparkTimeEntry(25, 2026, 3, 31, "09:00", "12:00", 180, "Use Payrexx valid_until as ticket source of truth"),
                            bikeparkTimeEntry(26, 2026, 3, 31, "14:00", "15:00", 60, "Ticket date source-of-truth polish"),
                            bikeparkTimeEntry(27, 2026, 4, 1, "11:00", "15:30", 300, "Observability and backup verification hardening"),
                            bikeparkTimeEntry(28, 2026, 4, 2, "10:00", "13:00", 180, "Deploy workflow, versioning, and payout webhooks"),
                            bikeparkTimeEntry(29, 2026, 4, 6, "10:00", "12:00", 120, "Renewal date fixes and Payrexx validity handling"),
                            bikeparkTimeEntry(30, 2026, 4, 12, "10:00", "12:00", 120, "Subscription renewal reminder polish"),
                            bikeparkTimeEntry(31, 2026, 4, 13, "12:00", "14:00", 120, "Subscription renewal reminder emails"),
                        ]
                    ),
                ],
                invoices: []
            ),
        ],
        activity: [
            WorkspaceActivity(
                message: "Trailpass Launch marked ready",
                detail: "Play Bikepark",
                occurredAt: Date.billbiDate(year: 2026, month: 4, day: 13)
            ),
        ]
    )

    private static func bikeparkTimeEntry(
        _ index: Int,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ startTime: String,
        _ endTime: String,
        _ durationMinutes: Int,
        _ description: String
    ) -> WorkspaceTimeEntry {
        WorkspaceTimeEntry(
            id: UUID(uuidString: String(format: "50000000-0000-0000-0000-000000001%03d", index))!,
            date: Date.billbiDate(year: year, month: month, day: day),
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            description: description,
            hourlyRateMinorUnits: 5_000
        )
    }
}
#endif
