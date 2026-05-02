import Foundation

enum WorkspaceInvoiceProjections {
    static func preview(
        for workspace: WorkspaceSnapshot,
        selectedInvoiceID: WorkspaceInvoice.ID? = nil,
        on date: Date,
        formatter: MoneyFormatting
    ) -> WorkspaceInvoicePreviewProjection? {
        let rows = workspace.projects
            .flatMap { project in
                project.invoices.map { invoice in
                    (projectName: project.name, invoice: invoice)
                }
            }
            .sorted { left, right in
                if left.invoice.issueDate == right.invoice.issueDate {
                    return left.invoice.number > right.invoice.number
                }

                return left.invoice.issueDate > right.invoice.issueDate
            }
            .map { projectName, invoice in
                let client = workspace.clients.firstMatching(id: invoice.clientID, name: invoice.clientName)
                return WorkspaceInvoiceRowProjection(
                    invoice: invoice,
                    projectName: projectName,
                    billingAddress: client?.billingAddress ?? "",
                    on: date,
                    formatter: formatter
                )
            }

        guard let selectedRow = rows.first(where: { $0.id == selectedInvoiceID }) ?? rows.first else {
            return nil
        }

        return WorkspaceInvoicePreviewProjection(
            selectedInvoice: selectedRow.invoice,
            selectedRow: selectedRow,
            rows: rows
        )
    }
}

struct WorkspaceInvoicePreviewProjection: Equatable {
    let selectedInvoice: WorkspaceInvoice
    let selectedRow: WorkspaceInvoiceRowProjection
    let rows: [WorkspaceInvoiceRowProjection]
}

struct WorkspaceInvoiceRowProjection: Equatable, Identifiable {
    let id: WorkspaceInvoice.ID
    let number: String
    let businessProfile: BusinessProfileProjection?
    let clientID: UUID?
    let clientName: String
    let projectID: UUID?
    let projectName: String
    let bucketID: UUID?
    let bucketName: String
    let template: InvoiceTemplate
    let issueDate: Date
    let dueDate: Date
    let servicePeriod: String
    let status: InvoiceStatus
    let statusTitle: String
    let isOverdue: Bool
    let totalLabel: String
    let billingAddress: String
    let lineItems: [WorkspaceInvoiceLineItemProjection]
    let invoice: WorkspaceInvoice

    init(
        invoice: WorkspaceInvoice,
        projectName: String,
        billingAddress: String,
        on date: Date,
        formatter: MoneyFormatting
    ) {
        id = invoice.id
        number = invoice.number
        businessProfile = invoice.businessSnapshot
        clientID = invoice.clientID
        clientName = invoice.clientSnapshot?.name ?? invoice.clientName
        projectID = invoice.projectID
        self.projectName = invoice.projectName.isEmpty ? projectName : invoice.projectName
        bucketID = invoice.bucketID
        bucketName = invoice.bucketName.isEmpty ? "Project services" : invoice.bucketName
        template = invoice.template
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        servicePeriod = invoice.servicePeriod
        status = invoice.status
        isOverdue = invoice.status.isOverdue(dueDate: invoice.dueDate, on: date)
        statusTitle = isOverdue ? "Overdue" : invoice.status.rawValue.capitalized
        totalLabel = formatter.string(fromMinorUnits: invoice.totalMinorUnits)
        self.billingAddress = invoice.clientSnapshot?.billingAddress ?? billingAddress
        lineItems = Self.lineItems(for: invoice, formatter: formatter)
        self.invoice = invoice
    }

    private static func lineItems(
        for invoice: WorkspaceInvoice,
        formatter: MoneyFormatting
    ) -> [WorkspaceInvoiceLineItemProjection] {
        let snapshots = invoice.lineItems.isEmpty
            ? [
                WorkspaceInvoiceLineItemSnapshot(
                    id: invoice.id,
                    description: "Services rendered",
                    quantityLabel: "1 item",
                    amountMinorUnits: invoice.totalMinorUnits
                ),
            ]
            : invoice.lineItems

        return snapshots.map { item in
            WorkspaceInvoiceLineItemProjection(
                id: item.id,
                description: item.description,
                quantityLabel: item.quantityLabel,
                amountMinorUnits: item.amountMinorUnits,
                formatter: formatter,
                amountLabel: formatter.string(fromMinorUnits: item.amountMinorUnits)
            )
        }
    }
}

struct WorkspaceInvoiceLineItemProjection: Equatable, Identifiable {
    let id: UUID
    let description: String
    let quantityLabel: String
    let quantityValueLabel: String
    let unitLabel: String
    let unitPriceLabel: String
    let amountLabel: String

    init(
        id: UUID,
        description: String,
        quantityLabel: String,
        amountMinorUnits: Int,
        formatter: MoneyFormatting,
        amountLabel: String
    ) {
        self.id = id
        self.description = description
        self.quantityLabel = quantityLabel
        self.amountLabel = amountLabel

        let quantityUnit = Self.quantityUnit(from: quantityLabel)
        quantityValueLabel = quantityUnit.quantity
        unitLabel = quantityUnit.unit
        unitPriceLabel = Self.unitPriceLabel(
            quantity: quantityUnit.numericQuantity,
            amountMinorUnits: amountMinorUnits,
            formatter: formatter
        )
    }

    private static func quantityUnit(from label: String) -> (quantity: String, numericQuantity: Double?, unit: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasSuffix("h") {
            let value = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return (localizedDecimal(value), numericQuantity(from: value), "Stunden")
        }

        if lowercased.hasSuffix("hours") || lowercased.hasSuffix("hour") {
            let parts = trimmed.split(separator: " ")
            let value = parts.first.map(String.init) ?? trimmed
            return (localizedDecimal(value), numericQuantity(from: value), "Stunden")
        }

        if lowercased.hasSuffix("items") || lowercased.hasSuffix("item") {
            let parts = trimmed.split(separator: " ")
            let value = parts.first.map(String.init) ?? trimmed
            return (localizedDecimal(value), numericQuantity(from: value), "Stück")
        }

        return (trimmed, numericQuantity(from: trimmed), "")
    }

    private static func localizedDecimal(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: ",")
    }

    private static func numericQuantity(from value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private static func unitPriceLabel(
        quantity: Double?,
        amountMinorUnits: Int,
        formatter: MoneyFormatting
    ) -> String {
        guard let quantity, quantity > 0 else { return "" }

        let unitAmount = Int((Double(amountMinorUnits) / quantity).rounded())
        return formatter.string(fromMinorUnits: unitAmount)
    }
}

extension Collection where Element == WorkspaceClient {
    func firstMatching(id clientID: UUID?, name clientName: String) -> WorkspaceClient? {
        first { client in
            if let clientID {
                return client.id == clientID
            }

            return client.name == clientName
        }
    }
}

extension WorkspaceSnapshot {
    func invoicePreviewProjection(
        selectedInvoiceID: WorkspaceInvoice.ID? = nil,
        on date: Date,
        formatter: MoneyFormatting
    ) -> WorkspaceInvoicePreviewProjection? {
        WorkspaceInvoiceProjections.preview(
            for: self,
            selectedInvoiceID: selectedInvoiceID,
            on: date,
            formatter: formatter
        )
    }
}
