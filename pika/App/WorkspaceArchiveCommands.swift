import SwiftUI

struct WorkspaceArchiveCommands: Commands {
    @Environment(\.workspaceStore) private var workspaceStore

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Export Workspace Archive…") {
                exportWorkspaceArchive()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }

    private func exportWorkspaceArchive() {
        do {
            try WorkspaceArchiveActions.export(workspaceStore: workspaceStore)
        } catch {
            AppTelemetry.workspaceArchiveExportFailed(message: String(describing: error))
        }
    }
}
