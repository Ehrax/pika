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

            Section("Projects") {
                ForEach(workspace.activeProjects) { project in
                    NavigationLink(value: PikaShellDestination.project(project.id)) {
                        projectRow(project)
                    }
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

            Section("Projects") {
                ForEach(workspace.activeProjects) { project in
                    sidebarButton(for: .project(project.id)) {
                        projectRow(project)
                    }
                }
            }
        }
        .navigationTitle("Pika")
        #endif
    }

    private func projectRow(_ project: WorkspaceProject) -> some View {
        HStack(spacing: PikaSpacing.sm) {
            Circle()
                .fill(PikaColor.accent)
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
                    .foregroundStyle(PikaColor.success)
            }
        }
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
