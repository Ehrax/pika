import Foundation
import Testing

struct LocalizationCatalogTests {
    @Test func appUsesSingleEnglishOnlyStringCatalog() throws {
        let catalogURLs = try appCatalogURLs()

        #expect(catalogURLs.map(\.lastPathComponent) == ["Localizable.xcstrings"])

        let catalog = try StringCatalog(url: try #require(catalogURLs.first))
        #expect(catalog.sourceLanguage == "en")
        #expect(catalog.localizedLanguages == ["en"])
    }

    @Test func appStringCatalogContainsRepresentativeMigratedUIEntries() throws {
        let catalog = try StringCatalog(url: try #require(appCatalogURLs().first))

        for key in [
            "Dashboard",
            "Projects",
            "Clients",
            "Invoices",
            "Settings",
            "New Project",
            "Create Client",
            "Invoice Action Failed",
            "Archived clients stay available for history, but must be archived before deletion.",
            "Search clients",
            "Unbilled project",
            "Export Workspace Archive…",
            "Welcome to Billbi",
            "Start setup",
            "Open Application",
            "You can start from the dashboard and fill details later.",
        ] {
            #expect(catalog.containsLocalizedEnglishValue(for: key))
        }
    }

    private func appCatalogURLs() throws -> [URL] {
        let appDirectory = repositoryRoot()
            .appending(path: "billbi", directoryHint: .isDirectory)

        let enumerator = FileManager.default.enumerator(
            at: appDirectory,
            includingPropertiesForKeys: nil
        )

        return try #require(enumerator?.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "xcstrings" else {
                return nil
            }
            return url
        })
        .sorted { $0.path < $1.path }
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct StringCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: Entry]

    var localizedLanguages: [String] {
        Array(
            Set(strings.values.flatMap { $0.localizations.keys })
        )
        .sorted()
    }

    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    func containsLocalizedEnglishValue(for key: String) -> Bool {
        strings[key]?.localizations["en"]?.stringUnit.value == key
    }

    struct Entry: Decodable {
        let localizations: [String: Localization]
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit
    }

    struct StringUnit: Decodable {
        let value: String
    }
}
