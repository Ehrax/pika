import Foundation
import SwiftData
import Testing
@testable import pika

struct WorkspacePersistenceReloadTests {
    @Test func persistentWorkspaceReloadDoesNotRestoreLegacyActivityBlob() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let seededWorkspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [],
            activity: [
                WorkspaceActivity(
                    message: "Legacy activity",
                    detail: "Do not reload",
                    occurredAt: Date.pikaDate(year: 2026, month: 5, day: 1)
                ),
            ]
        )

        let seedStore = WorkspaceStore(seed: seededWorkspace, modelContext: modelContext)
        #expect(seedStore.workspace.activity.count == 1)

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        #expect(reloadedStore.workspace.businessProfile.businessName == seededWorkspace.businessProfile.businessName)
        #expect(reloadedStore.workspace.activity.isEmpty)
    }

    @Test func persistentWorkspaceStoreFinalizesInvoiceSnapshotsIntoNormalizedRecords() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000611")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000611")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000611")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 1)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 15)

        let profile = BusinessProfileRecord(
            businessName: "North Coast Studio",
            personName: "Avery North",
            email: "billing@northcoast.example",
            phone: "+49 555 0100",
            address: "1 Harbour Way",
            taxIdentifier: "DE123",
            economicIdentifier: "ECO123",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 42,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE00 1234",
            taxNote: "VAT exempt",
            defaultTermsDays: 14,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let client = ClientRecord(
            id: clientID,
            name: "Snapshot Client",
            email: "billing@snapshot.example",
            billingAddress: "1 Snapshot Way",
            defaultTermsDays: 21,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Snapshot Project",
            currencyCode: "EUR",
            createdAt: issueDate,
            updatedAt: issueDate,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Ready Snapshot",
            statusRaw: BucketStatus.ready.rawValue,
            defaultHourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            project: project
        )
        let timeEntry = TimeEntryRecord(
            bucketID: bucketID,
            workDate: issueDate,
            durationMinutes: 600,
            descriptionText: "Billable work",
            isBillable: true,
            hourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            bucket: bucket
        )
        let fixedCost = FixedCostRecord(
            bucketID: bucketID,
            date: issueDate,
            descriptionText: "Design package",
            quantity: 1,
            unitPriceMinorUnits: 32_000,
            isBillable: true,
            createdAt: issueDate,
            updatedAt: issueDate,
            bucket: bucket
        )

        modelContext.insert(profile)
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(timeEntry)
        modelContext.insert(fixedCost)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let invoice = try store.finalizeInvoice(
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Snapshot Client",
                recipientEmail: "billing@snapshot.example",
                recipientBillingAddress: "1 Snapshot Way",
                invoiceNumber: "NCS-2026-042",
                template: .kleinunternehmerClassic,
                issueDate: issueDate,
                dueDate: dueDate,
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: "Thank you."
            ),
            occurredAt: issueDate
        )

        let persistedInvoices = try store.invoiceRecords(for: projectID)
        #expect(persistedInvoices.count == 1)
        let persistedLineItems = try store.invoiceLineItemRecords(for: invoice.id)
            .sorted(by: { $0.sortOrder < $1.sortOrder })
        #expect(persistedLineItems.map(\.descriptionText) == [
            "Ready Snapshot",
            "Design package",
        ])

        profile.businessName = "Changed Business"
        client.name = "Changed Client"
        client.email = "changed@example.com"
        project.name = "Changed Project"
        bucket.name = "Changed Bucket"
        timeEntry.descriptionText = "Changed time"
        fixedCost.descriptionText = "Changed fixed cost"
        try modelContext.save()

        try store.markInvoiceSent(invoiceID: invoice.id, occurredAt: dueDate)
        try store.markInvoicePaid(invoiceID: invoice.id, occurredAt: dueDate.addingTimeInterval(60))

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let reloadedProject = try #require(reloadedStore.workspace.projects.first(where: { $0.id == projectID }))
        let reloadedBucket = try #require(reloadedProject.buckets.first(where: { $0.id == bucketID }))
        let reloadedInvoice = try #require(reloadedProject.invoices.first(where: { $0.id == invoice.id }))

        #expect(reloadedBucket.status == .finalized)
        #expect(reloadedInvoice.status == .paid)
        #expect(reloadedInvoice.businessSnapshot?.businessName == "North Coast Studio")
        #expect(reloadedInvoice.clientSnapshot?.name == "Snapshot Client")
        #expect(reloadedInvoice.clientSnapshot?.email == "billing@snapshot.example")
        #expect(reloadedInvoice.projectName == "Snapshot Project")
        #expect(reloadedInvoice.bucketName == "Ready Snapshot")
        #expect(reloadedInvoice.number == "NCS-2026-042")
        #expect(reloadedInvoice.currencyCode == "EUR")
        #expect(reloadedInvoice.note == "Thank you.")
        #expect(reloadedInvoice.lineItems.map(\.description) == [
            "Ready Snapshot",
            "Design package",
        ])
        #expect(reloadedInvoice.lineItems.map(\.quantityLabel) == [
            "10h",
            "1 item",
        ])
        #expect(reloadedInvoice.lineItems.map(\.amountMinorUnits) == [
            100_000,
            32_000,
        ])
    }

    @Test func persistentWorkspaceStoreRejectsDuplicateLocalInvoiceNumbers() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000612")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000612")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000612")!
        let existingInvoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000612")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 2)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 16)

        let profile = BusinessProfileRecord(
            businessName: "North Coast Studio",
            personName: "Avery North",
            email: "billing@northcoast.example",
            phone: "+49 555 0100",
            address: "1 Harbour Way",
            taxIdentifier: "DE123",
            economicIdentifier: "ECO123",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 43,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE00 1234",
            taxNote: "VAT exempt",
            defaultTermsDays: 14,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let client = ClientRecord(
            id: clientID,
            name: "Snapshot Client",
            email: "billing@snapshot.example",
            billingAddress: "1 Snapshot Way",
            defaultTermsDays: 21,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Snapshot Project",
            currencyCode: "EUR",
            createdAt: issueDate,
            updatedAt: issueDate,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Ready Snapshot",
            statusRaw: BucketStatus.ready.rawValue,
            defaultHourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            project: project
        )
        let timeEntry = TimeEntryRecord(
            bucketID: bucketID,
            workDate: issueDate,
            durationMinutes: 60,
            descriptionText: "Billable work",
            isBillable: true,
            hourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            bucket: bucket
        )
        let existingInvoice = InvoiceRecord(
            id: existingInvoiceID,
            projectID: projectID,
            bucketID: bucketID,
            number: "NCS-2026-042",
            templateRaw: InvoiceTemplate.kleinunternehmerClassic.rawValue,
            issueDate: issueDate,
            dueDate: dueDate,
            servicePeriod: "May 2026",
            statusRaw: InvoiceStatus.finalized.rawValue,
            totalMinorUnits: 10_000,
            currencyCode: "EUR",
            note: "",
            businessName: "North Coast Studio",
            businessPersonName: "Avery North",
            businessEmail: "billing@northcoast.example",
            businessPhone: "+49 555 0100",
            businessAddress: "1 Harbour Way",
            businessTaxIdentifier: "DE123",
            businessEconomicIdentifier: "ECO123",
            businessPaymentDetails: "IBAN DE00 1234",
            businessTaxNote: "VAT exempt",
            clientName: "Snapshot Client",
            clientEmail: "billing@snapshot.example",
            clientBillingAddress: "1 Snapshot Way",
            projectName: "Snapshot Project",
            bucketName: "Ready Snapshot",
            createdAt: issueDate,
            updatedAt: issueDate,
            project: project,
            bucket: bucket
        )
        modelContext.insert(profile)
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(timeEntry)
        modelContext.insert(existingInvoice)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        #expect(throws: WorkspaceStoreError.duplicateInvoiceNumber) {
            try store.finalizeInvoice(
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Snapshot Client",
                    recipientEmail: "billing@snapshot.example",
                    recipientBillingAddress: "1 Snapshot Way",
                    invoiceNumber: " NCS-2026-042 ",
                    template: .kleinunternehmerClassic,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                ),
                occurredAt: issueDate
            )
        }
    }

    @Test func persistentWorkspaceStoreReloadsAndThrowsConflictForStaleInvoiceFinalization() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000613")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000613")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000613")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 3)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 17)

        let profile = BusinessProfileRecord(
            businessName: "North Coast Studio",
            personName: "Avery North",
            email: "billing@northcoast.example",
            phone: "+49 555 0100",
            address: "1 Harbour Way",
            taxIdentifier: "DE123",
            economicIdentifier: "ECO123",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 44,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE00 1234",
            taxNote: "VAT exempt",
            defaultTermsDays: 14,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let client = ClientRecord(
            id: clientID,
            name: "Snapshot Client",
            email: "billing@snapshot.example",
            billingAddress: "1 Snapshot Way",
            defaultTermsDays: 21,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Snapshot Project",
            currencyCode: "EUR",
            createdAt: issueDate,
            updatedAt: issueDate,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Ready Snapshot",
            statusRaw: BucketStatus.ready.rawValue,
            defaultHourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            project: project
        )
        let timeEntry = TimeEntryRecord(
            bucketID: bucketID,
            workDate: issueDate,
            durationMinutes: 60,
            descriptionText: "Billable work",
            isBillable: true,
            hourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            bucket: bucket
        )

        modelContext.insert(profile)
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(timeEntry)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let initialProject = try #require(store.workspace.projects.first(where: { $0.id == projectID }))
        #expect(initialProject.buckets.first(where: { $0.id == bucketID })?.status == .ready)

        bucket.status = .finalized
        bucket.updatedAt = issueDate.addingTimeInterval(60)
        try modelContext.save()

        #expect(throws: WorkspaceStoreError.persistenceConflict) {
            try store.finalizeInvoice(
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Snapshot Client",
                    recipientEmail: "billing@snapshot.example",
                    recipientBillingAddress: "1 Snapshot Way",
                    invoiceNumber: "NCS-2026-044",
                    template: .kleinunternehmerClassic,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                ),
                occurredAt: issueDate
            )
        }

        let reloadedProject = try #require(store.workspace.projects.first(where: { $0.id == projectID }))
        let reloadedBucket = try #require(reloadedProject.buckets.first(where: { $0.id == bucketID }))
        #expect(reloadedBucket.status == .finalized)
        #expect(reloadedProject.invoices.isEmpty)
    }

    @Test func persistentWorkspaceStoreRejectsReadyBucketFinalizationWhenDurableInputsChanged() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000615")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000615")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000615")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 5)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 19)

        let profile = BusinessProfileRecord(
            businessName: "North Coast Studio",
            personName: "Avery North",
            email: "billing@northcoast.example",
            phone: "+49 555 0100",
            address: "1 Harbour Way",
            taxIdentifier: "DE123",
            economicIdentifier: "ECO123",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 46,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE00 1234",
            taxNote: "VAT exempt",
            defaultTermsDays: 14,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let client = ClientRecord(
            id: clientID,
            name: "Snapshot Client",
            email: "billing@snapshot.example",
            billingAddress: "1 Snapshot Way",
            defaultTermsDays: 21,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Snapshot Project",
            currencyCode: "EUR",
            createdAt: issueDate,
            updatedAt: issueDate,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Ready Snapshot",
            statusRaw: BucketStatus.ready.rawValue,
            defaultHourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            project: project
        )
        let timeEntry = TimeEntryRecord(
            bucketID: bucketID,
            workDate: issueDate,
            durationMinutes: 60,
            descriptionText: "Original billable work",
            isBillable: true,
            hourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            bucket: bucket
        )

        modelContext.insert(profile)
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(timeEntry)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let initialProject = try #require(store.workspace.projects.first(where: { $0.id == projectID }))
        #expect(initialProject.buckets.first(where: { $0.id == bucketID })?.status == .ready)

        timeEntry.descriptionText = "Synced billable work"
        timeEntry.durationMinutes = 120
        timeEntry.updatedAt = issueDate.addingTimeInterval(60)
        try modelContext.save()

        #expect(throws: WorkspaceStoreError.persistenceConflict) {
            try store.finalizeInvoice(
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Snapshot Client",
                    recipientEmail: "billing@snapshot.example",
                    recipientBillingAddress: "1 Snapshot Way",
                    invoiceNumber: "NCS-2026-046",
                    template: .kleinunternehmerClassic,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                ),
                occurredAt: issueDate
            )
        }

        let reloadedProject = try #require(store.workspace.projects.first(where: { $0.id == projectID }))
        let reloadedBucket = try #require(reloadedProject.buckets.first(where: { $0.id == bucketID }))
        #expect(reloadedBucket.status == .ready)
        #expect(reloadedBucket.timeEntries.first?.description == "Synced billable work")
        #expect(reloadedBucket.timeEntries.first?.durationMinutes == 120)
        #expect(reloadedProject.invoices.isEmpty)
    }

    @Test func persistentWorkspaceStoreReloadsAndThrowsConflictForStaleInvoiceNumberDuplicate() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000614")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000614")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000614")!
        let existingInvoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000614")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 4)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 18)

        let profile = BusinessProfileRecord(
            businessName: "North Coast Studio",
            personName: "Avery North",
            email: "billing@northcoast.example",
            phone: "+49 555 0100",
            address: "1 Harbour Way",
            taxIdentifier: "DE123",
            economicIdentifier: "ECO123",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 45,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE00 1234",
            taxNote: "VAT exempt",
            defaultTermsDays: 14,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let client = ClientRecord(
            id: clientID,
            name: "Snapshot Client",
            email: "billing@snapshot.example",
            billingAddress: "1 Snapshot Way",
            defaultTermsDays: 21,
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Snapshot Project",
            currencyCode: "EUR",
            createdAt: issueDate,
            updatedAt: issueDate,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Ready Snapshot",
            statusRaw: BucketStatus.ready.rawValue,
            defaultHourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            project: project
        )
        let timeEntry = TimeEntryRecord(
            bucketID: bucketID,
            workDate: issueDate,
            durationMinutes: 60,
            descriptionText: "Billable work",
            isBillable: true,
            hourlyRateMinorUnits: 10_000,
            createdAt: issueDate,
            updatedAt: issueDate,
            bucket: bucket
        )
        modelContext.insert(profile)
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(timeEntry)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let staleInvoice = InvoiceRecord(
            id: existingInvoiceID,
            projectID: projectID,
            bucketID: bucketID,
            number: "NCS-2026-045",
            templateRaw: InvoiceTemplate.kleinunternehmerClassic.rawValue,
            issueDate: issueDate,
            dueDate: dueDate,
            servicePeriod: "May 2026",
            statusRaw: InvoiceStatus.finalized.rawValue,
            totalMinorUnits: 10_000,
            currencyCode: "EUR",
            note: "",
            businessName: "North Coast Studio",
            businessPersonName: "Avery North",
            businessEmail: "billing@northcoast.example",
            businessPhone: "+49 555 0100",
            businessAddress: "1 Harbour Way",
            businessTaxIdentifier: "DE123",
            businessEconomicIdentifier: "ECO123",
            businessPaymentDetails: "IBAN DE00 1234",
            businessTaxNote: "VAT exempt",
            clientName: "Snapshot Client",
            clientEmail: "billing@snapshot.example",
            clientBillingAddress: "1 Snapshot Way",
            projectName: "Snapshot Project",
            bucketName: "Ready Snapshot",
            createdAt: issueDate,
            updatedAt: issueDate,
            project: project,
            bucket: bucket
        )
        modelContext.insert(staleInvoice)
        try modelContext.save()

        #expect(throws: WorkspaceStoreError.persistenceConflict) {
            try store.finalizeInvoice(
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Snapshot Client",
                    recipientEmail: "billing@snapshot.example",
                    recipientBillingAddress: "1 Snapshot Way",
                    invoiceNumber: " NCS-2026-045 ",
                    template: .kleinunternehmerClassic,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                ),
                occurredAt: issueDate
            )
        }

        let reloadedProject = try #require(store.workspace.projects.first(where: { $0.id == projectID }))
        let reloadedBucket = try #require(reloadedProject.buckets.first(where: { $0.id == bucketID }))
        #expect(reloadedBucket.status == .ready)
        #expect(reloadedProject.invoices.map(\.number) == ["NCS-2026-045"])
    }

    @Test func persistentWorkspaceStoreSerializesDuplicateInvoiceNumbersAcrossContexts() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-workspace-\(UUID().uuidString)")
            .appendingPathComponent("workspace.store")
        let container = try WorkspaceStore.makeModelContainer(mode: .local, storeURL: storeURL)
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000616")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000616")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000616")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 6)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 20)
        let seededWorkspace = WorkspaceSnapshot(
            businessProfile: BusinessProfileProjection(
                businessName: "North Coast Studio",
                personName: "Avery North",
                email: "billing@northcoast.example",
                phone: "+49 555 0100",
                address: "1 Harbour Way",
                taxIdentifier: "DE123",
                economicIdentifier: "ECO123",
                invoicePrefix: "NCS",
                nextInvoiceNumber: 47,
                currencyCode: "EUR",
                paymentDetails: "IBAN DE00 1234",
                taxNote: "VAT exempt",
                defaultTermsDays: 14
            ),
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Snapshot Client",
                    email: "billing@snapshot.example",
                    billingAddress: "1 Snapshot Way",
                    defaultTermsDays: 21
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Snapshot Project",
                    clientName: "Snapshot Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Snapshot",
                            status: .ready,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            defaultHourlyRateMinorUnits: 10_000
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )

        _ = WorkspaceStore(
            seed: seededWorkspace,
            modelContext: ModelContext(container),
            resetForSeedImport: true
        )
        let firstStore = WorkspaceStore(seed: .empty, modelContext: ModelContext(container))
        let staleSecondStore = WorkspaceStore(seed: .empty, modelContext: ModelContext(container))
        #expect(staleSecondStore.workspace.projects.first?.buckets.first?.status == .ready)

        let draft = InvoiceFinalizationDraft(
            recipientName: "Snapshot Client",
            recipientEmail: "billing@snapshot.example",
            recipientBillingAddress: "1 Snapshot Way",
            invoiceNumber: " NCS-2026-047 ",
            template: .kleinunternehmerClassic,
            issueDate: issueDate,
            dueDate: dueDate,
            servicePeriod: "May 2026",
            currencyCode: "EUR",
            taxNote: ""
        )
        let firstInvoice = try firstStore.finalizeInvoice(
            projectID: projectID,
            bucketID: bucketID,
            draft: draft,
            occurredAt: issueDate
        )

        #expect(firstInvoice.number == "NCS-2026-047")
        #expect(throws: WorkspaceStoreError.persistenceConflict) {
            try staleSecondStore.finalizeInvoice(
                projectID: projectID,
                bucketID: bucketID,
                draft: draft,
                occurredAt: issueDate
            )
        }

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: ModelContext(container))
        let reloadedProject = try #require(reloadedStore.workspace.projects.first(where: { $0.id == projectID }))
        #expect(reloadedProject.invoices.map(\.number) == ["NCS-2026-047"])
        #expect(reloadedProject.buckets.first(where: { $0.id == bucketID })?.status == .finalized)
    }

    @Test func persistentWorkspaceStoreLoadsSavedWorkspaceOnRelaunch() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let initialStore = WorkspaceStore(
            seed: WorkspaceSnapshot(
                businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
                clients: [],
                projects: [],
                activity: []
            ),
            modelContext: modelContext
        )

        let client = try initialStore.createClient(WorkspaceClientDraft(
            name: "Persistent Client",
            email: "billing@persistent.example",
            billingAddress: "2 Saved Lane",
            defaultTermsDays: 21
        ))

        let relaunchedStore = WorkspaceStore(
            seed: WorkspaceFixtures.demoWorkspace,
            modelContext: modelContext
        )

        #expect(relaunchedStore.workspace.clients.map(\.id) == [client.id])
        #expect(relaunchedStore.workspace.clients.first?.name == "Persistent Client")
    }

    @Test func freshPersistentWorkspaceProjectionStartsWithBlankDefaultProfile() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)

        #expect(store.workspace.businessProfile == WorkspaceSnapshot.empty.businessProfile)
        #expect(store.workspace.clients.isEmpty)
        #expect(store.workspace.projects.isEmpty)
        #expect(store.workspace.activity.isEmpty)
    }

    @Test func persistentWorkspaceStoreBuildsProjectionFromNormalizedRecords() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009401")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009401")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009401")!
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000009401")!
        let lineItemID = UUID(uuidString: "50000000-0000-0000-0000-000000009401")!
        let workDate = Date.pikaDate(year: 2026, month: 4, day: 20)
        let issueDate = Date.pikaDate(year: 2026, month: 4, day: 25)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 9)

        let profile = BusinessProfileRecord(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000009401")!,
            businessName: "North Coast Studio",
            personName: "Avery North",
            email: "billing@northcoast.example",
            phone: "+49 555 0100",
            address: "1 Harbour Way",
            taxIdentifier: "DE123",
            economicIdentifier: "ECO123",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 12,
            currencyCode: "EUR",
            paymentDetails: "IBAN DE00 1234",
            taxNote: "VAT exempt",
            defaultTermsDays: 21,
            createdAt: workDate,
            updatedAt: workDate
        )
        let client = ClientRecord(
            id: clientID,
            name: "Summit Labs",
            email: "finance@summit.example",
            billingAddress: "9 Market Street",
            defaultTermsDays: 30,
            createdAt: workDate,
            updatedAt: workDate
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "API Delivery",
            currencyCode: "EUR",
            createdAt: workDate,
            updatedAt: workDate
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Sprint 1",
            statusRaw: BucketStatus.ready.rawValue,
            createdAt: workDate,
            updatedAt: workDate
        )
        let timeEntry = TimeEntryRecord(
            id: UUID(uuidString: "70000000-0000-0000-0000-000000009401")!,
            bucketID: bucketID,
            workDate: workDate,
            startMinuteOfDay: 9 * 60,
            endMinuteOfDay: 11 * 60,
            durationMinutes: 120,
            descriptionText: "Build endpoints",
            isBillable: true,
            hourlyRateMinorUnits: 6_000,
            createdAt: workDate,
            updatedAt: workDate
        )
        let fixedCost = FixedCostRecord(
            id: UUID(uuidString: "80000000-0000-0000-0000-000000009401")!,
            bucketID: bucketID,
            date: workDate,
            descriptionText: "API credits",
            quantity: 2,
            unitPriceMinorUnits: 5_000,
            isBillable: true,
            createdAt: workDate,
            updatedAt: workDate
        )
        let invoice = InvoiceRecord(
            id: invoiceID,
            projectID: projectID,
            bucketID: bucketID,
            number: "NCS-2026-011",
            issueDate: issueDate,
            dueDate: dueDate,
            servicePeriod: "Apr 2026",
            statusRaw: InvoiceStatus.finalized.rawValue,
            totalMinorUnits: 22_000,
            currencyCode: "EUR",
            note: "Thanks",
            businessName: "North Coast Studio",
            businessPersonName: "Avery North",
            businessEmail: "billing@northcoast.example",
            businessPhone: "+49 555 0100",
            businessAddress: "1 Harbour Way",
            businessTaxIdentifier: "DE123",
            businessEconomicIdentifier: "ECO123",
            businessPaymentDetails: "IBAN DE00 1234",
            businessTaxNote: "VAT exempt",
            clientName: "",
            clientEmail: "",
            clientBillingAddress: "",
            projectName: "",
            bucketName: "",
            createdAt: issueDate,
            updatedAt: issueDate
        )
        let lineItem = InvoiceLineItemRecord(
            id: lineItemID,
            invoiceID: invoiceID,
            sortOrder: 1,
            descriptionText: "Sprint 1 services",
            quantityLabel: "2h",
            amountMinorUnits: 12_000,
            createdAt: issueDate,
            updatedAt: issueDate
        )

        modelContext.insert(profile)
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(timeEntry)
        modelContext.insert(fixedCost)
        modelContext.insert(invoice)
        modelContext.insert(lineItem)
        try modelContext.save()

        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace, modelContext: modelContext)
        let projectedProject = try #require(store.workspace.projects.first)
        let projectedBucket = try #require(projectedProject.buckets.first)
        let projectedInvoice = try #require(projectedProject.invoices.first)

        #expect(store.workspace.businessProfile.businessName == "North Coast Studio")
        #expect(store.workspace.clients.map(\.name) == ["Summit Labs"])
        #expect(projectedProject.name == "API Delivery")
        #expect(projectedProject.clientID == clientID)
        #expect(projectedProject.clientName == "Summit Labs")
        #expect(projectedBucket.name == "Sprint 1")
        #expect(projectedBucket.billableMinutes == 120)
        #expect(projectedBucket.fixedCostMinorUnits == 10_000)
        #expect(projectedBucket.totalMinorUnits == 22_000)
        #expect(projectedInvoice.number == "NCS-2026-011")
        #expect(projectedInvoice.clientID == clientID)
        #expect(projectedInvoice.projectID == projectID)
        #expect(projectedInvoice.bucketID == bucketID)
        #expect(projectedInvoice.clientName == "Summit Labs")
        #expect(projectedInvoice.projectName == "API Delivery")
        #expect(projectedInvoice.bucketName == "Sprint 1")
        #expect(projectedInvoice.lineItems.map(\.id) == [lineItemID])
        #expect(store.workspace.activity.isEmpty)
    }

    @Test func persistentWorkspaceProjectionSortingIsDeterministic() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientAID = UUID(uuidString: "10000000-0000-0000-0000-000000009421")!
        let clientBID = UUID(uuidString: "10000000-0000-0000-0000-000000009422")!
        let projectAID = UUID(uuidString: "20000000-0000-0000-0000-000000009421")!
        let projectBID = UUID(uuidString: "20000000-0000-0000-0000-000000009422")!
        let createdAt = Date.pikaDate(year: 2026, month: 4, day: 22)

        modelContext.insert(ClientRecord(
            id: clientBID,
            name: "Zeta Client",
            email: "zeta@example.com",
            billingAddress: "2 Zeta Way",
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        modelContext.insert(ClientRecord(
            id: clientAID,
            name: "Alpha Client",
            email: "alpha@example.com",
            billingAddress: "1 Alpha Way",
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        modelContext.insert(ProjectRecord(
            id: projectBID,
            clientID: clientBID,
            name: "Zeta Project",
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        modelContext.insert(ProjectRecord(
            id: projectAID,
            clientID: clientAID,
            name: "Alpha Project",
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        modelContext.insert(BucketRecord(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000009422")!,
            projectID: projectAID,
            name: "Zeta Bucket",
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        modelContext.insert(BucketRecord(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000009421")!,
            projectID: projectAID,
            name: "Alpha Bucket",
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        try modelContext.save()

        let first = WorkspaceStore(seed: .empty, modelContext: modelContext).workspace
        let second = WorkspaceStore(seed: .empty, modelContext: modelContext).workspace

        #expect(first.clients.map(\.name) == ["Alpha Client", "Zeta Client"])
        #expect(first.projects.map(\.name) == ["Alpha Project", "Zeta Project"])
        #expect(first.projects.first?.buckets.map(\.name) == ["Alpha Bucket", "Zeta Bucket"])
        #expect(first == second)
    }
}
