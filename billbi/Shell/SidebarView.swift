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
                NavigationLink(value: BillbiShellDestination.dashboard) {
                    Label("Dashboard", systemImage: "gauge")
                }
                projectsFolderRow
                    .listRowInsets(SidebarProjectsFolderRowLayout.listInsets.edgeInsets)
                    .listRowBackground(Color.clear)
                if projectsExpanded && SidebarProjectsDisclosurePolicy.showsDisclosure(activeProjectCount: workspace.activeProjects.count) {
                    ForEach(Array(workspace.activeProjects.enumerated()), id: \.element.id) { index, project in
                        Button {
                            selection = .project(project.id)
                        } label: {
                            projectRow(
                                project,
                                appearance: SidebarProjectRowAppearance(isSelected: selection == .project(project.id)),
                                contentLeadingPadding: SidebarProjectRowLayout.contentLeadingPadding,
                                projectDotColor: SidebarProjectDotPalette.color(forProjectAt: index)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(SidebarProjectRowLayout.listInsets.edgeInsets)
                        .listRowBackground(Color.clear)
                    }
                }
                NavigationLink(value: BillbiShellDestination.invoices) {
                    Label("Invoices", systemImage: "doc.text")
                }
                NavigationLink(value: BillbiShellDestination.clients) {
                    Label("Clients", systemImage: "person.2")
                }
                NavigationLink(value: BillbiShellDestination.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }

        }
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
                sidebarButton(for: .dashboard) {
                    Label("Dashboard", systemImage: "gauge")
                }
                sidebarButton(for: .projects) {
                    Label("Projects", systemImage: "folder")
                }
                ForEach(Array(workspace.activeProjects.enumerated()), id: \.element.id) { index, project in
                    sidebarButton(for: .project(project.id)) {
                        projectRow(
                            project,
                            appearance: SidebarProjectRowAppearance(isSelected: selection == .project(project.id)),
                            projectDotColor: SidebarProjectDotPalette.color(forProjectAt: index)
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
                .foregroundStyle(selection == .projects ? Color.white.opacity(0.78) : BillbiColor.textSecondary)
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
        .foregroundStyle(selection == .projects ? Color.white : BillbiColor.textPrimary)
        .background {
            if selection == .projects {
                RoundedRectangle(cornerRadius: BillbiRadius.lg, style: .continuous)
                    .fill(BillbiColor.sidebarSelection)
            }
        }
        .contentShape(Rectangle())
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

    #if !os(macOS)
    private func sidebarButton<LabelContent: View>(
        for destination: BillbiShellDestination,
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
        .foregroundStyle(selection == destination ? BillbiColor.sidebarSelection : BillbiColor.textPrimary)
    }
    #endif
}

struct PrimarySidebarColumnLayout: Equatable {
    static let minimumWidth = 220.0
    static let idealWidth = 242.0
    static let maximumWidth = 520.0
    static let widthStorageKey = "billbi.primarySidebar.width"

    static func clamped(_ width: Double) -> Double {
        min(max(width, minimumWidth), maximumWidth)
    }
}

#if os(macOS)
private struct PrimarySidebarWidthTelemetry: View {
    @Binding var storedWidth: Double

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    observe(width: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, newWidth in
                    observe(width: newWidth)
                }
        }
    }

    private func observe(width: CGFloat) {
        guard width > 1 else { return }

        let clampedWidth = PrimarySidebarColumnLayout.clamped(Double(width))
        if abs(storedWidth - clampedWidth) > 0.5 {
            storedWidth = clampedWidth
            UserDefaults.standard.set(clampedWidth, forKey: PrimarySidebarColumnLayout.widthStorageKey)
        }

        AppTelemetry.primarySidebarWidthObserved(width: clampedWidth)
    }
}
#endif

struct SidebarProjectsDisclosurePolicy: Equatable {
    static let isExpandedByDefault = true
    static let disclosurePlacement = SidebarDisclosurePlacement.leading

    static func showsDisclosure(activeProjectCount: Int) -> Bool {
        activeProjectCount > 0
    }
}

enum SidebarDisclosurePlacement: Equatable {
    case leading
    case trailing
}

struct SidebarProjectsFolderRowLayout: Equatable {
    static let listInsets = SidebarRowInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
}

struct SidebarRowInsets: Equatable {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat

    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

struct SidebarProjectRowLayout: Equatable {
    static let listInsets = SidebarRowInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
    static let contentLeadingPadding: CGFloat = 24
    static let contentHorizontalPadding = BillbiSpacing.sm
    static let expandsSelectionToAvailableWidth = true
    static let displaysProjectDot = true
    static let projectDotSize: CGFloat = 7
    static let displaysClientSubtitle = false
}

enum SidebarProjectDotPalette {
    static let colors = ProjectColorPalette.colors

    static var colorCount: Int {
        ProjectColorPalette.colorCount
    }

    static func color(forProjectAt index: Int) -> Color {
        ProjectColorPalette.color(forProjectAt: index)
    }

    static func colorIndex(forProjectAt index: Int) -> Int {
        ProjectColorPalette.colorIndex(forProjectAt: index)
    }
}

enum SidebarProjectSelectionTreatment: Equatable {
    case none
    case sidebarAccent
}

struct SidebarProjectRowAppearance: Equatable {
    let isSelected: Bool

    var selectionTreatment: SidebarProjectSelectionTreatment {
        isSelected ? .sidebarAccent : .none
    }

    var selectionBackgroundColor: Color? {
        switch selectionTreatment {
        case .none:
            nil
        case .sidebarAccent:
            BillbiColor.sidebarSelection
        }
    }

    var textColor: Color {
        switch selectionTreatment {
        case .none:
            BillbiColor.textPrimary
        case .sidebarAccent:
            Color.white
        }
    }
}
