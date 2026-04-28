import Foundation

enum InvoiceTemplate: String, CaseIterable, Codable, Equatable, Identifiable {
    case classic

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .classic:
            "Classic"
        }
    }
}
