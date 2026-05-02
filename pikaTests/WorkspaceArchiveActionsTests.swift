import Foundation
import Testing
@testable import pika

struct WorkspaceArchiveActionsTests {
    @Test func exportDestinationAppendsArchiveExtensionWhenMissing() {
        let selectedURL = URL(filePath: "/tmp/workspace-2026-05-02")

        let destinationURL = WorkspaceArchiveActions.exportDestinationURL(from: selectedURL)

        #expect(destinationURL.pathExtension == WorkspaceArchiveActions.fileExtension)
        #expect(destinationURL.lastPathComponent == "workspace-2026-05-02.\(WorkspaceArchiveActions.fileExtension)")
    }

    @Test func exportDestinationPreservesExistingArchiveExtensionCaseInsensitively() {
        let selectedURL = URL(filePath: "/tmp/workspace-2026-05-02.PIKAARCHIVE")

        let destinationURL = WorkspaceArchiveActions.exportDestinationURL(from: selectedURL)

        #expect(destinationURL == selectedURL)
    }

    @Test func exportDestinationPreservesExistingNonArchiveExtension() {
        let selectedURL = URL(filePath: "/tmp/workspace-2026-05-02.json")

        let destinationURL = WorkspaceArchiveActions.exportDestinationURL(from: selectedURL)

        #expect(destinationURL == selectedURL)
    }

    @Test func preImportBackupWritesV1ArchiveInAppSupportBackupsDirectory() throws {
        let fileManager = FileManager.default
        let appSupportRoot = fileManager.temporaryDirectory
            .appending(component: "WorkspaceArchiveActionsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? fileManager.removeItem(at: appSupportRoot)
        }

        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let now = Date.pikaDate(year: 2026, month: 5, day: 2)
        let backupURL = try WorkspaceArchiveActions.writePreImportBackup(
            workspaceStore: store,
            now: now,
            fileManager: fileManager,
            appSupportDirectoryURL: appSupportRoot
        )

        let backupsDirectory = appSupportRoot
            .appending(component: WorkspaceArchiveActions.appSupportSubdirectoryName, directoryHint: .isDirectory)
            .appending(component: WorkspaceArchiveActions.backupsDirectoryName, directoryHint: .isDirectory)
        #expect(backupURL.deletingLastPathComponent() == backupsDirectory)
        #expect(backupURL.pathExtension == WorkspaceArchiveActions.fileExtension)
        #expect(fileManager.fileExists(atPath: backupURL.path))

        let data = try Data(contentsOf: backupURL)
        let decoded = try WorkspaceArchiveCodec.decode(data)
        #expect(decoded.format == WorkspaceArchiveEnvelope.formatMarker)
        #expect(decoded.version == WorkspaceArchiveEnvelope.supportedVersion)
    }

    @Test func revealWorkspaceBackupsCreatesDirectoryAndOpensIt() throws {
        let fileManager = FileManager.default
        let appSupportRoot = fileManager.temporaryDirectory
            .appending(component: "WorkspaceArchiveActionsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? fileManager.removeItem(at: appSupportRoot)
        }

        var openedURL: URL?
        let directoryURL = appSupportRoot
            .appending(component: WorkspaceArchiveActions.appSupportSubdirectoryName, directoryHint: .isDirectory)
            .appending(component: WorkspaceArchiveActions.backupsDirectoryName, directoryHint: .isDirectory)
        #expect(!fileManager.fileExists(atPath: directoryURL.path))

        try WorkspaceArchiveActions.revealWorkspaceBackups(
            fileManager: fileManager,
            appSupportDirectoryURL: appSupportRoot,
            openURL: { url in
                openedURL = url
                return true
            }
        )

        #expect(openedURL?.lastPathComponent == WorkspaceArchiveActions.backupsDirectoryName)
        #expect(fileManager.fileExists(atPath: directoryURL.path))
    }
}
