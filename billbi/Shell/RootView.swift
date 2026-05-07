import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.workspaceStore) private var workspaceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let currentDate: Date
    @State private var selection: BillbiShellDestination = .dashboard
    @State private var dashboardSelectedInvoiceID: WorkspaceInvoice.ID?
    @State private var dashboardSelectedBucketID: WorkspaceBucket.ID?
    @State private var isShowingOnboardingHandoff = false

    init(currentDate: Date = .now) {
        self.currentDate = currentDate
    }

    var body: some View {
        let workspace = workspaceStore.workspace

        Group {
            if isShowingOnboardingHandoff {
                OnboardingHandoffView()
                    .transition(.opacity)
            } else if workspace.onboardingCompleted {
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
            } else {
                OnboardingView(
                    workspaceStore: workspaceStore,
                    currentDate: currentDate,
                    onComplete: handleOnboardingCompletion
                )
                .transition(.opacity)
            }
        }
        .animation(onboardingHandoffAnimation, value: isShowingOnboardingHandoff)
#if os(macOS)
        .focusedSceneValue(\.workspaceStore, workspaceStore)
#endif
    }

    private var onboardingHandoffAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.42)
    }

    @ViewBuilder
    private func destinationView(
        for selection: BillbiShellDestination,
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

    private func handleOnboardingCompletion(_ cta: OnboardingPrimaryCTA) {
        switch cta {
        case .dashboard:
            selection = .dashboard
        case .project(let projectID, let bucketID):
            dashboardSelectedBucketID = bucketID
            selection = .project(projectID)
        }

        guard !reduceMotion else {
            return
        }

        isShowingOnboardingHandoff = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_350))
            isShowingOnboardingHandoff = false
        }
    }
}

private struct OnboardingHandoffView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: BillbiSpacing.lg) {
            Image("BillbiLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)
                .padding(.bottom, BillbiSpacing.sm)

            Text("Welcome")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(BillbiColor.textPrimary)

            HStack(spacing: BillbiSpacing.sm) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(BillbiColor.brand)
                        .frame(width: 7, height: 7)
                        .opacity(dotOpacity(at: index))
                        .scaleEffect(dotScale(at: index))
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.72)
                                .repeatForever()
                                .delay(Double(index) * 0.16),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 14)
            .accessibilityLabel("Loading")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BillbiColor.background)
        .onAppear {
            isAnimating = true
        }
    }

    private func dotOpacity(at index: Int) -> Double {
        guard !reduceMotion else {
            return 0.72
        }
        return isAnimating ? 0.35 : 1
    }

    private func dotScale(at index: Int) -> CGFloat {
        guard !reduceMotion else {
            return 1
        }
        return isAnimating ? 0.82 : 1
    }
}

enum BillbiShellDestination: Hashable {
    case dashboard
    case projects
    case invoices
    case clients
    case settings
    case project(UUID)

    var title: String {
        switch self {
        case .dashboard:
            String(localized: "Dashboard")
        case .projects:
            String(localized: "Projects")
        case .invoices:
            String(localized: "Invoices")
        case .clients:
            String(localized: "Clients")
        case .settings:
            String(localized: "Settings")
        case .project:
            String(localized: "Project")
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

    static func projectDestination(for project: WorkspaceProject) -> BillbiShellDestination {
        .project(project.id)
    }
}

#Preview {
    let container = try! PreviewSupport.makeModelContainer()
    RootView()
        .modelContainer(container)
        .billbiDependencies(modelContainer: container)
}
