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
    case invalidCurrencyCode(field: String, value: String)
    case invalidMoneyValue(field: String, value: Int)
    case invalidTermsDays(field: String, value: Int)
    case duplicateInvoiceNumber(String)
    case invoiceTotalMismatch(invoiceID: UUID, expected: Int, actual: Int)
}

enum WorkspaceArchiveImportValidator {
    static func validateAndSummarize(_ data: Data) throws -> WorkspaceArchiveImportSummary {
        let envelope = try WorkspaceArchiveCodec.decode(data)
        return try validateAndSummarize(envelope)
    }

    static func validateAndSummarize(_ envelope: WorkspaceArchiveEnvelope) throws -> WorkspaceArchiveImportSummary {
        try envelope.validate()

        let workspace = envelope.workspace
        try validateUniqueIDs(in: workspace)
        try validateRelationships(in: workspace)
        try validateCurrencies(in: workspace)
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

    private static func validateUniqueIDs(in workspace: WorkspaceArchiveWorkspace) throws {
        try ensureUnique(workspace.clients.map(\.id), entity: "client")
        try ensureUnique(workspace.projects.map(\.id), entity: "project")
        try ensureUnique(workspace.buckets.map(\.id), entity: "bucket")
        try ensureUnique(workspace.timeEntries.map(\.id), entity: "timeEntry")
        try ensureUnique(workspace.fixedCosts.map(\.id), entity: "fixedCost")
        try ensureUnique(workspace.invoices.map(\.id), entity: "invoice")
        try ensureUnique(workspace.invoiceLineItems.map(\.id), entity: "invoiceLineItem")
    }

    private static func validateRelationships(in workspace: WorkspaceArchiveWorkspace) throws {
        let clientIDs = Set(workspace.clients.map(\.id))
        let projectIDs = Set(workspace.projects.map(\.id))
        let bucketIDs = Set(workspace.buckets.map(\.id))
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

    private static func validateCurrencies(in workspace: WorkspaceArchiveWorkspace) throws {
        try ensureValidCurrencyCode(workspace.businessProfile.currencyCode, field: "businessProfile.currencyCode")

        for project in workspace.projects {
            try ensureValidCurrencyCode(project.currencyCode, field: "project.currencyCode")
        }

        for invoice in workspace.invoices {
            try ensureValidCurrencyCode(invoice.currencyCode, field: "invoice.currencyCode")
        }
    }

    private static func validateMoneyAndAccounting(in workspace: WorkspaceArchiveWorkspace) throws {
        if workspace.businessProfile.defaultTermsDays <= 0 {
            throw WorkspaceArchiveImportError.invalidTermsDays(
                field: "businessProfile.defaultTermsDays",
                value: workspace.businessProfile.defaultTermsDays
            )
        }

        if workspace.businessProfile.nextInvoiceNumber <= 0 {
            throw WorkspaceArchiveImportError.invalidMoneyValue(
                field: "businessProfile.nextInvoiceNumber",
                value: workspace.businessProfile.nextInvoiceNumber
            )
        }

        for client in workspace.clients where client.defaultTermsDays <= 0 {
            throw WorkspaceArchiveImportError.invalidTermsDays(
                field: "client.defaultTermsDays",
                value: client.defaultTermsDays
            )
        }

        for bucket in workspace.buckets where bucket.defaultHourlyRateMinorUnits <= 0 {
            throw WorkspaceArchiveImportError.invalidMoneyValue(
                field: "bucket.defaultHourlyRateMinorUnits",
                value: bucket.defaultHourlyRateMinorUnits
            )
        }

        for entry in workspace.timeEntries {
            if entry.durationMinutes <= 0 {
                throw WorkspaceArchiveImportError.invalidMoneyValue(
                    field: "timeEntry.durationMinutes",
                    value: entry.durationMinutes
                )
            }

            if entry.hourlyRateMinorUnits < 0 {
                throw WorkspaceArchiveImportError.invalidMoneyValue(
                    field: "timeEntry.hourlyRateMinorUnits",
                    value: entry.hourlyRateMinorUnits
                )
            }
        }

        for fixedCost in workspace.fixedCosts {
            if fixedCost.quantity <= 0 {
                throw WorkspaceArchiveImportError.invalidMoneyValue(
                    field: "fixedCost.quantity",
                    value: fixedCost.quantity
                )
            }

            if fixedCost.unitPriceMinorUnits < 0 {
                throw WorkspaceArchiveImportError.invalidMoneyValue(
                    field: "fixedCost.unitPriceMinorUnits",
                    value: fixedCost.unitPriceMinorUnits
                )
            }
        }

        for lineItem in workspace.invoiceLineItems where lineItem.amountMinorUnits < 0 {
            throw WorkspaceArchiveImportError.invalidMoneyValue(
                field: "invoiceLineItem.amountMinorUnits",
                value: lineItem.amountMinorUnits
            )
        }

        let groupedLineItems = Dictionary(grouping: workspace.invoiceLineItems, by: \.invoiceID)
        for invoice in workspace.invoices {
            if invoice.totalMinorUnits < 0 {
                throw WorkspaceArchiveImportError.invalidMoneyValue(
                    field: "invoice.totalMinorUnits",
                    value: invoice.totalMinorUnits
                )
            }

            let totalFromLineItems = groupedLineItems[invoice.id, default: []]
                .map(\.amountMinorUnits)
                .reduce(0, +)

            if totalFromLineItems != invoice.totalMinorUnits {
                throw WorkspaceArchiveImportError.invoiceTotalMismatch(
                    invoiceID: invoice.id,
                    expected: invoice.totalMinorUnits,
                    actual: totalFromLineItems
                )
            }
        }
    }

    private static func validateInvoiceNumbers(in workspace: WorkspaceArchiveWorkspace) throws {
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
