import SwiftUI

struct InvoicesView: View {
    let workspace: WorkspaceSnapshot
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    let initialSelectedInvoiceID: WorkspaceInvoice.ID?

    init(
        workspace: WorkspaceSnapshot,
        workspaceStore: WorkspaceStore,
        currentDate: Date,
        initialSelectedInvoiceID: WorkspaceInvoice.ID? = nil
    ) {
        self.workspace = workspace
        self.workspaceStore = workspaceStore
        self.currentDate = currentDate
        self.initialSelectedInvoiceID = initialSelectedInvoiceID
    }

    var body: some View {
        InvoicesFeatureView(
            workspace: workspace,
            workspaceStore: workspaceStore,
            currentDate: currentDate,
            initialSelectedInvoiceID: initialSelectedInvoiceID
        )
    }
}
