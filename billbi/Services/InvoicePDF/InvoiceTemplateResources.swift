import Foundation

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
