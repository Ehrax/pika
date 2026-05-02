import Foundation
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

enum WorkspaceArchiveActions {
    static let fileExtension = "pikaarchive"

    static func export(workspaceStore: WorkspaceStore) throws {
        let envelope = try workspaceStore.workspaceArchiveEnvelope(
            exportedAt: .now,
            generator: WorkspaceArchiveGenerator(app: "Pika", version: appVersion, build: appBuild)
        )
        let data = try WorkspaceArchiveCodec.encode(envelope)

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [archiveUTType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultArchiveFilename()

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        try data.write(to: exportDestinationURL(from: url), options: .atomic)
        #else
        throw WorkspaceArchiveActionError.unsupportedPlatform
        #endif
    }

    static func exportDestinationURL(from selectedURL: URL) -> URL {
        guard selectedURL.pathExtension.isEmpty else {
            return selectedURL
        }

        return selectedURL.appendingPathExtension(fileExtension)
    }

    private static var archiveUTType: UTType {
        UTType(filenameExtension: fileExtension) ?? .data
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
    }

    private static func defaultArchiveFilename(now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "workspace-\(formatter.string(from: now)).\(fileExtension)"
    }
}

enum WorkspaceArchiveActionError: LocalizedError {
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Workspace archive export is only available on Mac."
        }
    }
}
