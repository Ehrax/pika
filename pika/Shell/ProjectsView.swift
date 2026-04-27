import SwiftUI

struct ProjectsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case active = "Active"
        case archived = "Archived"

        var id: String { rawValue }
    }

    let workspace: WorkspaceSnapshot
    let currentDate: Date
    let onSelectProject: (PikaShellDestination) -> Void
    @State private var filter = Filter.active

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
        switch filter {
        case .active:
            workspace.activeProjects
        case .archived:
            workspace.archivedProjects
        }
    }

    private var summary: ProjectOverviewSummary {
        workspace.projectOverviewSummary(for: projects, on: currentDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                HStack(alignment: .bottom, spacing: PikaSpacing.lg) {
                    VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                        Text("\(summary.projectCount) \(filter.rawValue.lowercased()) projects")
                            .font(PikaTypography.display)
                            .foregroundStyle(PikaColor.textPrimary)

                        Text(summaryLine)
                            .font(PikaTypography.body.monospacedDigit())
                            .foregroundStyle(PikaColor.textSecondary)
                    }

                    Spacer()

                    Picker("Project status", selection: $filter) {
                        ForEach(Filter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }

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
                    }
                }
            }
            .padding(PikaSpacing.lg)
        }
        .background(PikaColor.background)
        .navigationTitle("Projects")
        .toolbar {
            Button {
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .disabled(true)
            .help("Project creation lands in a later task")
        }
        .accessibilityIdentifier("ProjectsView")
    }

    private var summaryLine: String {
        "\(formatter.string(fromMinorUnits: summary.openMinorUnits)) open · \(formatter.string(fromMinorUnits: summary.readyMinorUnits)) ready · \(formatter.string(fromMinorUnits: summary.overdueMinorUnits)) overdue"
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

            if project.readyToInvoiceMinorUnits > 0 {
                HStack(spacing: PikaSpacing.sm) {
                    StatusBadge(.success, title: "Ready")
                    Text("\(project.readyBucketCount) ready · \(readyAmount)")
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textPrimary)
                    Spacer()
                }
                .padding(PikaSpacing.sm)
                .background(PikaColor.successMuted)
                .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
            } else if overdueInvoiceCount > 0 {
                HStack(spacing: PikaSpacing.sm) {
                    StatusBadge(.danger, title: "Overdue")
                    Text("\(overdueInvoiceCount) invoice needs attention")
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textPrimary)
                    Spacer()
                }
                .padding(PikaSpacing.sm)
                .background(PikaColor.dangerMuted)
                .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
            }
        }
        .padding(PikaSpacing.md)
        .pikaSurface()
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
