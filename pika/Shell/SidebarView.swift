import SwiftUI

struct SidebarView: View {
    let workspace: WorkspaceSnapshot
    @Binding var selection: PikaShellDestination

    var body: some View {
        #if os(macOS)
        List(selection: $selection) {
            Section("Workspace") {
                NavigationLink(value: PikaShellDestination.dashboard) {
                    Label("Dashboard", systemImage: "gauge")
                }
                NavigationLink(value: PikaShellDestination.projects) {
                    Label("Projects", systemImage: "folder")
                }
                ForEach(workspace.activeProjects) { project in
                    NavigationLink(value: PikaShellDestination.project(project.id)) {
                        projectRow(
                            project,
                            appearance: SidebarProjectRowAppearance(isSelected: selection == .project(project.id))
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 34, bottom: 4, trailing: 12))
                }
                NavigationLink(value: PikaShellDestination.invoices) {
                    Label("Invoices", systemImage: "doc.text")
                }
                NavigationLink(value: PikaShellDestination.clients) {
                    Label("Clients", systemImage: "person.2")
                }
                NavigationLink(value: PikaShellDestination.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }

        }
        .navigationTitle("Pika")
        .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        #else
        List {
            Section("Workspace") {
                sidebarButton(for: .dashboard) {
                    Label("Dashboard", systemImage: "gauge")
                }
                sidebarButton(for: .projects) {
                    Label("Projects", systemImage: "folder")
                }
                ForEach(workspace.activeProjects) { project in
                    sidebarButton(for: .project(project.id)) {
                        projectRow(
                            project,
                            appearance: SidebarProjectRowAppearance(isSelected: selection == .project(project.id))
                        )
                        .padding(.leading, 22)
                    }
                }
                sidebarButton(for: .invoices) {
                    Label("Invoices", systemImage: "doc.text")
                }
                sidebarButton(for: .clients) {
                    Label("Clients", systemImage: "person.2")
                }
                sidebarButton(for: .settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("Pika")
        #endif
    }

    private func projectRow(_ project: WorkspaceProject, appearance: SidebarProjectRowAppearance) -> some View {
        HStack(spacing: PikaSpacing.sm) {
            Circle()
                .fill(appearance.projectDotColor)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                Text(project.clientName)
                    .font(PikaTypography.small)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: PikaSpacing.sm)

            if project.readyBucketCount > 0 {
                Text("\(project.readyBucketCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(appearance.readyCountColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    #if !os(macOS)
    private func sidebarButton<LabelContent: View>(
        for destination: PikaShellDestination,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        Button {
            selection = destination
        } label: {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selection == destination ? PikaColor.accent : PikaColor.textPrimary)
    }
    #endif
}

enum SidebarReadyCountContrast: Equatable {
    case selectedForeground
    case success
}

struct SidebarProjectRowAppearance: Equatable {
    let isSelected: Bool

    var readyCountContrast: SidebarReadyCountContrast {
        isSelected ? .selectedForeground : .success
    }

    var readyCountColor: Color {
        switch readyCountContrast {
        case .selectedForeground:
            Color.white
        case .success:
            PikaColor.success
        }
    }

    var projectDotColor: Color {
        isSelected ? Color.white.opacity(0.78) : PikaColor.accent
    }
}
