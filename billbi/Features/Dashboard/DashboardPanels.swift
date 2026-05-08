import SwiftUI

struct DashboardMetricStrip: View {
    let summary: DashboardSummary
    let money: (Int) -> String

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: BillbiSpacing.md)],
            spacing: BillbiSpacing.md
        ) {
            MetricTile(title: "Outstanding", value: money(summary.outstandingMinorUnits), tone: .neutral)
            MetricTile(title: "Overdue", value: money(summary.overdueMinorUnits), tone: .danger)
            MetricTile(title: "Ready to invoice", value: money(summary.readyToInvoiceMinorUnits), tone: .success)
            MetricTile(title: "This month", value: money(summary.thisMonthMinorUnits), tone: .warning)
        }
    }
}

struct DashboardNeedsAttentionPanel: View {
    let summary: DashboardSummary
    let money: (Int) -> String
    let onSelectAttentionItem: (DashboardAttentionItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            SectionHeader(
                title: "Needs Attention",
                detail: String(localized: "\(summary.needsAttention.count) items")
            )

            VStack(spacing: 0) {
                ForEach(summary.needsAttention) { item in
                    Button {
                        onSelectAttentionItem(item)
                    } label: {
                        AttentionRow(item: item, amount: money(item.amountMinorUnits))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(attentionAccessibilityHint(for: item))

                    if item.id != summary.needsAttention.last?.id {
                        Divider()
                    }
                }
            }
            .billbiSurface()
        }
    }

    private func attentionAccessibilityHint(for item: DashboardAttentionItem) -> String {
        switch item.target {
        case .invoice:
            String(localized: "Open this invoice")
        case .bucket:
            String(localized: "Open this bucket")
        }
    }
}

struct DashboardRevenueHistoryPanel: View {
    let summary: DashboardSummary
    let currentDate: Date
    let chartHeight: CGFloat
    let money: (Int) -> String
    @Binding var selectedRevenueRange: DashboardRevenueRange

    var body: some View {
        let visiblePoints = selectedRevenueRange.visiblePoints(from: summary.revenueHistory, endingAt: currentDate)

        return VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            revenueHeader(visiblePoints: visiblePoints)

            VStack(alignment: .leading, spacing: BillbiSpacing.md) {
                Text(money(visiblePoints.map(\.amountMinorUnits).reduce(0, +)))
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(BillbiColor.textPrimary)

                RevenueSparkline(points: visiblePoints)
                    .frame(height: chartHeight)

                HStack {
                    Text(visiblePoints.first?.label ?? "")
                    Spacer()
                    Text(visiblePoints.last?.label ?? "")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(BillbiColor.textMuted)
            }
            .padding(BillbiSpacing.md)
            .frame(height: DashboardPanelLayoutPolicy.revenuePanelContentHeight, alignment: .topLeading)
            .billbiSurface()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: selectedRevenueRange) { _, newRange in
            AppTelemetry.dashboardRevenueRangeSelected(
                range: newRange.rawValue,
                visiblePointCount: newRange.visiblePoints(from: summary.revenueHistory, endingAt: currentDate).count
            )
        }
    }

    private func revenueHeader(visiblePoints: [RevenuePoint]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: BillbiSpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: BillbiSpacing.sm) {
                    Text(String(localized: "Revenue · \(selectedRevenueRange.displayTitle)"))
                        .font(BillbiTypography.subheading)
                        .foregroundStyle(BillbiColor.textPrimary)

                    Text(revenueRangeDetail(visiblePoints))
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                }

                Spacer(minLength: BillbiSpacing.md)

                revenueRangePicker()
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                SectionHeader(
                    title: String(localized: "Revenue · \(selectedRevenueRange.displayTitle)"),
                    detail: revenueRangeDetail(visiblePoints)
                )

                revenueRangePicker()
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func revenueRangePicker() -> some View {
        Picker("Revenue range", selection: $selectedRevenueRange) {
            ForEach(DashboardRevenueRange.allCases) { range in
                Text(range.displayTitle).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .accessibilityHint("Changes the visible revenue period")
    }

    private func revenueRangeDetail(_ points: [RevenuePoint]) -> String {
        "\(points.first?.label ?? "") - \(points.last?.label ?? "")"
    }
}

struct DashboardUnbilledProjectRevenuePanel: View {
    let summary: DashboardSummary
    let chartHeight: CGFloat
    let money: (Int) -> String
    @Binding var selectedUnbilledProjectID: WorkspaceProject.ID?

    var body: some View {
        let points = summary.unbilledProjectRevenue
            .sorted { left, right in
                if left.amountMinorUnits == right.amountMinorUnits {
                    return left.projectName < right.projectName
                }

                return left.amountMinorUnits > right.amountMinorUnits
            }
        let selectedPoint = selectedUnbilledProject(from: points)
        let selectedHistory = selectedPoint.map { selectedPoint in
            summary.unbilledRevenueHistory.filter { $0.projectID == selectedPoint.projectID }
        } ?? []

        return VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            unbilledProjectHeader(projects: points, selectedProject: selectedPoint)

            VStack(alignment: .leading, spacing: BillbiSpacing.md) {
                Text(money(selectedPoint?.amountMinorUnits ?? 0))
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(BillbiColor.textPrimary)

                ProjectRevenueSparkline(points: selectedHistory)
                    .frame(height: chartHeight)

                HStack {
                    Text(selectedHistory.first?.label ?? "")
                    Spacer()
                    Text(selectedHistory.last?.label ?? "")
                }
                .font(.caption)
                .foregroundStyle(BillbiColor.textMuted)
            }
            .padding(BillbiSpacing.md)
            .frame(height: DashboardPanelLayoutPolicy.revenuePanelContentHeight, alignment: .topLeading)
            .billbiSurface()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectedUnbilledProject(from projects: [ProjectRevenuePoint]) -> ProjectRevenuePoint? {
        projects.first { $0.projectID == selectedUnbilledProjectID } ?? projects.first
    }

    private func unbilledProjectHeader(
        projects: [ProjectRevenuePoint],
        selectedProject: ProjectRevenuePoint?
    ) -> some View {
        HStack(alignment: .center, spacing: BillbiSpacing.md) {
            Text("Unbilled · Projects")
                .font(BillbiTypography.subheading)
                .foregroundStyle(BillbiColor.textPrimary)

            Spacer(minLength: BillbiSpacing.md)

            Menu {
                ForEach(projects) { project in
                    Button {
                        selectedUnbilledProjectID = project.projectID
                    } label: {
                        Text(project.projectName)
                    }
                }
            } label: {
                HStack(spacing: BillbiSpacing.xs) {
                    Text(selectedProject?.projectName ?? "No projects")
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BillbiColor.textMuted)
                }
                .font(BillbiTypography.small)
                .padding(.horizontal, BillbiSpacing.sm)
                .padding(.vertical, BillbiSpacing.xs)
                .background(BillbiColor.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.sm))
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(projects.isEmpty)
            .accessibilityLabel("Unbilled project")
            .accessibilityHint("Changes the project shown in the unbilled revenue chart")
        }
    }
}
