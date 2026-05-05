import Foundation

struct WorkspaceArchiveImportSummary: Equatable {
    var clientCount: Int
    var projectCount: Int
    var bucketCount: Int
    var timeEntryCount: Int
    var fixedCostCount: Int
    var invoiceCount: Int
}

enum WorkspaceArchiveImportError: Error, Equatable {
    case duplicateEntityID(entity: String, id: UUID)
    case missingRelationship(entity: String, id: UUID, relationship: String, targetID: UUID)
    case inconsistentRelationship(entity: String, id: UUID, relationship: String, targetID: UUID)
    case invalidCurrencyCode(field: String, value: String)
    case invalidMoneyValue(field: String, value: Int)
    case invalidTermsDays(field: String, value: Int)
    case invalidInvoiceTemplate(String)
    case duplicateInvoiceNumber(String)
    case invoiceTotalMismatch(invoiceID: UUID, expected: Int, actual: Int)
}

enum WorkspaceArchiveImportValidator {
    static func validateAndSummarize(_ data: Data) throws -> WorkspaceArchiveImportSummary {
        let envelope = try WorkspaceArchiveCodec.decode(data)
        return try validateAndSummarize(envelope)
    }

    static func validateAndSummarize(_ envelope: WorkspaceArchiveEnvelope) throws -> WorkspaceArchiveImportSummary {
        let workspace = envelope.workspace
        try validateUniqueIDs(in: workspace)
        try validateRelationships(in: workspace)
        try validateCurrencies(in: workspace)
        try validateInvoiceTemplates(in: workspace)
        try validateMoneyAndAccounting(in: workspace)
        try validateInvoiceNumbers(in: workspace)

        return WorkspaceArchiveImportSummary(
            clientCount: workspace.clients.count,
            projectCount: workspace.projects.count,
            bucketCount: workspace.buckets.count,
            timeEntryCount: workspace.timeEntries.count,
            fixedCostCount: workspace.fixedCosts.count,
            invoiceCount: workspace.invoices.count
        )
    }

    private static func validateUniqueIDs(in workspace: WorkspaceArchiveV1Workspace) throws {
        try ensureUnique(workspace.clients.map(\.id), entity: "client")
        try ensureUnique(workspace.projects.map(\.id), entity: "project")
        try ensureUnique(workspace.buckets.map(\.id), entity: "bucket")
        try ensureUnique(workspace.timeEntries.map(\.id), entity: "timeEntry")
        try ensureUnique(workspace.fixedCosts.map(\.id), entity: "fixedCost")
        try ensureUnique(workspace.invoices.map(\.id), entity: "invoice")
        try ensureUnique(workspace.invoiceLineItems.map(\.id), entity: "invoiceLineItem")
    }

    private static func validateRelationships(in workspace: WorkspaceArchiveV1Workspace) throws {
        let clientIDs = Set(workspace.clients.map(\.id))
        let projectIDs = Set(workspace.projects.map(\.id))
        let bucketIDs = Set(workspace.buckets.map(\.id))
        let bucketProjectIDByID = Dictionary(uniqueKeysWithValues: workspace.buckets.map { ($0.id, $0.projectID) })
        let invoiceIDs = Set(workspace.invoices.map(\.id))

        for project in workspace.projects where !clientIDs.contains(project.clientID) {
            throw WorkspaceArchiveImportError.missingRelationship(
                entity: "project",
                id: project.id,
                relationship: "clientID",
                targetID: project.clientID
            )
        }

        for bucket in workspace.buckets where !projectIDs.contains(bucket.projectID) {
            throw WorkspaceArchiveImportError.missingRelationship(
                entity: "bucket",
                id: bucket.id,
                relationship: "projectID",
                targetID: bucket.projectID
            )
        }

        for entry in workspace.timeEntries where !bucketIDs.contains(entry.bucketID) {
            throw WorkspaceArchiveImportError.missingRelationship(
                entity: "timeEntry",
                id: entry.id,
                relationship: "bucketID",
                targetID: entry.bucketID
            )
        }

        for fixedCost in workspace.fixedCosts where !bucketIDs.contains(fixedCost.bucketID) {
            throw WorkspaceArchiveImportError.missingRelationship(
                entity: "fixedCost",
                id: fixedCost.id,
                relationship: "bucketID",
                targetID: fixedCost.bucketID
            )
        }

        for invoice in workspace.invoices {
            if !projectIDs.contains(invoice.projectID) {
                throw WorkspaceArchiveImportError.missingRelationship(
                    entity: "invoice",
                    id: invoice.id,
                    relationship: "projectID",
                    targetID: invoice.projectID
                )
            }

            if !bucketIDs.contains(invoice.bucketID) {
                throw WorkspaceArchiveImportError.missingRelationship(
                    entity: "invoice",
                    id: invoice.id,
                    relationship: "bucketID",
                    targetID: invoice.bucketID
                )
            }

            if bucketProjectIDByID[invoice.bucketID] != invoice.projectID {
                throw WorkspaceArchiveImportError.inconsistentRelationship(
                    entity: "invoice",
                    id: invoice.id,
                    relationship: "bucketID",
                    targetID: invoice.bucketID
                )
            }
        }

        for lineItem in workspace.invoiceLineItems where !invoiceIDs.contains(lineItem.invoiceID) {
            throw WorkspaceArchiveImportError.missingRelationship(
                entity: "invoiceLineItem",
                id: lineItem.id,
                relationship: "invoiceID",
                targetID: lineItem.invoiceID
            )
        }
    }

    private static func validateCurrencies(in workspace: WorkspaceArchiveV1Workspace) throws {
        try ensureValidCurrencyCode(workspace.businessProfile.currencyCode, field: "businessProfile.currencyCode")

        for project in workspace.projects {
            try ensureValidCurrencyCode(project.currencyCode, field: "project.currencyCode")
        }

        for invoice in workspace.invoices {
            try ensureValidCurrencyCode(invoice.currencyCode, field: "invoice.currencyCode")
        }
    }

    private static func validateMoneyAndAccounting(in workspace: WorkspaceArchiveV1Workspace) throws {
        try ensurePositiveTermsDays(
            workspace.businessProfile.defaultTermsDays,
            field: "businessProfile.defaultTermsDays"
        )
        try ensurePositiveMoneyValue(
            workspace.businessProfile.nextInvoiceNumber,
            field: "businessProfile.nextInvoiceNumber"
        )

        for client in workspace.clients {
            try ensurePositiveTermsDays(client.defaultTermsDays, field: "client.defaultTermsDays")
        }

        for bucket in workspace.buckets {
            try ensureNonNegativeMoneyValue(
                bucket.defaultHourlyRateMinorUnits,
                field: "bucket.defaultHourlyRateMinorUnits"
            )
        }

        for entry in workspace.timeEntries {
            try ensurePositiveMoneyValue(entry.durationMinutes, field: "timeEntry.durationMinutes")
            try ensureNonNegativeMoneyValue(entry.hourlyRateMinorUnits, field: "timeEntry.hourlyRateMinorUnits")
            _ = try billableTimeAmount(for: entry)
        }

        for fixedCost in workspace.fixedCosts {
            try ensureNonNegativeMoneyValue(fixedCost.amountMinorUnits, field: "fixedCost.amountMinorUnits")
        }

        for lineItem in workspace.invoiceLineItems {
            try ensureNonNegativeMoneyValue(
                lineItem.amountMinorUnits,
                field: "invoiceLineItem.amountMinorUnits"
            )
        }

        let groupedTimeEntries = Dictionary(grouping: workspace.timeEntries, by: \.bucketID)
        let groupedFixedCosts = Dictionary(grouping: workspace.fixedCosts, by: \.bucketID)
        for bucket in workspace.buckets {
            let billableTimeTotal = try sumMoneyValues(
                groupedTimeEntries[bucket.id, default: []].map { try billableTimeAmount(for: $0) },
                field: "timeEntry.hourlyRateMinorUnits"
            )
            let fixedCostTotal = try sumMoneyValues(
                groupedFixedCosts[bucket.id, default: []].map(\.amountMinorUnits),
                field: "fixedCost.amountMinorUnits"
            )
            _ = try sumMoneyValues(
                [billableTimeTotal, fixedCostTotal],
                field: "bucket.totalMinorUnits"
            )
        }

        let groupedLineItems = Dictionary(grouping: workspace.invoiceLineItems, by: \.invoiceID)
        for invoice in workspace.invoices {
            try ensureNonNegativeMoneyValue(invoice.totalMinorUnits, field: "invoice.totalMinorUnits")

            let totalFromLineItems = try sumMoneyValues(
                groupedLineItems[invoice.id, default: []].map(\.amountMinorUnits),
                field: "invoiceLineItem.amountMinorUnits"
            )

            if totalFromLineItems != invoice.totalMinorUnits {
                throw WorkspaceArchiveImportError.invoiceTotalMismatch(
                    invoiceID: invoice.id,
                    expected: invoice.totalMinorUnits,
                    actual: totalFromLineItems
                )
            }
        }
    }

    private static func validateInvoiceTemplates(in workspace: WorkspaceArchiveV1Workspace) throws {
        for invoice in workspace.invoices where InvoiceTemplate(rawValue: invoice.template) == nil {
            throw WorkspaceArchiveImportError.invalidInvoiceTemplate(invoice.template)
        }
    }

    private static func billableTimeAmount(for entry: WorkspaceArchiveV1Workspace.TimeEntry) throws -> Int {
        guard entry.isBillable else { return 0 }

        let product = entry.durationMinutes.multipliedReportingOverflow(by: entry.hourlyRateMinorUnits)
        if product.overflow {
            throw WorkspaceArchiveImportError.invalidMoneyValue(
                field: "timeEntry.hourlyRateMinorUnits",
                value: entry.hourlyRateMinorUnits
            )
        }
        return product.partialValue / 60
    }

    private static func sumMoneyValues(_ values: [Int], field: String) throws -> Int {
        try values.reduce(0) { partialTotal, value in
            let result = partialTotal.addingReportingOverflow(value)
            if result.overflow {
                throw WorkspaceArchiveImportError.invalidMoneyValue(field: field, value: value)
            }
            return result.partialValue
        }
    }

    private static func ensurePositiveTermsDays(_ value: Int, field: String) throws {
        guard value > 0 else {
            throw WorkspaceArchiveImportError.invalidTermsDays(field: field, value: value)
        }
    }

    private static func ensurePositiveMoneyValue(_ value: Int, field: String) throws {
        guard value > 0 else {
            throw WorkspaceArchiveImportError.invalidMoneyValue(field: field, value: value)
        }
    }

    private static func ensureNonNegativeMoneyValue(_ value: Int, field: String) throws {
        guard value >= 0 else {
            throw WorkspaceArchiveImportError.invalidMoneyValue(field: field, value: value)
        }
    }

    private static func validateInvoiceNumbers(in workspace: WorkspaceArchiveV1Workspace) throws {
        var seenNumbers = Set<String>()
        for invoice in workspace.invoices {
            let normalized = normalizedInvoiceNumberKey(invoice.number)
            if normalized.isEmpty {
                throw WorkspaceArchiveImportError.duplicateInvoiceNumber(normalized)
            }

            let inserted = seenNumbers.insert(normalized).inserted
            if !inserted {
                throw WorkspaceArchiveImportError.duplicateInvoiceNumber(normalized)
            }
        }
    }

    private static func normalizedInvoiceNumberKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func ensureUnique(_ values: [UUID], entity: String) throws {
        var seen = Set<UUID>()
        for value in values {
            let inserted = seen.insert(value).inserted
            if !inserted {
                throw WorkspaceArchiveImportError.duplicateEntityID(entity: entity, id: value)
            }
        }
    }

    private static func ensureValidCurrencyCode(_ rawValue: String, field: String) throws {
        guard rawValue.count == 3,
              rawValue.allSatisfy(\.isLetter),
              rawValue == rawValue.uppercased()
        else {
            throw WorkspaceArchiveImportError.invalidCurrencyCode(field: field, value: rawValue)
        }
    }
}
