import Foundation

struct ISOCountryOption: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let localizedName: String
}

enum ISOCountryCatalog {
    static func options(locale: Locale = .current) -> [ISOCountryOption] {
        Locale.Region.isoRegions
            .map { region in
                ISOCountryOption(
                    code: region.identifier.uppercased(),
                    localizedName: locale.localizedString(forRegionCode: region.identifier.uppercased()) ?? region.identifier
                )
            }
            .sorted { $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending }
    }
}
