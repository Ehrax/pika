import Foundation

struct TaxLegalFieldPresetCatalog: Codable, Equatable {
    struct CountryPreset: Codable, Equatable {
        var countryCode: String
        var sourceName: String
        var sourceURL: String
        var fields: [FieldPreset]
    }

    struct FieldPreset: Codable, Equatable, Identifiable {
        var id: String { key }
        var key: String
        var label: String
        var placement: TaxLegalFieldPlacement
        var owner: Owner
        var sortOrder: Int

        enum Owner: String, Codable, Equatable {
            case sender
            case recipient
        }
    }

    var countries: [CountryPreset]

    func presets(for countryCode: String) -> [FieldPreset] {
        countries
            .first(where: { $0.countryCode.caseInsensitiveCompare(countryCode) == .orderedSame })?
            .fields
            .sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
    }

    func duplicateKeys(for countryCode: String) -> [String] {
        let keys = presets(for: countryCode).map(\.key)
        let counts = Dictionary(keys.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.filter { $0.value > 1 }.map(\.key)
    }
}

enum TaxLegalFieldPresetCatalogLoader {
    static func decode(_ data: Data) throws -> TaxLegalFieldPresetCatalog {
        try JSONDecoder().decode(TaxLegalFieldPresetCatalog.self, from: data)
    }
}
