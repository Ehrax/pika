import Foundation
import SwiftData

enum SwiftDataWorkspaceSeedImporter {
    private static let deterministicImportTimestamp = Date(timeIntervalSince1970: 0)

    private struct ClientRecordLookup {
        var byID: [UUID: ClientRecord] = [:]
        var byName: [String: ClientRecord] = [:]

        mutating func insert(_ record: ClientRecord) {
            byID[record.id] = record
            byName[SwiftDataWorkspaceSeedImporter.normalizedNameKey(record.name)] = record
        }
    }

    static func replacePersistentWorkspaceWithSeedImport(
        _ snapshot: WorkspaceSnapshot,
        in context: ModelContext
    ) throws {
        try clearWorkspaceRecords(from: context)
        try persistNormalizedWorkspace(snapshot, into: context)
        try context.save()
    }

    private static func clearWorkspaceRecords(from context: ModelContext) throws {
        try deleteAll(FetchDescriptor<BusinessProfileRecord>(), from: context)
        try deleteAll(FetchDescriptor<ClientRecord>(), from: context)
        try deleteAll(FetchDescriptor<ProjectRecord>(), from: context)
        try deleteAll(FetchDescriptor<BucketRecord>(), from: context)
        try deleteAll(FetchDescriptor<TimeEntryRecord>(), from: context)
        try deleteAll(FetchDescriptor<FixedCostRecord>(), from: context)
        try deleteAll(FetchDescriptor<InvoiceLineItemRecord>(), from: context)
        try deleteAll(FetchDescriptor<InvoiceRecord>(), from: context)
    }

    private static func deleteAll<Record: PersistentModel>(
        _ descriptor: FetchDescriptor<Record>,
        from context: ModelContext
    ) throws {
        let records = try context.fetch(descriptor)
        for record in records {
            context.delete(record)
        }
    }

    private static func persistNormalizedWorkspace(_ snapshot: WorkspaceSnapshot, into context: ModelContext) throws {
        let importedAt = deterministicImportTimestamp

        let profile = snapshot.businessProfile
        persistBusinessProfile(
            profile,
            onboardingCompleted: snapshot.onboardingCompleted,
            importedAt: importedAt,
            into: context
        )

        var clientLookup = persistClients(snapshot.clients, importedAt: importedAt, into: context)

        for project in snapshot.projects {
            let projectRecord = persistProject(
                project,
                profile: profile,
                clientLookup: &clientLookup,
                importedAt: importedAt,
                into: context
            )
            let bucketIDsByName = persistBuckets(
                project.buckets,
                projectID: project.id,
                projectRecord: projectRecord,
                importedAt: importedAt,
                into: context
            )
            persistInvoices(
                project.invoices,
                project: project,
                projectRecord: projectRecord,
                bucketIDsByName: bucketIDsByName,
                into: context
            )
        }
    }

    private static func persistBusinessProfile(
        _ profile: BusinessProfileProjection,
        onboardingCompleted: Bool,
        importedAt: Date,
        into context: ModelContext
    ) {
        context.insert(BusinessProfileRecord(
            businessName: profile.businessName,
            personName: profile.personName,
            email: profile.email,
            phone: profile.phone,
            address: profile.address,
            taxIdentifier: profile.taxIdentifier,
            economicIdentifier: profile.economicIdentifier,
            countryCode: profile.countryCode,
            senderTaxLegalFieldsData: SenderTaxLegalFieldCoding.encode(profile.senderTaxLegalFields),
            invoicePrefix: profile.invoicePrefix,
            nextInvoiceNumber: profile.nextInvoiceNumber,
            currencyCode: profile.currencyCode,
            paymentDetails: profile.paymentDetails,
            paymentMethodsData: PaymentMethodCoding.encode(profile.paymentMethods),
            defaultPaymentMethodIDString: profile.defaultPaymentMethodID?.uuidString ?? "",
            taxNote: profile.taxNote,
            defaultTermsDays: profile.defaultTermsDays,
            onboardingCompleted: onboardingCompleted,
            createdAt: importedAt,
            updatedAt: importedAt
        ))
    }

    private static func persistClients(
        _ clients: [WorkspaceClient],
        importedAt: Date,
        into context: ModelContext
    ) -> ClientRecordLookup {
        var lookup = ClientRecordLookup()
        for client in clients {
            let record = ClientRecord(
                id: client.id,
                name: client.name,
                email: client.email,
                billingAddress: client.billingAddress,
                defaultTermsDays: client.defaultTermsDays,
                recipientTaxLegalFieldsData: SenderTaxLegalFieldCoding.encode(client.recipientTaxLegalFields),
                isArchived: client.isArchived,
                createdAt: importedAt,
                updatedAt: importedAt
            )
            context.insert(record)
            lookup.insert(record)
        }

        return lookup
    }

    private static func persistProject(
        _ project: WorkspaceProject,
        profile: BusinessProfileProjection,
        clientLookup: inout ClientRecordLookup,
        importedAt: Date,
        into context: ModelContext
    ) -> ProjectRecord {
        let resolvedClientRecord = resolveClientRecord(
            for: project,
            profile: profile,
            importedAt: importedAt,
            clientLookup: &clientLookup,
            into: context
        )
        let projectRecord = ProjectRecord(
            id: project.id,
            clientID: resolvedClientRecord.id,
            name: project.name,
            currencyCode: project.currencyCode,
            isArchived: project.isArchived,
            createdAt: importedAt,
            updatedAt: importedAt,
            client: resolvedClientRecord
        )
        context.insert(projectRecord)
        return projectRecord
    }

    private static func resolveClientRecord(
        for project: WorkspaceProject,
        profile: BusinessProfileProjection,
        importedAt: Date,
        clientLookup: inout ClientRecordLookup,
        into context: ModelContext
    ) -> ClientRecord {
        let normalizedClientName = normalizedNameKey(project.clientName)
        if let clientID = project.clientID,
           let existing = clientLookup.byID[clientID]
        {
            return existing
        }

        if let existing = clientLookup.byName[normalizedClientName] {
            return existing
        }

        let synthesizedClientID = project.clientID ?? project.id
        let synthesizedClient = ClientRecord(
            id: synthesizedClientID,
            name: project.clientName,
            email: "",
            billingAddress: "",
            defaultTermsDays: profile.defaultTermsDays,
            recipientTaxLegalFieldsData: "[]",
            isArchived: false,
            createdAt: importedAt,
            updatedAt: importedAt
        )
        context.insert(synthesizedClient)
        clientLookup.insert(synthesizedClient)
        return synthesizedClient
    }

    private static func persistBuckets(
        _ buckets: [WorkspaceBucket],
        projectID: UUID,
        projectRecord: ProjectRecord,
        importedAt: Date,
        into context: ModelContext
    ) -> [String: UUID] {
        var bucketIDsByName: [String: UUID] = [:]
        for bucket in buckets {
            let bucketRecord = BucketRecord(
                id: bucket.id,
                projectID: projectID,
                name: bucket.name,
                statusRaw: bucket.status.rawValue,
                billingModeRaw: bucket.billingMode.rawValue,
                defaultHourlyRateMinorUnits: bucket.billingMode == .hourly
                    ? bucket.defaultHourlyRateMinorUnits ?? 0
                    : 0,
                fixedAmountMinorUnits: bucket.billingMode == .fixed
                    ? bucket.effectiveFixedAmountMinorUnits
                    : 0,
                retainerAmountMinorUnits: bucket.billingMode == .retainer
                    ? bucket.effectiveRetainerAmountMinorUnits
                    : 0,
                retainerPeriodLabel: bucket.billingMode == .retainer ? bucket.retainerPeriodLabel : "",
                retainerIncludedMinutes: bucket.billingMode == .retainer ? bucket.retainerIncludedMinutes : nil,
                retainerOverageRateMinorUnits: bucket.billingMode == .retainer
                    ? bucket.retainerOverageRateMinorUnits ?? 0
                    : 0,
                createdAt: importedAt,
                updatedAt: importedAt,
                project: projectRecord
            )
            context.insert(bucketRecord)
            bucketIDsByName[normalizedNameKey(bucket.name)] = bucket.id
            persistBucketRows(
                for: bucket,
                bucketRecord: bucketRecord,
                importedAt: importedAt,
                into: context
            )
        }

        return bucketIDsByName
    }

    private static func persistBucketRows(
        for bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        importedAt: Date,
        into context: ModelContext
    ) {
        guard bucket.billingMode != .fixed else { return }

        if bucket.hasRowLevelEntries {
            persistTimeEntries(
                bucket.timeEntries,
                bucket: bucket,
                bucketRecord: bucketRecord,
                into: context
            )
            persistFixedCosts(
                bucket.fixedCostEntries,
                bucket: bucket,
                bucketRecord: bucketRecord,
                into: context
            )
        } else {
            persistLegacyAggregateRows(
                for: bucket,
                bucketRecord: bucketRecord,
                importedAt: importedAt,
                into: context
            )
        }
    }

    private static func persistTimeEntries(
        _ entries: [WorkspaceTimeEntry],
        bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        into context: ModelContext
    ) {
        for entry in entries {
            context.insert(TimeEntryRecord(
                id: entry.id,
                bucketID: bucket.id,
                workDate: entry.date,
                startMinuteOfDay: minuteOfDay(from: entry.startTime),
                endMinuteOfDay: minuteOfDay(from: entry.endTime),
                durationMinutes: max(entry.durationMinutes, 0),
                descriptionText: entry.description,
                isBillable: entry.isBillable,
                hourlyRateMinorUnits: max(entry.hourlyRateMinorUnits, 0),
                createdAt: entry.date,
                updatedAt: entry.date,
                bucket: bucketRecord
            ))
        }
    }

    private static func persistFixedCosts(
        _ fixedCosts: [WorkspaceFixedCostEntry],
        bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        into context: ModelContext
    ) {
        for fixedCost in fixedCosts {
            context.insert(FixedCostRecord(
                id: fixedCost.id,
                bucketID: bucket.id,
                date: fixedCost.date,
                descriptionText: fixedCost.description,
                quantity: 1,
                unitPriceMinorUnits: max(fixedCost.amountMinorUnits, 0),
                isBillable: true,
                createdAt: fixedCost.date,
                updatedAt: fixedCost.date,
                bucket: bucketRecord
            ))
        }
    }

    private static func persistInvoices(
        _ invoices: [WorkspaceInvoice],
        project: WorkspaceProject,
        projectRecord: ProjectRecord,
        bucketIDsByName: [String: UUID],
        into context: ModelContext
    ) {
        for invoice in invoices {
            let bucketID = resolvedBucketID(
                for: invoice,
                in: project,
                bucketIDsByName: bucketIDsByName
            )
            let invoiceRecord = InvoiceRecord(
                id: invoice.id,
                projectID: project.id,
                bucketID: bucketID,
                number: invoice.number,
                templateRaw: invoice.template.rawValue,
                issueDate: invoice.issueDate,
                dueDate: invoice.dueDate,
                servicePeriod: invoice.servicePeriod,
                statusRaw: invoice.status.rawValue,
                totalMinorUnits: invoice.totalMinorUnits,
                currencyCode: invoice.currencyCode.isEmpty ? project.currencyCode : invoice.currencyCode,
                note: invoice.note ?? "",
                businessName: invoice.businessSnapshot?.businessName ?? "",
                businessPersonName: invoice.businessSnapshot?.personName ?? "",
                businessEmail: invoice.businessSnapshot?.email ?? "",
                businessPhone: invoice.businessSnapshot?.phone ?? "",
                businessAddress: invoice.businessSnapshot?.address ?? "",
                businessTaxIdentifier: invoice.businessSnapshot?.taxIdentifier ?? "",
                businessEconomicIdentifier: invoice.businessSnapshot?.economicIdentifier ?? "",
                businessPaymentDetails: invoice.businessSnapshot?.paymentDetails ?? "",
                businessTaxNote: invoice.businessSnapshot?.taxNote ?? "",
                clientName: invoiceSnapshotClientName(for: invoice),
                clientEmail: invoice.clientSnapshot?.email ?? "",
                clientBillingAddress: invoice.clientSnapshot?.billingAddress ?? "",
                projectName: invoice.projectName.isEmpty ? project.name : invoice.projectName,
                bucketName: invoice.bucketName,
                createdAt: invoice.issueDate,
                updatedAt: invoice.issueDate
            )
            invoiceRecord.project = projectRecord
            invoiceRecord.bucket = nil
            context.insert(invoiceRecord)

            persistInvoiceLineItems(
                invoice.lineItems,
                invoice: invoice,
                invoiceRecord: invoiceRecord,
                into: context
            )
        }
    }

    private static func persistInvoiceLineItems(
        _ lineItems: [WorkspaceInvoiceLineItemSnapshot],
        invoice: WorkspaceInvoice,
        invoiceRecord: InvoiceRecord,
        into context: ModelContext
    ) {
        for (lineItemIndex, lineItem) in lineItems.enumerated() {
            context.insert(InvoiceLineItemRecord(
                id: lineItem.id,
                invoiceID: invoice.id,
                sortOrder: lineItemIndex,
                descriptionText: lineItem.description,
                quantityLabel: lineItem.quantityLabel,
                amountMinorUnits: lineItem.amountMinorUnits,
                createdAt: invoice.issueDate,
                updatedAt: invoice.issueDate,
                invoice: invoiceRecord
            ))
        }
    }

    private static func resolvedBucketID(
        for invoice: WorkspaceInvoice,
        in project: WorkspaceProject,
        bucketIDsByName: [String: UUID]
    ) -> UUID {
        if let bucketID = invoice.bucketID {
            return bucketID
        }

        if let bucketID = bucketIDsByName[normalizedNameKey(invoice.bucketName)] {
            return bucketID
        }

        if let bucketID = project.buckets.first?.id {
            return bucketID
        }

        return UUID()
    }

    private static func invoiceSnapshotClientName(for invoice: WorkspaceInvoice) -> String {
        if let clientSnapshotName = invoice.clientSnapshot?.name, !clientSnapshotName.isEmpty {
            return clientSnapshotName
        }

        return invoice.clientName
    }

    private static func persistLegacyAggregateRows(
        for bucket: WorkspaceBucket,
        bucketRecord: BucketRecord,
        importedAt: Date,
        into context: ModelContext
    ) {
        let billableMinorUnits = max(bucket.totalMinorUnits - bucket.fixedCostMinorUnits, 0)
        if bucket.billableMinutes > 0 {
            let inferredRate = bucket.hourlyRateMinorUnits
                ?? billableMinorUnits * 60 / bucket.billableMinutes
            context.insert(TimeEntryRecord(
                id: derivedUUID(from: bucket.id, variant: 1),
                bucketID: bucket.id,
                workDate: importedAt,
                startMinuteOfDay: nil,
                endMinuteOfDay: nil,
                durationMinutes: bucket.billableMinutes,
                descriptionText: "Imported billable time",
                isBillable: true,
                hourlyRateMinorUnits: max(inferredRate, 0),
                createdAt: importedAt,
                updatedAt: importedAt,
                bucket: bucketRecord
            ))
        }

        if bucket.nonBillableMinutes > 0 {
            context.insert(TimeEntryRecord(
                id: derivedUUID(from: bucket.id, variant: 2),
                bucketID: bucket.id,
                workDate: importedAt,
                startMinuteOfDay: nil,
                endMinuteOfDay: nil,
                durationMinutes: bucket.nonBillableMinutes,
                descriptionText: "Imported non-billable time",
                isBillable: false,
                hourlyRateMinorUnits: max(bucket.hourlyRateMinorUnits ?? 0, 0),
                createdAt: importedAt,
                updatedAt: importedAt,
                bucket: bucketRecord
            ))
        }

        if bucket.fixedCostMinorUnits > 0 {
            context.insert(FixedCostRecord(
                id: derivedUUID(from: bucket.id, variant: 3),
                bucketID: bucket.id,
                date: importedAt,
                descriptionText: "Imported Fixed Charges",
                quantity: 1,
                unitPriceMinorUnits: bucket.fixedCostMinorUnits,
                isBillable: true,
                createdAt: importedAt,
                updatedAt: importedAt,
                bucket: bucketRecord
            ))
        }
    }

    private static func minuteOfDay(from label: String) -> Int? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 5 else { return nil }

        let components = trimmed.split(separator: ":")
        guard components.count == 2,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              (0 ... 23).contains(hours),
              (0 ... 59).contains(minutes)
        else {
            return nil
        }

        return hours * 60 + minutes
    }

    private static func normalizedNameKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func derivedUUID(from base: UUID, variant: UInt8) -> UUID {
        var raw = base.uuid
        withUnsafeMutableBytes(of: &raw) { bytes in
            bytes[15] ^= variant
            bytes[14] ^= 0xA5
        }
        return UUID(uuid: raw)
    }
}
