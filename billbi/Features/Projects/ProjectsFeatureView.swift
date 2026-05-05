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
        "\(formatter.string(fromMinorUnits: summary.openMinorUnits)) open · \(formatter.string(fromMinorUnits: summary.readyMinorUnits)) ready · \(formatter.string(fromMinorUnits: summary.overdueMinorUnits)) overdue"
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
        HStack(spacing: BillbiSpacing.sm) {
            Text("\(count) archived projects")
                .font(BillbiTypography.subheading)
                .foregroundStyle(BillbiColor.textPrimary)

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BillbiColor.textSecondary)
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
                VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                    BillbiInputSheetSection(title: "Project") {
                        BillbiInputSheetFieldRow(label: "Project name") {
                            TextField("Project name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Client") {
                            if clients.isEmpty {
                                Text("Create a client first")
                                    .foregroundStyle(BillbiColor.textMuted)
                            } else {
                                Picker("Client", selection: $clientID) {
                                    ForEach(clients) { client in
                                        Text(client.name).tag(Optional(client.id))
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Currency") {
                            CurrencyCodeField("Currency", text: $currencyCode)
                        }
                    }

                    BillbiInputSheetSection(title: "Starter bucket") {
                        BillbiInputSheetFieldRow(label: "Bucket name") {
                            TextField("Bucket name", text: $firstBucketName)
                                .textFieldStyle(.roundedBorder)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Hourly rate") {
                            CurrencyAmountField("Hourly rate", value: $hourlyRate, currencyCode: currencyCode)
                        }
                    }
                }
                .padding(BillbiSpacing.md)
            }

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.billbiAction(.destructive))

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
                .buttonStyle(.billbiAction(.primary))
                .disabled(!canSave)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 360)
        .background(BillbiColor.background)
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
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(BillbiTypography.subheading)
                        .foregroundStyle(BillbiColor.textPrimary)
                    Text(project.clientName)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                    Text("\(project.bucketCount) buckets")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BillbiColor.textMuted)
                }

                Spacer()

                StatusBadge(project.isArchived ? .neutral : .success, title: project.isArchived ? "Archived" : "Active")
            }

            HStack(spacing: BillbiSpacing.sm) {
                ProjectCountPill(value: project.openBucketCount, label: "Open")
                ProjectCountPill(value: project.readyBucketCount, label: "Ready", tone: .success)
                ProjectCountPill(value: project.finalizedBucketCount, label: "Invoiced", tone: .warning)

                if overdueInvoiceCount > 0 {
                    ProjectCountPill(value: overdueInvoiceCount, label: "Overdue", tone: .danger)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                Text(totalAmount)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                Text("total billed + open")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textMuted)
            }

            cardFooter
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
        .padding(BillbiSpacing.md)
        .billbiSurface()
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

    private func footerStrip(tone: BillbiStatusTone, title: String, detail: String) -> some View {
        HStack(spacing: BillbiSpacing.sm) {
            StatusBadge(tone, title: title)
            Text(detail)
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textPrimary)
            Spacer()
        }
        .padding(BillbiSpacing.sm)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md))
    }
}

private struct ProjectCountPill: View {
    var value: Int
    var label: String
    var tone: BillbiStatusTone = .neutral

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(BillbiTypography.small)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, BillbiSpacing.xs)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
    }
}
