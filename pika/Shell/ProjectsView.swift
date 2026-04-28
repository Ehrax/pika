import SwiftUI

struct ProjectsView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date
    let onSelectProject: (PikaShellDestination) -> Void

    init(
        workspace: WorkspaceSnapshot,
        currentDate: Date,
        onSelectProject: @escaping (PikaShellDestination) -> Void = { _ in }
    ) {
        self.workspace = workspace
        self.currentDate = currentDate
        self.onSelectProject = onSelectProject
    }

    var body: some View {
        ProjectsFeatureView(
            workspace: workspace,
            currentDate: currentDate,
            onSelectProject: onSelectProject
        )
    }
}
