import Foundation

struct InvoiceRenderContext: Equatable {
    struct LineItem: Equatable {
        var position: String
        var description: String
        var quantity: String
        var unit: String
        var unitPrice: String
        var amount: String
    }

    var metadata: InvoicePDFService.Metadata
    var businessName: String
    var businessPersonName: String
    var businessAddress: String
    var businessEmail: String
    var businessPhone: String
    var taxIdentifier: String
    var economicIdentifier: String
    var senderTaxLegalFields: [WorkspaceTaxLegalField]
    var clientName: String
    var billingAddress: String
    var recipientTaxLegalFields: [WorkspaceTaxLegalField]
    var invoiceNumber: String
    var issueDate: String
    var dueDate: String
    var servicePeriod: String
    var projectName: String
    var bucketName: String
    var lineItems: [LineItem]
    var totalLabel: String
    var paymentDetails: String
    var paymentIBAN: String
    var paymentBIC: String
    var paymentQRCodeDataURL: String
    var paymentTransferNote: String
    var taxNote: String
    var note: String
    var thankYouNote: String

    init(profile: BusinessProfileProjection, row: WorkspaceInvoiceRowProjection) {
        metadata = InvoicePDFService.Metadata(
            invoiceNumber: row.number,
            clientName: row.clientName,
            projectName: row.projectName,
            bucketName: row.bucketName,
            templateName: row.template.displayName,
            currencyCode: profile.currencyCode,
            totalLabel: row.totalLabel,
            lineItemCount: row.lineItems.count,
            pageCount: 1,
            suggestedFilename: InvoiceRenderContext.filename(invoiceNumber: row.number, clientName: row.clientName)
        )
        businessName = profile.businessName
        businessPersonName = profile.personName
        businessAddress = profile.address
        businessEmail = profile.email
        businessPhone = profile.phone
        taxIdentifier = profile.taxIdentifier
        economicIdentifier = profile.economicIdentifier
        senderTaxLegalFields = profile.senderTaxLegalFields
            .filter { $0.placement == .senderDetails && $0.isRenderable }
            .sorted { $0.sortOrder < $1.sortOrder }
        clientName = row.clientName
        billingAddress = row.billingAddress
        recipientTaxLegalFields = (row.invoice.clientSnapshot?.recipientTaxLegalFields ?? [])
            .filter { $0.placement == .recipientDetails && $0.isRenderable }
            .sorted { $0.sortOrder < $1.sortOrder }
        invoiceNumber = row.number
        issueDate = Self.dateLabel(row.issueDate)
        dueDate = Self.dateLabel(row.dueDate)
        servicePeriod = row.servicePeriod
        projectName = row.projectName
        bucketName = row.bucketName
        lineItems = row.lineItems.enumerated().map { index, item in
            LineItem(
                position: "\(index + 1)",
                description: item.description,
                quantity: item.quantityValueLabel,
                unit: item.unitLabel,
                unitPrice: item.unitPriceLabel,
                amount: item.amountLabel
            )
        }
        totalLabel = row.totalLabel
        let selectedPaymentMethod = row.invoice.selectedPaymentMethodSnapshot ?? profile.defaultPaymentMethod
        let selectedPaymentDetails = selectedPaymentMethod?.printableInstructions ?? profile.paymentDetails
        paymentDetails = selectedPaymentDetails
        let parsedPaymentDetails = ParsedPaymentDetails(rawValue: selectedPaymentDetails)
        paymentIBAN = parsedPaymentDetails.formattedIBAN
        paymentBIC = parsedPaymentDetails.bic
        paymentTransferNote = "Der Rechnungsbetrag ist bitte innerhalb von \(profile.defaultTermsDays) Tagen nach Rechnungseingang auf folgendes Konto zu überweisen:"
        paymentQRCodeDataURL = Self.paymentQRCodeDataURL(
            profile: profile,
            row: row,
            paymentDetails: parsedPaymentDetails,
            selectedPaymentMethod: selectedPaymentMethod
        )
        taxNote = Self.taxNote(profile.taxNote, taxIdentifier: profile.taxIdentifier)
        note = Self.invoiceNote(row.invoice.note, taxNote: profile.taxNote, taxIdentifier: profile.taxIdentifier)
        thankYouNote = "Vielen Dank für die Zusammenarbeit!"
    }

    private static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .billbiGregorian
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private static func filename(invoiceNumber: String, clientName: String) -> String {
        let rawName = "\(invoiceNumber)-\(clientName)"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = rawName
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }

        return "\(cleaned).pdf"
    }

    private static func taxNote(_ value: String, taxIdentifier: String) -> String {
        let note = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return isTaxIdentifierNote(note, taxIdentifier: taxIdentifier) ? "" : note
    }

    private static func invoiceNote(_ value: String?, taxNote: String, taxIdentifier: String) -> String {
        let note = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let taxNote = taxNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return note == taxNote || isTaxIdentifierNote(note, taxIdentifier: taxIdentifier) ? "" : note
    }

    private static func isTaxIdentifierNote(_ note: String, taxIdentifier: String) -> Bool {
        let taxIdentifier = taxIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !taxIdentifier.isEmpty else {
            return false
        }
        return note == "Steuernummer: \(taxIdentifier)"
    }

    private static func paymentQRCodeDataURL(
        profile: BusinessProfileProjection,
        row: WorkspaceInvoiceRowProjection,
        paymentDetails: ParsedPaymentDetails,
        selectedPaymentMethod: WorkspacePaymentMethod?
    ) -> String {
        let invoiceCurrencyCode = row.invoice.currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let effectiveCurrencyCode = invoiceCurrencyCode.isEmpty
            ? profile.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            : invoiceCurrencyCode
        guard effectiveCurrencyCode == "EUR" else { return "" }
        if let selectedPaymentMethod {
            guard selectedPaymentMethod.isSEPAEligible else { return "" }
        } else {
            guard !paymentDetails.iban.isEmpty else { return "" }
        }
        do {
            let payload = try PaymentQRCodePayload(
                recipientName: profile.businessName,
                iban: paymentDetails.iban,
                bic: paymentDetails.bic,
                amountMinorUnits: row.invoice.totalMinorUnits,
                currencyCode: effectiveCurrencyCode,
                remittanceText: row.number
            )
            return PaymentQRCodeRenderer().dataURL(for: payload.text) ?? ""
        } catch {
            return ""
        }
    }
}
