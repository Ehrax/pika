import SwiftUI

enum WorkspaceArchiveFileMenuCommandSurface {
    static let exportWorkspaceArchiveTitle = "Export Workspace Archive…"
    static let importWorkspaceArchiveTitle = "Import Workspace Archive…"
    static let revealWorkspaceBackupsTitle = "Reveal Workspace Backups"
    static let commandTitles = [
        exportWorkspaceArchiveTitle,
        importWorkspaceArchiveTitle,
        revealWorkspaceBackupsTitle,
    ]

#if os(macOS)
    static let commandGroupTypeNames = [
        String(describing: WorkspaceArchiveCommands.self),
        String(describing: WorkspaceArchiveImportCommands.self),
    ]

    @CommandsBuilder
    static var commands: some Commands {
        WorkspaceArchiveCommands()
        WorkspaceArchiveImportCommands()
    }
#endif
}

struct WorkspaceArchiveCommands: Commands {
    @Environment(\.workspaceStore) private var workspaceStore

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button(WorkspaceArchiveFileMenuCommandSurface.exportWorkspaceArchiveTitle) {
                exportWorkspaceArchive()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button(WorkspaceArchiveFileMenuCommandSurface.revealWorkspaceBackupsTitle) {
                revealWorkspaceBackups()
            }
        }
    }

    private func exportWorkspaceArchive() {
        do {
            try WorkspaceArchiveActions.export(workspaceStore: workspaceStore)
        } catch {
            AppTelemetry.workspaceArchiveExportFailed(message: String(describing: error))
        }
    }

    private func revealWorkspaceBackups() {
        do {
            #if os(macOS)
            try WorkspaceArchiveActions.revealWorkspaceBackups()
            #else
            throw WorkspaceArchiveActionError.unsupportedPlatform
            #endif
        } catch {
            AppTelemetry.workspaceArchiveBackupRevealFailed(message: String(describing: error))
        }
    }
}
