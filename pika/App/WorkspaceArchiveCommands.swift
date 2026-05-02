import SwiftUI

struct WorkspaceArchiveCommands: Commands {
    @Environment(\.workspaceStore) private var workspaceStore

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Export Workspace Archive…") {
                exportWorkspaceArchive()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Reveal Workspace Backups") {
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
