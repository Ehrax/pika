import Foundation

extension WorkspaceStore {
    func validateImportedWorkspaceArchive(_ data: Data) throws -> WorkspaceArchiveImportSummary {
        try WorkspaceArchiveImportValidator.validateAndSummarize(data)
    }

    func importWorkspaceArchive(_ data: Data) throws -> WorkspaceArchiveImportSummary {
        try importWorkspaceArchive(data) {
            _ = try WorkspaceArchiveActions.writePreImportBackup(workspaceStore: self)
        }
    }

    func importWorkspaceArchive(
        _ data: Data,
        createPreImportBackup: () throws -> Void
    ) throws -> WorkspaceArchiveImportSummary {
        let envelope = try WorkspaceArchiveCodec.decode(data)
        let summary = try WorkspaceArchiveImportValidator.validateAndSummarize(envelope)
        let replacementWorkspace = try Self.workspaceSnapshot(from: envelope.workspace)
        let priorWorkspace = workspace

        try createPreImportBackup()

        do {
            try replacePersistentWorkspaceWithSeedImport(replacementWorkspace)
            workspace = Self.normalizedImportedWorkspace(replacementWorkspace)
            return summary
        } catch {
            workspace = priorWorkspace
            throw error
        }
    }

    private static func normalizedImportedWorkspace(_ snapshot: WorkspaceSnapshot) -> WorkspaceSnapshot {
        var importedWorkspace = snapshot
        importedWorkspace.activity = []
        importedWorkspace.normalizeMissingHourlyRates()
        return importedWorkspace
    }

    private static func workspaceSnapshot(from archiveWorkspace: WorkspaceArchiveV1Workspace) throws -> WorkspaceSnapshot {
        let businessProfile = BusinessProfileProjection(
            businessName: archiveWorkspace.businessProfile.businessName,
            personName: archiveWorkspace.businessProfile.personName,
            email: archiveWorkspace.businessProfile.email,
            phone: archiveWorkspace.businessProfile.phone,
            address: archiveWorkspace.businessProfile.address,
            taxIdentifier: archiveWorkspace.businessProfile.taxIdentifier,
            economicIdentifier: archiveWorkspace.businessProfile.economicIdentifier,
            countryCode: "",
            invoicePrefix: archiveWorkspace.businessProfile.invoicePrefix,
            nextInvoiceNumber: archiveWorkspace.businessProfile.nextInvoiceNumber,
            currencyCode: archiveWorkspace.businessProfile.currencyCode,
            paymentDetails: archiveWorkspace.businessProfile.paymentDetails,
            paymentMethods: archiveWorkspace.businessProfile.paymentMethods,
            defaultPaymentMethodID: archiveWorkspace.businessProfile.defaultPaymentMethodID,
            taxNote: archiveWorkspace.businessProfile.taxNote,
            defaultTermsDays: archiveWorkspace.businessProfile.defaultTermsDays,
            senderTaxLegalFields: archiveWorkspace.businessProfile.senderTaxLegalFields
        )

        let clients = archiveWorkspace.clients.map { client in
            WorkspaceClient(
                id: client.id,
                name: client.name,
                email: client.email,
                billingAddress: client.billingAddress,
                defaultTermsDays: client.defaultTermsDays,
                preferredPaymentMethodID: client.preferredPaymentMethodID,
                isArchived: client.isArchived
                ,
                recipientTaxLegalFields: client.recipientTaxLegalFields
            )
        }
        let clientNameByID = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.name) })
        let bucketsByProjectID = Dictionary(grouping: archiveWorkspace.buckets, by: \.projectID)
        let timeEntriesByBucketID = Dictionary(grouping: archiveWorkspace.timeEntries, by: \.bucketID)
        let fixedCostsByBucketID = Dictionary(grouping: archiveWorkspace.fixedCosts, by: \.bucketID)
        let invoicesByProjectID = Dictionary(grouping: archiveWorkspace.invoices, by: \.projectID)
        let lineItemsByInvoiceID = Dictionary(grouping: archiveWorkspace.invoiceLineItems, by: \.invoiceID)

        let projects = try archiveWorkspace.projects.map { archiveProject in
            let buckets = try (bucketsByProjectID[archiveProject.id] ?? []).map { archiveBucket in
                let timeEntries = try sortedArchiveTimeEntries(
                    timeEntriesByBucketID[archiveBucket.id] ?? []
                ).map { archiveEntry in
                    let durationMinutes = max(archiveEntry.durationMinutes, 0)
                    return WorkspaceTimeEntry(
                        id: archiveEntry.id,
                        date: try dateOnly(archiveEntry.date, field: "workspace.timeEntries.date"),
                        startTime: timeEntryStartLabel(
                            startMinuteOfDay: archiveEntry.startMinuteOfDay,
                            endMinuteOfDay: archiveEntry.endMinuteOfDay,
                            durationMinutes: durationMinutes
                        ),
                        endTime: minuteOfDayLabel(archiveEntry.endMinuteOfDay),
                        durationMinutes: durationMinutes,
                        description: archiveEntry.description,
                        isBillable: archiveEntry.isBillable,
                        hourlyRateMinorUnits: max(archiveEntry.hourlyRateMinorUnits, 0)
                    )
                }
                let fixedCosts = try sortedArchiveFixedCosts(
                    fixedCostsByBucketID[archiveBucket.id] ?? []
                ).map { archiveCost in
                    WorkspaceFixedCostEntry(
                        id: archiveCost.id,
                        date: try dateOnly(archiveCost.date, field: "workspace.fixedCosts.date"),
                        description: archiveCost.description,
                        amountMinorUnits: max(archiveCost.amountMinorUnits, 0)
                    )
                }

                let billableMinutes = timeEntries.filter(\.isBillable).map(\.durationMinutes).reduce(0, +)
                let nonBillableMinutes = timeEntries.filter { !$0.isBillable }.map(\.durationMinutes).reduce(0, +)
                let fixedCostMinorUnits = fixedCosts.map(\.amountMinorUnits).reduce(0, +)
                let billableTimeMinorUnits = timeEntries.map(\.billableAmountMinorUnits).reduce(0, +)

                return WorkspaceBucket(
                    id: archiveBucket.id,
                    name: archiveBucket.name,
                    status: bucketStatus(archiveBucket.status),
                    billingMode: archiveBucket.billingMode,
                    totalMinorUnits: billableTimeMinorUnits + fixedCostMinorUnits,
                    billableMinutes: billableMinutes,
                    fixedCostMinorUnits: fixedCostMinorUnits,
                    nonBillableMinutes: nonBillableMinutes,
                    defaultHourlyRateMinorUnits: archiveBucket.defaultHourlyRateMinorUnits,
                    fixedAmountMinorUnits: archiveBucket.fixedAmountMinorUnits > 0
                        ? archiveBucket.fixedAmountMinorUnits
                        : nil,
                    retainerAmountMinorUnits: archiveBucket.retainerAmountMinorUnits > 0
                        ? archiveBucket.retainerAmountMinorUnits
                        : nil,
                    retainerPeriodLabel: archiveBucket.retainerPeriodLabel,
                    retainerIncludedMinutes: archiveBucket.retainerIncludedMinutes,
                    retainerOverageRateMinorUnits: archiveBucket.retainerOverageRateMinorUnits > 0
                        ? archiveBucket.retainerOverageRateMinorUnits
                        : nil,
                    timeEntries: timeEntries,
                    fixedCostEntries: fixedCosts
                )
            }

            let bucketsByID = Dictionary(uniqueKeysWithValues: buckets.map { ($0.id, $0) })
            let invoices = try sortedArchiveInvoices(invoicesByProjectID[archiveProject.id] ?? []).map { archiveInvoice in
                let lineItems = sortedArchiveInvoiceLineItems(
                    lineItemsByInvoiceID[archiveInvoice.id] ?? []
                ).map { lineItem in
                    WorkspaceInvoiceLineItemSnapshot(
                        id: lineItem.id,
                        description: lineItem.description,
                        quantityLabel: lineItem.quantityLabel,
                        amountMinorUnits: max(lineItem.amountMinorUnits, 0)
                    )
                }
                let projectName = archiveProject.name
                let bucketName = bucketsByID[archiveInvoice.bucketID]?.name ?? ""
                let template = try invoiceTemplate(archiveInvoice.template)

                return WorkspaceInvoice(
                    id: archiveInvoice.id,
                    number: archiveInvoice.number,
                    businessSnapshot: BusinessProfileProjection(
                        businessName: archiveInvoice.businessSnapshot.businessName,
                        personName: archiveInvoice.businessSnapshot.personName,
                        email: archiveInvoice.businessSnapshot.email,
                        phone: archiveInvoice.businessSnapshot.phone,
                        address: archiveInvoice.businessSnapshot.address,
                        taxIdentifier: archiveInvoice.businessSnapshot.taxIdentifier,
                        economicIdentifier: archiveInvoice.businessSnapshot.economicIdentifier,
                        countryCode: "",
                        invoicePrefix: businessProfile.invoicePrefix,
                        nextInvoiceNumber: businessProfile.nextInvoiceNumber,
                        currencyCode: archiveInvoice.currencyCode,
                        paymentDetails: archiveInvoice.businessSnapshot.paymentDetails,
                        paymentMethods: [],
                        defaultPaymentMethodID: nil,
                        taxNote: archiveInvoice.businessSnapshot.taxNote,
                        defaultTermsDays: businessProfile.defaultTermsDays,
                        senderTaxLegalFields: archiveInvoice.businessSnapshot.senderTaxLegalFields
                    ),
                    clientSnapshot: WorkspaceClient(
                        id: archiveProject.clientID,
                        name: archiveInvoice.clientSnapshot.name,
                        email: archiveInvoice.clientSnapshot.email,
                        billingAddress: archiveInvoice.clientSnapshot.billingAddress,
                        defaultTermsDays: businessProfile.defaultTermsDays,
                        isArchived: false,
                        recipientTaxLegalFields: archiveInvoice.clientSnapshot.recipientTaxLegalFields
                    ),
                    clientID: archiveProject.clientID,
                    clientName: archiveInvoice.clientSnapshot.name,
                    projectID: archiveInvoice.projectID,
                    projectName: projectName,
                    bucketID: archiveInvoice.bucketID,
                    bucketName: bucketName,
                    template: template,
                    issueDate: try dateOnly(archiveInvoice.issueDate, field: "workspace.invoices.issueDate"),
                    dueDate: try dateOnly(archiveInvoice.dueDate, field: "workspace.invoices.dueDate"),
                    servicePeriod: archiveInvoice.servicePeriod,
                    status: invoiceStatus(archiveInvoice.status),
                    totalMinorUnits: max(archiveInvoice.totalMinorUnits, 0),
                    lineItems: lineItems,
                    currencyCode: archiveInvoice.currencyCode,
                    selectedPaymentMethodSnapshot: archiveInvoice.businessSnapshot.selectedPaymentMethod,
                    note: archiveInvoice.note
                )
            }

            return WorkspaceProject(
                id: archiveProject.id,
                clientID: archiveProject.clientID,
                name: archiveProject.name,
                clientName: clientNameByID[archiveProject.clientID] ?? "",
                currencyCode: archiveProject.currencyCode,
                isArchived: archiveProject.isArchived,
                buckets: buckets,
                invoices: invoices
            )
        }

        return WorkspaceSnapshot(
            onboardingCompleted: archiveWorkspace.onboardingCompleted,
            businessProfile: businessProfile,
            clients: clients,
            projects: projects,
            activity: []
        )
    }

    private static func bucketStatus(_ archiveStatus: WorkspaceArchiveBucketStatus) -> BucketStatus {
        switch archiveStatus {
        case .open:
            return .open
        case .ready:
            return .ready
        case .finalized:
            return .finalized
        case .archived:
            return .archived
        }
    }

    private static func invoiceStatus(_ archiveStatus: WorkspaceArchiveInvoiceStatus) -> InvoiceStatus {
        switch archiveStatus {
        case .finalized:
            return .finalized
        case .sent:
            return .sent
        case .paid:
            return .paid
        case .cancelled:
            return .cancelled
        }
    }

    private static func invoiceTemplate(_ rawValue: String) throws -> InvoiceTemplate {
        guard let template = InvoiceTemplate(rawValue: rawValue) else {
            throw WorkspaceArchiveImportError.invalidInvoiceTemplate(rawValue)
        }
        return template
    }

    private static func dateOnly(_ value: String, field: String) throws -> Date {
        guard let date = WorkspaceArchiveDateCoding.date(fromDateOnly: value) else {
            throw WorkspaceArchiveError.invalidDate(field: field, value: value)
        }
        return date
    }

    private static func sortedArchiveTimeEntries(_ entries: [WorkspaceArchiveV1Workspace.TimeEntry]) -> [WorkspaceArchiveV1Workspace.TimeEntry] {
        entries.sorted { left, right in
            if left.date != right.date {
                return left.date < right.date
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func sortedArchiveFixedCosts(_ fixedCosts: [WorkspaceArchiveV1Workspace.FixedCost]) -> [WorkspaceArchiveV1Workspace.FixedCost] {
        fixedCosts.sorted { left, right in
            if left.date != right.date {
                return left.date < right.date
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func sortedArchiveInvoices(_ invoices: [WorkspaceArchiveV1Workspace.Invoice]) -> [WorkspaceArchiveV1Workspace.Invoice] {
        invoices.sorted { left, right in
            if left.issueDate != right.issueDate {
                return left.issueDate < right.issueDate
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func sortedArchiveInvoiceLineItems(
        _ lineItems: [WorkspaceArchiveV1Workspace.InvoiceLineItem]
    ) -> [WorkspaceArchiveV1Workspace.InvoiceLineItem] {
        lineItems.sorted { left, right in
            if left.sortOrder != right.sortOrder {
                return left.sortOrder < right.sortOrder
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func timeEntryStartLabel(
        startMinuteOfDay: Int?,
        endMinuteOfDay: Int?,
        durationMinutes: Int
    ) -> String {
        let startLabel = minuteOfDayLabel(startMinuteOfDay)
        let endLabel = minuteOfDayLabel(endMinuteOfDay)
        if !startLabel.isEmpty || !endLabel.isEmpty {
            return startLabel
        }
        return durationInputLabel(minutes: durationMinutes)
    }

    private static func minuteOfDayLabel(_ minuteOfDay: Int?) -> String {
        guard let minuteOfDay else { return "" }
        let hours = minuteOfDay / 60
        let minutes = minuteOfDay % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private static func durationInputLabel(minutes: Int) -> String {
        guard minutes > 0 else { return "" }
        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60)h"
        }
        if minutes.isMultiple(of: 30) {
            return String(format: "%.1fh", locale: Locale(identifier: "en_US_POSIX"), Double(minutes) / 60)
        }
        return "\(minutes)m"
    }
}
