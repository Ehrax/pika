import SwiftUI

struct ProjectWorkbenchContainerView: View {
    let project: WorkspaceProject?
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    let initialSelectedBucketID: WorkspaceBucket.ID?

    init(
        project: WorkspaceProject?,
        workspaceStore: WorkspaceStore,
        currentDate: Date,
        initialSelectedBucketID: WorkspaceBucket.ID? = nil
    ) {
        self.project = project
        self.workspaceStore = workspaceStore
        self.currentDate = currentDate
        self.initialSelectedBucketID = initialSelectedBucketID
    }

    var body: some View {
        ProjectWorkbenchView(
            project: project,
            workspaceStore: workspaceStore,
            currentDate: currentDate,
            initialSelectedBucketID: initialSelectedBucketID
        )
    }
}
