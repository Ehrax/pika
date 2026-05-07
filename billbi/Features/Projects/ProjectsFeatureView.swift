import SwiftUI

struct ProjectsFeatureView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date
    let onSelectProject: (BillbiShellDestination) -> Void
    @Environment(\.workspaceStore) private var workspaceStore
    @State private var showsArchivedProjects = false
    @State private var showsCreateProject = false
    @State private var creationFailure: ProjectCreationFailure?
    @State private var listActionFailure: ProjectListActionFailure?
    @State private var showsArchiveProjectConfirmation = false
    @State private var showsDeleteProjectConfirmation = false
    @State private var projectBeingEdited: WorkspaceProject?
    @State private var projectPendingListActionID: WorkspaceProject.ID?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    init(
        workspace: WorkspaceSnapshot,
        currentDate: Date,
        onSelectProject: @escaping (BillbiShellDestination) -> Void = { _ in }
    ) {
        self.workspace = workspace
        self.currentDate = currentDate
        self.onSelectProject = onSelectProject
    }

    private var projects: [WorkspaceProject] {
        workspace.activeProjects
    }

    private var summary: ProjectOverviewSummary {
        WorkspaceProjectProjections.overviewSummary(for: projects, on: currentDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                HStack(alignment: .bottom, spacing: BillbiSpacing.lg) {
                    VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                        Text("\(summary.projectCount) active projects")
                            .font(BillbiTypography.display)
                            .foregroundStyle(BillbiColor.textPrimary)

                        Text(summaryLine)
                            .font(BillbiTypography.body.monospacedDigit())
                            .foregroundStyle(BillbiColor.textSecondary)
                    }

                    Spacer(minLength: 0)
                }

                projectGrid(projects)

                if !workspace.archivedProjects.isEmpty {
                    archivedProjectsSection
                }
            }
            .padding(BillbiSpacing.md)
        }
        .background(BillbiColor.background)
        .navigationTitle("Projects")
        .toolbar {
            Button {
                showsCreateProject = true
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .help("Create a project")
        }
        .sheet(isPresented: $showsCreateProject) {
            CreateProjectSheet(
                clients: workspace.clients,
                defaultCurrencyCode: workspace.businessProfile.currencyCode,
                onCancel: { showsCreateProject = false },
                onSave: createProject
            )
        }
        .sheet(item: $projectBeingEdited) { project in
            ProjectEditorSheet(
                project: project,
                clients: workspace.clients,
                onCancel: { projectBeingEdited = nil },
                onSave: { draft in updateProjectFromList(project.id, draft) }
            )
        }
        .alert(item: $creationFailure) { failure in
            Alert(
                title: Text("Project Creation Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(item: $listActionFailure) { failure in
            Alert(
                title: Text("Project Action Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Archive this project?",
            isPresented: $showsArchiveProjectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Project", role: .destructive) {
                archivePendingProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived projects stay available for history, and can be deleted later.")
        }
        .confirmationDialog(
            "Delete this project?",
            isPresented: $showsDeleteProjectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive) {
                deletePendingProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleted projects are removed permanently and cannot be restored.")
        }
        .accessibilityIdentifier("ProjectsView")
    }

    private var summaryLine: String {
        String(
            localized: "\(formatter.string(fromMinorUnits: summary.openMinorUnits)) open · \(formatter.string(fromMinorUnits: summary.readyMinorUnits)) ready · \(formatter.string(fromMinorUnits: summary.overdueMinorUnits)) overdue"
        )
    }

    private var archivedProjectsSection: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    showsArchivedProjects.toggle()
                }
            } label: {
                ArchivedProjectsHeader(
                    count: workspace.archivedProjects.count,
                    isExpanded: showsArchivedProjects
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(workspace.archivedProjects.count) archived projects")
            .accessibilityHint(showsArchivedProjects ? "Collapses archived projects" : "Expands archived projects")
            .accessibilityAddTraits(.isButton)

            if showsArchivedProjects {
                projectGrid(workspace.archivedProjects)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.14), value: showsArchivedProjects)
    }

    private func projectGrid(_ projects: [WorkspaceProject]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 280), spacing: BillbiSpacing.md)],
            spacing: BillbiSpacing.md
        ) {
            ForEach(projects) { project in
                Button {
                    onSelectProject(.projectDestination(for: project))
                } label: {
                    ProjectCard(
                        project: project,
                        currentDate: currentDate,
                        totalAmount: formatter.string(fromMinorUnits: project.totalBucketMinorUnits),
                        readyAmount: formatter.string(fromMinorUnits: project.readyToInvoiceMinorUnits)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the project")
                .contextMenu {
                    projectMenuActions(for: project)
                }
            }
        }
    }

    @ViewBuilder
    private func projectMenuActions(for project: WorkspaceProject) -> some View {
        Button {
            projectBeingEdited = project
        } label: {
            Label("Edit Project", systemImage: "pencil")
        }

        if project.isArchived {
            Button(role: .destructive) {
                projectPendingListActionID = project.id
                showsDeleteProjectConfirmation = true
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        } else {
            Button {
                projectPendingListActionID = project.id
                showsArchiveProjectConfirmation = true
            } label: {
                Label("Archive Project", systemImage: "archivebox")
            }
        }
    }

    private func updateProjectFromList(_ projectID: WorkspaceProject.ID, _ draft: WorkspaceProjectUpdateDraft) {
        do {
            try workspaceStore.updateProject(projectID: projectID, draft)
            projectBeingEdited = nil
        } catch {
            listActionFailure = ProjectListActionFailure(message: String(localized: "Project could not be updated."))
        }
    }

    private func archiveProjectFromList(_ projectID: WorkspaceProject.ID) {
        do {
            try workspaceStore.archiveProject(projectID: projectID)
        } catch {
            listActionFailure = ProjectListActionFailure(message: String(localized: "Project could not be archived."))
        }
    }

    private func deleteProjectFromList(_ projectID: WorkspaceProject.ID) {
        do {
            try workspaceStore.removeProject(projectID: projectID)
        } catch WorkspaceStoreError.projectNotArchived {
            listActionFailure = ProjectListActionFailure(message: String(localized: "Only archived projects can be deleted."))
        } catch {
            listActionFailure = ProjectListActionFailure(message: String(localized: "Project could not be deleted."))
        }
    }

    private func archivePendingProject() {
        guard let projectID = projectPendingListActionID else { return }
        archiveProjectFromList(projectID)
        projectPendingListActionID = nil
    }

    private func deletePendingProject() {
        guard let projectID = projectPendingListActionID else { return }
        deleteProjectFromList(projectID)
        projectPendingListActionID = nil
    }

    private func createProject(_ draft: WorkspaceProjectDraft) {
        do {
            let project = try workspaceStore.createProject(draft)
            showsCreateProject = false
            onSelectProject(.projectDestination(for: project))
        } catch {
            creationFailure = ProjectCreationFailure(message: error.localizedDescription)
        }
    }
}

private struct ProjectCreationFailure: Identifiable {
    let id = UUID()
    let message: String
}

private struct ProjectListActionFailure: Identifiable {
    let id = UUID()
    let message: String
}
