import Foundation

enum InvoiceTemplate: String, CaseIterable, Codable, Equatable, Identifiable {
    case kleinunternehmerClassic = "kleinunternehmer-classic"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .kleinunternehmerClassic:
            String(localized: "Small Business")
        }
    }

    var resourceFolderName: String {
        rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "classic":
            self = .kleinunternehmerClassic
        default:
            guard let template = Self(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown invoice template: \(rawValue)"
                )
            }
            self = template
        }
    }
}
