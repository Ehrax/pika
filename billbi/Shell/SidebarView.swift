import SwiftUI

struct SidebarView: View {
    let workspace: WorkspaceSnapshot
    @Binding var selection: BillbiShellDestination
    @SceneStorage("billbi.sidebar.projectsExpanded") private var projectsExpanded = SidebarProjectsDisclosurePolicy.isExpandedByDefault
#if os(macOS)
    @AppStorage(PrimarySidebarColumnLayout.widthStorageKey) private var storedColumnWidth = PrimarySidebarColumnLayout.idealWidth
#endif

    var body: some View {
        #if os(macOS)
        List(selection: $selection) {
            Section("Workspace") {
                primarySidebarButton(for: .dashboard) {
                    Label("Dashboard", systemImage: "gauge")
                }
                projectsFolderRow
                    .listRowInsets(SidebarProjectsFolderRowLayout.listInsets.edgeInsets)
                    .listRowBackground(Color.clear)
                if projectsExpanded && SidebarProjectsDisclosurePolicy.showsDisclosure(activeProjectCount: workspace.activeProjects.count) {
                    ForEach(Array(workspace.activeProjects.enumerated()), id: \.element.id) { index, project in
                        NavigationLink(value: BillbiShellDestination.project(project.id)) {
                            projectRow(
                                project,
                                appearance: SidebarProjectRowAppearance(isSelected: false),
                                contentLeadingPadding: SidebarProjectRowLayout.contentLeadingPadding,
                                projectDotColor: SidebarProjectDotPalette.color(forProjectAt: index)
                            )
                        }
                        .listRowInsets(SidebarProjectRowLayout.listInsets.edgeInsets)
                    }
                }
                primarySidebarButton(for: .invoices) {
                    Label("Invoices", systemImage: "doc.text")
                }
                primarySidebarButton(for: .clients) {
                    Label("Clients", systemImage: "person.2")
                }
                primarySidebarButton(for: .settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }

        }
        .listStyle(.sidebar)
        .navigationTitle("Billbi")
        .navigationSplitViewColumnWidth(
            min: CGFloat(PrimarySidebarColumnLayout.minimumWidth),
            ideal: CGFloat(PrimarySidebarColumnLayout.clamped(storedColumnWidth)),
            max: CGFloat(PrimarySidebarColumnLayout.maximumWidth)
        )
        .background {
            PrimarySidebarWidthTelemetry(storedWidth: $storedColumnWidth)
        }
        #else
        List {
            Section("Workspace") {
                primarySidebarButton(for: .dashboard) {
                    Label("Dashboard", systemImage: "gauge")
                }
                primarySidebarButton(for: .projects) {
                    Label("Projects", systemImage: "folder")
                }
                ForEach(Array(workspace.activeProjects.enumerated()), id: \.element.id) { index, project in
                    NavigationLink(value: BillbiShellDestination.project(project.id)) {
                        projectRow(
                            project,
                            appearance: SidebarProjectRowAppearance(isSelected: false),
                            projectDotColor: SidebarProjectDotPalette.color(forProjectAt: index)
                        )
                        .padding(.leading, 22)
                    }
                }
                primarySidebarButton(for: .invoices) {
                    Label("Invoices", systemImage: "doc.text")
                }
                primarySidebarButton(for: .clients) {
                    Label("Clients", systemImage: "person.2")
                }
                primarySidebarButton(for: .settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("Billbi")
        #endif
    }

    private var projectsFolderRow: some View {
        HStack(spacing: BillbiSpacing.xs) {
            if SidebarProjectsDisclosurePolicy.showsDisclosure(activeProjectCount: workspace.activeProjects.count) {
                Button {
                    projectsExpanded.toggle()
                } label: {
                    Image(systemName: projectsExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 12, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(BillbiColor.textSecondary)
            }

            Button {
                selection = .projects
            } label: {
                Label("Projects", systemImage: "folder")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SidebarProjectRowLayout.contentHorizontalPadding)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tag(BillbiShellDestination.projects)
        .contentShape(Rectangle())
    }

    private func primarySidebarButton<LabelContent: View>(
        for destination: BillbiShellDestination,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        NavigationLink(value: destination) {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .listRowInsets(SidebarProjectsFolderRowLayout.listInsets.edgeInsets)
    }

    private func projectRow(
        _ project: WorkspaceProject,
        appearance: SidebarProjectRowAppearance,
        contentLeadingPadding: CGFloat = 0,
        projectDotColor: Color
    ) -> some View {
        HStack(spacing: BillbiSpacing.sm) {
            Circle()
                .fill(projectDotColor)
                .frame(width: SidebarProjectRowLayout.projectDotSize, height: SidebarProjectRowLayout.projectDotSize)

            Text(project.name)
                .lineLimit(1)

            Spacer(minLength: BillbiSpacing.sm)
        }
        .padding(.leading, contentLeadingPadding + SidebarProjectRowLayout.contentHorizontalPadding)
        .padding(.trailing, SidebarProjectRowLayout.contentHorizontalPadding)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(appearance.textColor)
        .background {
            if let selectionBackgroundColor = appearance.selectionBackgroundColor {
                RoundedRectangle(cornerRadius: BillbiRadius.lg, style: .continuous)
                    .fill(selectionBackgroundColor)
            }
        }
        .contentShape(Rectangle())
    }

}
