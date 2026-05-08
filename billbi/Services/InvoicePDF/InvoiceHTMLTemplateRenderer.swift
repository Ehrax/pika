import Foundation
import Mustache

struct InvoiceHTMLTemplateRenderer {
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
            "senderTaxLegalFields": senderTaxLegalFields.map(\.mustacheValues),
            "hasSenderTaxLegalFields": !senderTaxLegalFields.isEmpty,
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

    func lineBreaks(_ value: String) -> String {
        value
            .htmlEscaped
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}

private extension WorkspaceTaxLegalField {
    var mustacheValues: [String: Any] {
        [
            "label": label.htmlEscaped,
            "value": value.htmlEscaped,
        ]
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
