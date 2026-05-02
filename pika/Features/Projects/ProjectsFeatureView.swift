import SwiftUI

struct ProjectsFeatureView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date
    let onSelectProject: (PikaShellDestination) -> Void
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
        onSelectProject: @escaping (PikaShellDestination) -> Void = { _ in }
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
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                HStack(alignment: .bottom, spacing: PikaSpacing.lg) {
                    VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                        Text("\(summary.projectCount) active projects")
                            .font(PikaTypography.display)
                            .foregroundStyle(PikaColor.textPrimary)

                        Text(summaryLine)
                            .font(PikaTypography.body.monospacedDigit())
                            .foregroundStyle(PikaColor.textSecondary)
                    }

                    Spacer(minLength: 0)
                }

                projectGrid(projects)

                if !workspace.archivedProjects.isEmpty {
                    archivedProjectsSection
                }
            }
            .padding(PikaSpacing.md)
        }
        .background(PikaColor.background)
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
        "\(formatter.string(fromMinorUnits: summary.openMinorUnits)) open · \(formatter.string(fromMinorUnits: summary.readyMinorUnits)) ready · \(formatter.string(fromMinorUnits: summary.overdueMinorUnits)) overdue"
    }

    private var archivedProjectsSection: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.md) {
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
            columns: [GridItem(.adaptive(minimum: 280), spacing: PikaSpacing.md)],
            spacing: PikaSpacing.md
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
            listActionFailure = ProjectListActionFailure(message: "Project could not be updated.")
        }
    }

    private func archiveProjectFromList(_ projectID: WorkspaceProject.ID) {
        do {
            try workspaceStore.archiveProject(projectID: projectID)
        } catch {
            listActionFailure = ProjectListActionFailure(message: "Project could not be archived.")
        }
    }

    private func deleteProjectFromList(_ projectID: WorkspaceProject.ID) {
        do {
            try workspaceStore.removeProject(projectID: projectID)
        } catch WorkspaceStoreError.projectNotArchived {
            listActionFailure = ProjectListActionFailure(message: "Only archived projects can be deleted.")
        } catch {
            listActionFailure = ProjectListActionFailure(message: "Project could not be deleted.")
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

private struct ArchivedProjectsHeader: View {
    let count: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            Text("\(count) archived projects")
                .font(PikaTypography.subheading)
                .foregroundStyle(PikaColor.textPrimary)

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PikaColor.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
        }
        .frame(minHeight: 28, alignment: .leading)
        .contentShape(Rectangle())
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

private struct CreateProjectSheet: View {
    let clients: [WorkspaceClient]
    let defaultCurrencyCode: String
    let onCancel: () -> Void
    let onSave: (WorkspaceProjectDraft) -> Void

    @State private var name = ""
    @State private var clientID: WorkspaceClient.ID?
    @State private var currencyCode: String
    @State private var firstBucketName = "MVP"
    @State private var hourlyRate = 80.0

    init(
        clients: [WorkspaceClient],
        defaultCurrencyCode: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceProjectDraft) -> Void
    ) {
        self.clients = clients
        self.defaultCurrencyCode = defaultCurrencyCode
        self.onCancel = onCancel
        self.onSave = onSave
        _clientID = State(initialValue: clients.first?.id)
        _currencyCode = State(initialValue: defaultCurrencyCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                    PikaInputSheetSection(title: "Project") {
                        PikaInputSheetFieldRow(label: "Project name") {
                            TextField("Project name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Client") {
                            if clients.isEmpty {
                                Text("Create a client first")
                                    .foregroundStyle(PikaColor.textMuted)
                            } else {
                                Picker("Client", selection: $clientID) {
                                    ForEach(clients) { client in
                                        Text(client.name).tag(Optional(client.id))
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Currency") {
                            CurrencyCodeField("Currency", text: $currencyCode)
                        }
                    }

                    PikaInputSheetSection(title: "Starter bucket") {
                        PikaInputSheetFieldRow(label: "Bucket name") {
                            TextField("Bucket name", text: $firstBucketName)
                                .textFieldStyle(.roundedBorder)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Hourly rate") {
                            CurrencyAmountField("Hourly rate", value: $hourlyRate, currencyCode: currencyCode)
                        }
                    }
                }
                .padding(PikaSpacing.md)
            }

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.pikaAction(.destructive))

                Spacer()

                Button {
                    guard let clientID else { return }
                    onSave(WorkspaceProjectDraft(
                        name: name,
                        clientID: clientID,
                        currencyCode: CurrencyTextFormatting.normalizedInput(currencyCode),
                        firstBucketName: firstBucketName,
                        hourlyRateMinorUnits: max(Int((hourlyRate * 100).rounded()), 0)
                    ))
                } label: {
                    Label("Create Project", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 360)
        .background(PikaColor.background)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && clientID != nil
            && !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !firstBucketName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hourlyRate > 0
    }
}

private struct ProjectCard: View {
    var project: WorkspaceProject
    var currentDate: Date
    var totalAmount: String
    var readyAmount: String

    private var overdueInvoiceCount: Int {
        project.overdueInvoiceCount(on: currentDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(PikaTypography.subheading)
                        .foregroundStyle(PikaColor.textPrimary)
                    Text(project.clientName)
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textSecondary)
                    Text("\(project.bucketCount) buckets")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PikaColor.textMuted)
                }

                Spacer()

                StatusBadge(project.isArchived ? .neutral : .success, title: project.isArchived ? "Archived" : "Active")
            }

            HStack(spacing: PikaSpacing.sm) {
                ProjectCountPill(value: project.openBucketCount, label: "Open")
                ProjectCountPill(value: project.readyBucketCount, label: "Ready", tone: .success)
                ProjectCountPill(value: project.finalizedBucketCount, label: "Invoiced", tone: .warning)

                if overdueInvoiceCount > 0 {
                    ProjectCountPill(value: overdueInvoiceCount, label: "Overdue", tone: .danger)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                Text(totalAmount)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PikaColor.textPrimary)
                Text("total billed + open")
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textMuted)
            }

            cardFooter
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
        .padding(PikaSpacing.md)
        .pikaSurface()
    }

    @ViewBuilder
    private var cardFooter: some View {
        if project.readyToInvoiceMinorUnits > 0 {
            footerStrip(
                tone: .success,
                title: "Ready",
                detail: "\(project.readyBucketCount) ready · \(readyAmount)"
            )
        } else if overdueInvoiceCount > 0 {
            footerStrip(
                tone: .danger,
                title: "Overdue",
                detail: "\(overdueInvoiceCount) invoice needs attention"
            )
        } else {
            footerStrip(tone: .neutral, title: "", detail: "")
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private func footerStrip(tone: PikaStatusTone, title: String, detail: String) -> some View {
        HStack(spacing: PikaSpacing.sm) {
            StatusBadge(tone, title: title)
            Text(detail)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textPrimary)
            Spacer()
        }
        .padding(PikaSpacing.sm)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
    }
}

private struct ProjectCountPill: View {
    var value: Int
    var label: String
    var tone: PikaStatusTone = .neutral

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(PikaTypography.small)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, PikaSpacing.xs)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.pill))
    }
}
