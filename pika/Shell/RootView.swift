import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.workspaceStore) private var workspaceStore
    let currentDate: Date
    @State private var selection: PikaShellDestination = .dashboard
    @State private var dashboardSelectedInvoiceID: WorkspaceInvoice.ID?
    @State private var dashboardSelectedBucketID: WorkspaceBucket.ID?

    init(currentDate: Date = .now) {
        self.currentDate = currentDate
    }

    var body: some View {
        let workspace = workspaceStore.workspace

        NavigationSplitView {
            SidebarView(
                workspace: workspace,
                selection: $selection
            )
        } detail: {
            destinationView(for: selection, workspace: workspace)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { _, newSelection in
            AppTelemetry.shellSelectionChanged(newSelection.telemetryName)
        }
        .onAppear {
            AppTelemetry.shellSelectionChanged(selection.telemetryName)
        }
#if os(macOS)
        .focusedSceneValue(\.workspaceStore, workspaceStore)
#endif
    }

    @ViewBuilder
    private func destinationView(
        for selection: PikaShellDestination,
        workspace: WorkspaceSnapshot
    ) -> some View {
        switch selection {
        case .dashboard:
            DashboardView(
                workspace: workspace,
                currentDate: currentDate,
                onSelectAttentionItem: handleDashboardAttentionSelection
            )
        case .projects:
            ProjectsView(
                workspace: workspace,
                currentDate: currentDate,
                onSelectProject: { self.selection = $0 }
            )
        case .invoices:
            InvoicesView(
                workspace: workspace,
                workspaceStore: workspaceStore,
                currentDate: currentDate,
                initialSelectedInvoiceID: dashboardSelectedInvoiceID
            )
        case .clients:
            ClientsView(workspace: workspace)
        case .settings:
            SettingsView(profile: workspace.businessProfile)
        case .project(let id):
            let project = workspace.projects.first { $0.id == id }
            ProjectWorkbenchContainerView(
                project: project,
                workspaceStore: workspaceStore,
                currentDate: currentDate,
                initialSelectedBucketID: initialBucketID(in: project)
            )
        }
    }

    private func handleDashboardAttentionSelection(_ item: DashboardAttentionItem) {
        AppTelemetry.dashboardAttentionSelected(itemID: item.id)

        switch item.target {
        case .invoice(let invoiceID):
            dashboardSelectedInvoiceID = invoiceID
            selection = .invoices
        case .bucket(let projectID, let bucketID):
            dashboardSelectedBucketID = bucketID
            selection = .project(projectID)
        }
    }

    private func initialBucketID(in project: WorkspaceProject?) -> WorkspaceBucket.ID? {
        guard
            let dashboardSelectedBucketID,
            let project,
            project.buckets.contains(where: { $0.id == dashboardSelectedBucketID })
        else {
            return nil
        }

        return dashboardSelectedBucketID
    }
}

enum PikaShellDestination: Hashable {
    case dashboard
    case projects
    case invoices
    case clients
    case settings
    case project(UUID)

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .projects:
            "Projects"
        case .invoices:
            "Invoices"
        case .clients:
            "Clients"
        case .settings:
            "Settings"
        case .project:
            "Project"
        }
    }

    var telemetryName: String {
        switch self {
        case .dashboard:
            "dashboard"
        case .projects:
            "projects"
        case .invoices:
            "invoices"
        case .clients:
            "clients"
        case .settings:
            "settings"
        case .project:
            "project_shortcut"
        }
    }

    static func projectDestination(for project: WorkspaceProject) -> PikaShellDestination {
        .project(project.id)
    }
}

#Preview {
    let container = try! PreviewSupport.makeModelContainer()
    RootView()
        .modelContainer(container)
        .pikaDependencies(modelContainer: container)
}
