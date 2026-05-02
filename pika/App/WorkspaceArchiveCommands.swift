import SwiftUI

enum WorkspaceArchiveFileMenuCommandTitles {
    static let exportWorkspaceArchive = "Export Workspace Archive…"
    static let importWorkspaceArchive = "Import Workspace Archive…"
    static let revealWorkspaceBackups = "Reveal Workspace Backups"
    static let all = [
        exportWorkspaceArchive,
        importWorkspaceArchive,
        revealWorkspaceBackups,
    ]
}

struct WorkspaceArchiveCommands: Commands {
    @Environment(\.workspaceStore) private var workspaceStore

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button(WorkspaceArchiveFileMenuCommandTitles.exportWorkspaceArchive) {
                exportWorkspaceArchive()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button(WorkspaceArchiveFileMenuCommandTitles.revealWorkspaceBackups) {
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
