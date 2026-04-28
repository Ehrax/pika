import SwiftUI

struct DashboardView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date
    let onSelectAttentionItem: (DashboardAttentionItem) -> Void

    init(
        workspace: WorkspaceSnapshot,
        currentDate: Date,
        onSelectAttentionItem: @escaping (DashboardAttentionItem) -> Void = { _ in }
    ) {
        self.workspace = workspace
        self.currentDate = currentDate
        self.onSelectAttentionItem = onSelectAttentionItem
    }

    var body: some View {
        DashboardFeatureView(
            workspace: workspace,
            currentDate: currentDate,
            onSelectAttentionItem: onSelectAttentionItem
        )
    }
}
