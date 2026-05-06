import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Mustache
import OSLog
import UniformTypeIdentifiers

struct InvoicePDFService {
    enum Error: Swift.Error, Equatable {
        case notImplemented
        case renderingFailed
    }

    struct RenderedInvoice: Equatable {
        var data: Data
        var metadata: Metadata
    }

    struct RenderedInvoiceHTML: Equatable {
        var html: String
        var metadata: Metadata
        var templateFolderName: String
        var resourceBaseURL: URL?
    }

    struct Metadata: Equatable {
        var invoiceNumber: String
        var clientName: String
        var projectName: String
        var bucketName: String
        var templateName: String
        var currencyCode: String
        var totalLabel: String
        var lineItemCount: Int
        var pageCount: Int
        var suggestedFilename: String
    }

    static func placeholder() -> InvoicePDFService {
        InvoicePDFService()
    }

    func renderDraftPDF() throws -> Data {
        throw Error.notImplemented
    }

    func renderInvoiceHTML(
        profile: BusinessProfileProjection,
        row: WorkspaceInvoiceRowProjection
    ) throws -> RenderedInvoiceHTML {
        let context = InvoiceRenderContext(profile: row.businessProfile ?? profile, row: row)
        let resources = try InvoiceTemplateResources(template: row.template)
        let html = try InvoiceHTMLTemplateRenderer().render(context, resources: resources)

        Self.logger.info(
            "Rendered invoice HTML \(context.metadata.invoiceNumber, privacy: .public) for \(context.metadata.clientName, privacy: .public)"
        )

        return RenderedInvoiceHTML(
            html: html,
            metadata: context.metadata,
            templateFolderName: row.template.resourceFolderName,
            resourceBaseURL: resources.baseURL
        )
    }

    private static let logger = Logger(subsystem: "dev.ehrax.billbi", category: "InvoicePDFService")
}

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
    var clientName: String
    var billingAddress: String
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
        clientName = row.clientName
        billingAddress = row.billingAddress
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
        paymentDetails = profile.paymentDetails
        let parsedPaymentDetails = ParsedPaymentDetails(rawValue: profile.paymentDetails)
        paymentIBAN = parsedPaymentDetails.formattedIBAN
        paymentBIC = parsedPaymentDetails.bic
        paymentTransferNote = "Der Rechnungsbetrag ist bitte innerhalb von \(profile.defaultTermsDays) Tagen nach Rechnungseingang auf folgendes Konto zu überweisen:"
        paymentQRCodeDataURL = Self.paymentQRCodeDataURL(
            profile: profile,
            row: row,
            paymentDetails: parsedPaymentDetails
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
        paymentDetails: ParsedPaymentDetails
    ) -> String {
        do {
            let payload = try PaymentQRCodePayload(
                recipientName: profile.businessName,
                iban: paymentDetails.iban,
                bic: paymentDetails.bic,
                amountMinorUnits: row.invoice.totalMinorUnits,
                currencyCode: profile.currencyCode,
                remittanceText: row.number
            )
            return PaymentQRCodeRenderer().dataURL(for: payload.text) ?? ""
        } catch {
            return ""
        }
    }
}

struct InvoiceTemplateResources: Equatable {
    let folderName: String
    let document: String
    let stylesheet: String
    let partials: [String: String]
    let baseURL: URL?

    init(template: InvoiceTemplate, bundle: Bundle = .main) throws {
        folderName = template.resourceFolderName
        if let folderURL = Self.bundledFolderURL(folderName: folderName, bundle: bundle) {
            baseURL = folderURL
            document = try String(contentsOf: folderURL.appendingPathComponent("document.mustache"), encoding: .utf8)
            stylesheet = try String(contentsOf: folderURL.appendingPathComponent("style.css"), encoding: .utf8)
            partials = try Self.loadPartials(from: folderURL.appendingPathComponent("partials", isDirectory: true))
        } else if let flatDocumentURL = bundle.url(forResource: "document", withExtension: "mustache"),
                  let flatStylesheetURL = bundle.url(forResource: "style", withExtension: "css") {
            baseURL = bundle.resourceURL
            document = try String(contentsOf: flatDocumentURL, encoding: .utf8)
            stylesheet = try String(contentsOf: flatStylesheetURL, encoding: .utf8)
            partials = try Self.loadFlatPartials(from: bundle)
        } else {
            let folderURL = try Self.sourceFolderURL(folderName: folderName)
            baseURL = folderURL
            document = try String(contentsOf: folderURL.appendingPathComponent("document.mustache"), encoding: .utf8)
            stylesheet = try String(contentsOf: folderURL.appendingPathComponent("style.css"), encoding: .utf8)
            partials = try Self.loadPartials(from: folderURL.appendingPathComponent("partials", isDirectory: true))
        }
    }

    private static func bundledFolderURL(folderName: String, bundle: Bundle) -> URL? {
        bundle.url(
            forResource: folderName,
            withExtension: nil,
            subdirectory: "InvoiceTemplates"
        )
    }

    private static func sourceFolderURL(folderName: String) throws -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/InvoiceTemplates/\(folderName)", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw InvoicePDFService.Error.renderingFailed
        }
        return sourceURL
    }

    private static func loadPartials(from folderURL: URL) throws -> [String: String] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        )
        return try urls
            .filter { $0.pathExtension == "mustache" }
            .reduce(into: [:]) { partials, url in
                partials[url.deletingPathExtension().lastPathComponent] = try String(contentsOf: url, encoding: .utf8)
            }
    }

    private static func loadFlatPartials(from bundle: Bundle) throws -> [String: String] {
        try ["line-items", "payment-details", "legal-notes"].reduce(into: [:]) { partials, name in
            guard let url = bundle.url(forResource: name, withExtension: "mustache") else {
                throw InvoicePDFService.Error.renderingFailed
            }
            partials[name] = try String(contentsOf: url, encoding: .utf8)
        }
    }
}

private struct InvoiceHTMLTemplateRenderer {
    func render(_ context: InvoiceRenderContext, resources: InvoiceTemplateResources) throws -> String {
        var library = MustacheLibrary()
        try library.register(resources.document, named: "document")
        for (name, partial) in resources.partials {
            try library.register(partial, named: name)
        }
        guard let html = library.render(context.mustacheValues, withTemplate: "document") else {
            throw InvoicePDFService.Error.renderingFailed
        }
        return html
    }
}

private extension InvoiceRenderContext {
    var mustacheValues: [String: Any] {
        [
            "templateName": metadata.templateName,
            "businessName": businessName,
            "businessPersonName": businessPersonName,
            "businessAddress": lineBreaks(businessAddress),
            "businessEmail": businessEmail,
            "businessPhone": businessPhone,
            "taxIdentifier": taxIdentifier,
            "economicIdentifier": economicIdentifier,
            "clientName": clientName,
            "billingAddress": lineBreaks(billingAddress),
            "invoiceNumber": invoiceNumber,
            "issueDate": issueDate,
            "dueDate": dueDate,
            "servicePeriod": servicePeriod,
            "projectName": projectName,
            "bucketName": bucketName,
            "lineItems": lineItems.map(\.mustacheValues),
            "totalLabel": totalLabel,
            "paymentDetails": lineBreaks(paymentDetails),
            "paymentIBAN": paymentIBAN,
            "paymentBIC": paymentBIC,
            "hasPaymentIBAN": !paymentIBAN.isEmpty,
            "hasPaymentBIC": !paymentBIC.isEmpty,
            "paymentQRCodeDataURL": paymentQRCodeDataURL,
            "paymentTransferNote": paymentTransferNote.htmlEscaped,
            "taxNote": lineBreaks(taxNote),
            "note": lineBreaks(note),
            "thankYouNote": thankYouNote.htmlEscaped,
        ]
    }

    private func lineBreaks(_ value: String) -> String {
        value
            .htmlEscaped
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}

private extension String {
    var htmlEscaped: String {
        var escaped = ""
        for character in self {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
        return escaped
    }
}

private extension InvoiceRenderContext.LineItem {
    var mustacheValues: [String: Any] {
        [
            "position": position,
            "description": description,
            "quantity": quantity,
            "unit": unit,
            "unitPrice": unitPrice,
            "amount": amount,
        ]
    }
}

private struct ParsedPaymentDetails: Equatable {
    var iban: String
    var formattedIBAN: String
    var bic: String

    init(rawValue: String) {
        let lines = rawValue
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var parsedIBAN = ""
        var parsedBIC = ""

        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("iban") {
                parsedIBAN = Self.value(afterLabelIn: line)
            } else if lowercased.hasPrefix("bic") {
                parsedBIC = Self.value(afterLabelIn: line)
            } else if parsedIBAN.isEmpty, line.filter({ !$0.isWhitespace }).count >= 15 {
                parsedIBAN = line
            }
        }

        iban = parsedIBAN.filter { !$0.isWhitespace }.uppercased()
        formattedIBAN = Self.groupedIBAN(iban)
        bic = parsedBIC.uppercased()
    }

    private static func value(afterLabelIn line: String) -> String {
        let separators = CharacterSet(charactersIn: ": ")
        return line
            .drop { !$0.unicodeScalars.contains { separators.contains($0) } }
            .trimmingCharacters(in: separators)
    }

    private static func groupedIBAN(_ value: String) -> String {
        value.enumerated().reduce(into: "") { result, element in
            if element.offset > 0, element.offset.isMultiple(of: 4) {
                result.append(" ")
            }
            result.append(element.element)
        }
    }
}

private struct PaymentQRCodeRenderer {
    private let context = CIContext(options: nil)

    func dataURL(for text: String) -> String? {
        guard let payloadData = text.data(using: .utf8) else {
            return nil
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = payloadData
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scale: CGFloat = 8
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent),
              let pngData = Self.pngData(from: cgImage) else {
            return nil
        }

        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }

    private static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}

struct PaymentQRCodePayload: Equatable {
    enum Error: Swift.Error, Equatable {
        case missingRecipientName
        case missingIBAN
        case missingCurrencyCode
        case invalidAmount
    }

    let text: String

    init(
        recipientName: String,
        iban: String,
        bic: String?,
        amountMinorUnits: Int,
        currencyCode: String,
        remittanceText: String
    ) throws {
        let cleanRecipientName = recipientName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let cleanIBAN = iban
            .filter { !$0.isWhitespace }
            .uppercased()
        let cleanBIC = (bic ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let cleanCurrencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanRemittanceText = remittanceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !cleanRecipientName.isEmpty else { throw Error.missingRecipientName }
        guard !cleanIBAN.isEmpty else { throw Error.missingIBAN }
        guard !cleanCurrencyCode.isEmpty else { throw Error.missingCurrencyCode }
        guard amountMinorUnits > 0 else { throw Error.invalidAmount }

        text = [
            "BCD",
            "002",
            "1",
            "SCT",
            cleanBIC,
            cleanRecipientName,
            cleanIBAN,
            Self.amountLabel(amountMinorUnits: amountMinorUnits, currencyCode: cleanCurrencyCode),
            "",
            "",
            cleanRemittanceText,
        ].joined(separator: "\n")
    }

    nonisolated private static func amountLabel(amountMinorUnits: Int, currencyCode: String) -> String {
        let majorUnits = amountMinorUnits / 100
        let cents = amountMinorUnits % 100
        return "\(currencyCode)\(majorUnits).\(String(format: "%02d", cents))"
    }
}
