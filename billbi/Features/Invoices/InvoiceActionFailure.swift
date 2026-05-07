import Foundation

struct PDFActionFailure: Identifiable {
    let id = UUID()
    let message: String
}

enum PDFActionError: LocalizedError {
    case noSelectedInvoice

    var errorDescription: String? {
        switch self {
        case .noSelectedInvoice:
            return String(localized: "Select an invoice before opening or exporting a PDF.")
        }
    }
}
