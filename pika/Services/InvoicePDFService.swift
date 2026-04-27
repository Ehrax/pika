import Foundation

struct InvoicePDFService {
    enum Error: Swift.Error, Equatable {
        case notImplemented
    }

    static func placeholder() -> InvoicePDFService {
        InvoicePDFService()
    }

    func renderDraftPDF() throws -> Data {
        throw Error.notImplemented
    }
}
