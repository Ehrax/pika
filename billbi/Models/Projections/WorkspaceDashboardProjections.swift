import Foundation

enum WorkspaceDashboardProjections {
    static func summary(for workspace: WorkspaceSnapshot, on date: Date = .now) -> DashboardSummary {
        let invoices = workspace.projects.flatMap(\.invoices)
        let paidInvoices = invoices.filter { $0.status == .paid }
        let unpaidInvoices = invoices.filter { $0.status == .finalized || $0.status == .sent }
        let readyBuckets = workspace.projects.flatMap { project in
            project.buckets
                .filter { $0.status == .ready }
                .map { bucket in
                    (project: project, bucket: bucket)
                }
        }

        let overdueItems = invoices
            .filter { $0.status.isOverdue(dueDate: $0.dueDate, on: date) }
            .map { invoice in
                DashboardAttentionItem(
                    id: "overdue-invoice-\(invoice.id.uuidString)",
                    target: .invoice(invoice.id),
                    title: "\(invoice.clientName) invoice overdue",
                    detail: "\(invoice.number) due \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))",
                    amountMinorUnits: invoice.totalMinorUnits,
                    tone: .danger
                )
            }

        let readyItems = readyBuckets
            .sorted { left, right in
                if left.project.name == right.project.name {
                    return left.bucket.name < right.bucket.name
                }

                return left.project.name > right.project.name
            }
            .map { project, bucket in
                DashboardAttentionItem(
                    id: "ready-bucket-\(bucket.id.uuidString)",
                    target: .bucket(projectID: project.id, bucketID: bucket.id),
                    title: readyAttentionTitle(for: project),
                    detail: "\(bucket.name) has \(bucket.billableHoursLabel) billable",
                    amountMinorUnits: bucket.effectiveTotalMinorUnits,
                    tone: .success
                )
            }

        return DashboardSummary(
            outstandingMinorUnits: unpaidInvoices.map(\.totalMinorUnits).reduce(0, +),
            overdueMinorUnits: overdueItems.map(\.amountMinorUnits).reduce(0, +),
            readyToInvoiceMinorUnits: readyBuckets.map(\.bucket.effectiveTotalMinorUnits).reduce(0, +),
            thisMonthMinorUnits: paidInvoices
                .filter { Calendar.billbiGregorian.isDate($0.issueDate, equalTo: date, toGranularity: .month) }
                .map(\.totalMinorUnits)
                .reduce(0, +),
            activeProjectCount: workspace.activeProjects.count,
            clientCount: workspace.clients.count,
            needsAttention: overdueItems + readyItems,
            unbilledProjectRevenue: workspace.activeProjects.enumerated().compactMap { index, project in
                let buckets = project.buckets.filter { $0.status == .open || $0.status == .ready }
                let amountMinorUnits = buckets.map(\.effectiveTotalMinorUnits).reduce(0, +)
                guard amountMinorUnits > 0 else { return nil }

                return ProjectRevenuePoint(
                    projectID: project.id,
                    projectName: project.name,
                    amountMinorUnits: amountMinorUnits,
                    colorIndex: ProjectColorPalette.colorIndex(forProjectAt: index)
                )
            },
            unbilledRevenueHistory: unbilledRevenueHistory(for: workspace, on: date),
            revenueHistory: paidInvoices
                .sorted { left, right in
                    if left.issueDate == right.issueDate {
                        return left.number < right.number
                    }

                    return left.issueDate < right.issueDate
                }
                .map { invoice in
                    RevenuePoint(
                        date: invoice.issueDate,
                        label: invoice.number,
                        amountMinorUnits: invoice.totalMinorUnits
                    )
                }
        )
    }

    private static func readyAttentionTitle(for project: WorkspaceProject) -> String {
        "\(project.clientName) \(project.name.lowercased()) ready to invoice"
    }

    private static func unbilledRevenueHistory(for workspace: WorkspaceSnapshot, on date: Date) -> [ProjectRevenueHistoryPoint] {
        workspace.activeProjects.enumerated().flatMap { index, project in
            let colorIndex = ProjectColorPalette.colorIndex(forProjectAt: index)
            let events = project.buckets
                .filter { $0.status == .open || $0.status == .ready }
                .flatMap { bucket in
                    unbilledRevenueEvents(for: bucket, fallbackDate: date, colorIndex: colorIndex)
                }
                .sorted { left, right in
                    if left.date == right.date {
                        return left.amountMinorUnits < right.amountMinorUnits
                    }

                    return left.date < right.date
                }

            var cumulativeAmount = 0
            return events.map { event in
                cumulativeAmount += event.amountMinorUnits
                return ProjectRevenueHistoryPoint(
                    projectID: project.id,
                    date: event.date,
                    label: event.date.formatted(date: .abbreviated, time: .omitted),
                    amountMinorUnits: cumulativeAmount,
                    colorIndex: event.colorIndex
                )
            }
        }
    }

    private static func unbilledRevenueEvents(
        for bucket: WorkspaceBucket,
        fallbackDate: Date,
        colorIndex: Int
    ) -> [ProjectRevenueEvent] {
        guard bucket.hasRowLevelEntries else {
            guard bucket.effectiveTotalMinorUnits > 0 else { return [] }
            return [
                ProjectRevenueEvent(
                    date: bucket.updatedAt ?? fallbackDate,
                    amountMinorUnits: bucket.effectiveTotalMinorUnits,
                    colorIndex: colorIndex
                ),
            ]
        }

        return bucket.timeEntries
            .map { entry in
                ProjectRevenueEvent(
                    date: entry.date,
                    amountMinorUnits: entry.billableAmountMinorUnits,
                    colorIndex: colorIndex
                )
            }
            .filter { $0.amountMinorUnits > 0 }
            + bucket.fixedCostEntries
            .map { fixedCost in
                ProjectRevenueEvent(
                    date: fixedCost.date,
                    amountMinorUnits: fixedCost.amountMinorUnits,
                    colorIndex: colorIndex
                )
            }
            .filter { $0.amountMinorUnits > 0 }
    }
}

extension WorkspaceSnapshot {
    func dashboardSummary(on date: Date = .now) -> DashboardSummary {
        WorkspaceDashboardProjections.summary(for: self, on: date)
    }
}

struct DashboardSummary: Equatable {
    var outstandingMinorUnits: Int
    var overdueMinorUnits: Int
    var readyToInvoiceMinorUnits: Int
    var thisMonthMinorUnits: Int
    var activeProjectCount: Int
    var clientCount: Int
    var needsAttention: [DashboardAttentionItem]
    var unbilledProjectRevenue: [ProjectRevenuePoint]
    var unbilledRevenueHistory: [ProjectRevenueHistoryPoint]
    var revenueHistory: [RevenuePoint]
}

enum DashboardAttentionTarget: Equatable {
    case invoice(WorkspaceInvoice.ID)
    case bucket(projectID: WorkspaceProject.ID, bucketID: WorkspaceBucket.ID)
}

struct DashboardAttentionItem: Equatable, Identifiable {
    var id: String
    var target: DashboardAttentionTarget
    var title: String
    var detail: String
    var amountMinorUnits: Int
    var tone: BillbiStatusTone
}

struct RevenuePoint: Equatable, Identifiable {
    var date: Date
    var label: String
    var amountMinorUnits: Int

    init(date: Date = .distantPast, label: String, amountMinorUnits: Int) {
        self.date = date
        self.label = label
        self.amountMinorUnits = amountMinorUnits
    }

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(label)"
    }
}

struct ProjectRevenuePoint: Equatable, Identifiable {
    var projectID: WorkspaceProject.ID
    var projectName: String
    var amountMinorUnits: Int
    var colorIndex: Int

    var id: WorkspaceProject.ID {
        projectID
    }
}

struct ProjectRevenueHistoryPoint: Equatable, Identifiable {
    var projectID: WorkspaceProject.ID
    var date: Date
    var label: String
    var amountMinorUnits: Int
    var colorIndex: Int

    var id: String {
        "\(projectID)-\(date.timeIntervalSinceReferenceDate)-\(amountMinorUnits)-\(colorIndex)"
    }
}

private struct ProjectRevenueEvent: Equatable {
    var date: Date
    var amountMinorUnits: Int
    var colorIndex: Int
}
