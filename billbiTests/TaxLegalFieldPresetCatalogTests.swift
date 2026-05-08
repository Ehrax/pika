import Foundation
import Testing
@testable import billbi

struct TaxLegalFieldPresetCatalogTests {
    @Test func presetCatalogCoversInitialCountrySetAndIncludesSourceMetadata() throws {
        let catalog = try loadCatalog()
        let countryCodes = Set(catalog.countries.map(\.countryCode))

        #expect(countryCodes == Set(["DE", "AT", "CH", "GB", "US", "AU", "CA", "NL", "FR", "ES", "IT"]))
        #expect(catalog.countries.allSatisfy { !$0.sourceName.isEmpty && !$0.sourceURL.isEmpty })
    }

    @Test func presetCatalogHasStableUniqueKeysPerCountry() throws {
        let catalog = try loadCatalog()
        for country in catalog.countries {
            let duplicates = catalog.duplicateKeys(for: country.countryCode)
            #expect(duplicates.isEmpty)
        }
    }

    @Test func presetsForUnknownCountryReturnEmptyList() throws {
        let catalog = try loadCatalog()
        #expect(catalog.presets(for: "XX").isEmpty)
    }

    private func loadCatalog() throws -> TaxLegalFieldPresetCatalog {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "billbi/Resources/TaxLegalPresets/v1.json")
        let data = try Data(contentsOf: url)
        return try TaxLegalFieldPresetCatalogLoader.decode(data)
    }
}
