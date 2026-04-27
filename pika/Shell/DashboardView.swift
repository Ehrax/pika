import SwiftUI

struct DashboardView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    var body: some View {
        let summary = workspace.dashboardSummary(on: currentDate)
        let activityItems = workspace.recentActivity

        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                metricStrip(summary: summary)

                lowerPanels(summary: summary)

                recentActivity(activityItems)
            }
            .padding(PikaSpacing.lg)
        }
        .background(PikaColor.background)
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItemGroup {
                Button {
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(true)
                .help("Search lands in a later task")

                Button {
                } label: {
                    Label("New Invoice", systemImage: "plus")
                }
                .disabled(true)
                .help("Invoice creation lands in a later task")
            }
        }
        .onAppear {
            AppTelemetry.dashboardLoaded(summary)
        }
        .accessibilityIdentifier("DashboardView")
    }

    private func lowerPanels(summary: DashboardSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: PikaSpacing.lg) {
                needsAttention(summary: summary)
                    .frame(minWidth: 480, maxWidth: .infinity, alignment: .topLeading)

                revenueHistory(summary: summary)
                    .frame(minWidth: 280, idealWidth: 300, maxWidth: 360, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                needsAttention(summary: summary)
                revenueHistory(summary: summary)
            }
        }
    }

    private func metricStrip(summary: DashboardSummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: PikaSpacing.md)],
            spacing: PikaSpacing.md
        ) {
            MetricTile(title: "Outstanding", value: money(summary.outstandingMinorUnits), tone: .neutral)
            MetricTile(title: "Overdue", value: money(summary.overdueMinorUnits), tone: .danger)
            MetricTile(title: "Ready to invoice", value: money(summary.readyToInvoiceMinorUnits), tone: .success)
            MetricTile(title: "This month", value: money(summary.thisMonthMinorUnits), tone: .warning)
        }
    }

    private func needsAttention(summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: PikaSpacing.md) {
            SectionHeader(title: "Needs Attention", detail: "\(summary.needsAttention.count) items")

            VStack(spacing: 0) {
                ForEach(summary.needsAttention) { item in
                    AttentionRow(item: item, amount: money(item.amountMinorUnits))

                    if item.id != summary.needsAttention.last?.id {
                        Divider()
                    }
                }
            }
            .pikaSurface()
        }
    }

    private func revenueHistory(summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: PikaSpacing.md) {
            SectionHeader(title: "Revenue", detail: "Simple history")

            VStack(alignment: .leading, spacing: PikaSpacing.md) {
                ForEach(summary.revenueHistory) { point in
                    HStack(spacing: PikaSpacing.sm) {
                        Text(point.label)
                            .font(PikaTypography.small.monospacedDigit())
                            .foregroundStyle(PikaColor.textSecondary)
                            .frame(width: 32, alignment: .leading)

                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: PikaRadius.sm)
                                .fill(PikaColor.accent)
                                .frame(width: barWidth(
                                    for: point,
                                    availableWidth: proxy.size.width,
                                    revenueHistory: summary.revenueHistory
                                ))
                        }
                        .frame(height: 9)

                        Text(money(point.amountMinorUnits))
                            .font(PikaTypography.small.monospacedDigit())
                            .foregroundStyle(PikaColor.textPrimary)
                            .frame(width: 86, alignment: .trailing)
                    }
                }
            }
            .padding(PikaSpacing.md)
            .pikaSurface()
        }
    }

    private func recentActivity(_ activityItems: [WorkspaceActivity]) -> some View {
        VStack(alignment: .leading, spacing: PikaSpacing.md) {
            SectionHeader(title: "Recent Activity", detail: "\(activityItems.count) events")

            VStack(spacing: 0) {
                if activityItems.isEmpty {
                    Text("No activity yet")
                        .font(PikaTypography.body)
                        .foregroundStyle(PikaColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(PikaSpacing.md)
                } else {
                    ForEach(activityItems) { activity in
                        ActivityRow(activity: activity)

                        if activity.id != activityItems.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .pikaSurface()
        }
    }

    private func money(_ minorUnits: Int) -> String {
        formatter.string(fromMinorUnits: minorUnits)
    }

    private func barWidth(
        for point: RevenuePoint,
        availableWidth: CGFloat,
        revenueHistory: [RevenuePoint]
    ) -> CGFloat {
        guard let maxAmount = revenueHistory.map(\.amountMinorUnits).max(), maxAmount > 0 else {
            return 0
        }

        return max(8, availableWidth * CGFloat(point.amountMinorUnits) / CGFloat(maxAmount))
    }
}

private struct ActivityRow: View {
    var activity: WorkspaceActivity

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: PikaSpacing.md) {
                titleBlock
                    .layoutPriority(1)

                Spacer(minLength: PikaSpacing.sm)

                dateText
            }
            .padding(.horizontal, PikaSpacing.md)
            .padding(.vertical, PikaSpacing.sm)

            VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                titleBlock
                dateText
            }
            .padding(PikaSpacing.md)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(activity.message)
                .font(PikaTypography.body.weight(.medium))
                .foregroundStyle(PikaColor.textPrimary)
                .lineLimit(1)
            Text(activity.detail)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textSecondary)
                .lineLimit(1)
        }
    }

    private var dateText: some View {
        Text(activity.occurredAt.formatted(.dateTime.month(.abbreviated).day()))
            .font(PikaTypography.small.monospacedDigit())
            .foregroundStyle(PikaColor.textMuted)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct AttentionRow: View {
    var item: DashboardAttentionItem
    var amount: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: PikaSpacing.md) {
                badge

                titleBlock
                    .frame(minWidth: 220, alignment: .leading)
                    .layoutPriority(1)

                Spacer(minLength: PikaSpacing.sm)

                amountText
            }
            .padding(PikaSpacing.md)

            VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: PikaSpacing.md) {
                    badge
                    Spacer(minLength: PikaSpacing.sm)
                    amountText
                }

                titleBlock
            }
            .padding(PikaSpacing.md)
        }
    }

    private var badge: some View {
        StatusBadge(item.tone, title: item.tone == .danger ? "Overdue" : "Ready")
            .fixedSize(horizontal: true, vertical: false)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(PikaTypography.body.weight(.medium))
                .foregroundStyle(PikaColor.textPrimary)
                .lineLimit(2)
            Text(item.detail)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textSecondary)
                .lineLimit(2)
        }
    }

    private var amountText: some View {
        Text(amount)
            .font(.body.monospacedDigit())
            .foregroundStyle(PikaColor.textPrimary)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MetricTile: View {
    var title: String
    var value: String
    var tone: PikaStatusTone

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            HStack {
                Text(title)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textSecondary)
                Spacer()
                Circle()
                    .fill(tone.color)
                    .frame(width: 7, height: 7)
            }

            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(PikaColor.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(PikaSpacing.md)
        .pikaSurface()
    }
}
