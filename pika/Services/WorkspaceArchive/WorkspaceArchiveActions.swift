import Foundation
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

enum WorkspaceArchiveActions {
    static let fileExtension = "pikaarchive"
    static let backupsDirectoryName = "Backups"
    static let appSupportSubdirectoryName = "Pika"

    static func export(workspaceStore: WorkspaceStore) throws {
        let data = try archiveData(workspaceStore: workspaceStore, exportedAt: .now)

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

    static func writePreImportBackup(
        workspaceStore: WorkspaceStore,
        now: Date = .now,
        fileManager: FileManager = .default,
        appSupportDirectoryURL: URL? = nil
    ) throws -> URL {
        let directory = try workspaceBackupsDirectoryURL(
            fileManager: fileManager,
            appSupportDirectoryURL: appSupportDirectoryURL
        )
        let data = try archiveData(workspaceStore: workspaceStore, exportedAt: now)
        let destinationURL = directory.appending(component: preImportBackupFilename(now: now))
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    static func workspaceBackupsDirectoryURL(
        fileManager: FileManager = .default,
        appSupportDirectoryURL: URL? = nil
    ) throws -> URL {
        let applicationSupportURL: URL
        if let appSupportDirectoryURL {
            applicationSupportURL = appSupportDirectoryURL
        } else {
            guard let resolvedURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw WorkspaceArchiveActionError.backupsDirectoryUnavailable
            }
            applicationSupportURL = resolvedURL
        }

        let backupsDirectoryURL = applicationSupportURL
            .appending(component: appSupportSubdirectoryName, directoryHint: .isDirectory)
            .appending(component: backupsDirectoryName, directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: backupsDirectoryURL,
            withIntermediateDirectories: true
        )
        return backupsDirectoryURL
    }

    #if os(macOS)
    static func revealWorkspaceBackups(
        fileManager: FileManager = .default,
        appSupportDirectoryURL: URL? = nil,
        openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) throws {
        let backupsDirectoryURL = try workspaceBackupsDirectoryURL(
            fileManager: fileManager,
            appSupportDirectoryURL: appSupportDirectoryURL
        )
        guard openURL(backupsDirectoryURL) else {
            throw WorkspaceArchiveActionError.backupsDirectoryOpenFailed
        }
    }
    #endif

    static func exportDestinationURL(from selectedURL: URL) -> URL {
        guard selectedURL.pathExtension.isEmpty else {
            return selectedURL
        }

        return selectedURL.appendingPathExtension(fileExtension)
    }

    private static var archiveUTType: UTType {
        UTType(filenameExtension: fileExtension) ?? .data
    }

    private static func archiveData(workspaceStore: WorkspaceStore, exportedAt: Date) throws -> Data {
        let envelope = try workspaceStore.workspaceArchiveEnvelope(
            exportedAt: exportedAt,
            generator: WorkspaceArchiveGenerator(app: "Pika", version: appVersion, build: appBuild)
        )
        return try WorkspaceArchiveCodec.encode(envelope)
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

    private static func preImportBackupFilename(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return "workspace-pre-import-\(formatter.string(from: now))-\(UUID().uuidString).\(fileExtension)"
    }
}

enum WorkspaceArchiveActionError: LocalizedError, Equatable {
    case backupsDirectoryUnavailable
    case backupsDirectoryOpenFailed
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .backupsDirectoryUnavailable:
            return "The backups directory could not be located."
        case .backupsDirectoryOpenFailed:
            return "The backups folder could not be opened."
        case .unsupportedPlatform:
            return "Workspace archive export is only available on Mac."
        }
    }
}
