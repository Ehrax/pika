import SwiftUI

struct DashboardView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    var body: some View {
        let summary = workspace.dashboardSummary(on: currentDate)

        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                metricStrip(summary: summary)

                lowerPanels(summary: summary)
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
            SectionHeader(title: "Revenue · 12 mo", detail: "\(summary.revenueHistory.first?.label ?? "") - \(summary.revenueHistory.last?.label ?? "")")

            VStack(alignment: .leading, spacing: PikaSpacing.md) {
                Text(money(summary.revenueHistory.map(\.amountMinorUnits).reduce(0, +)))
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PikaColor.textPrimary)

                Text("Up 18% vs previous period")
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.success)

                RevenueSparkline(points: summary.revenueHistory)
                    .frame(height: 120)

                HStack {
                    Text(summary.revenueHistory.first?.label ?? "")
                    Spacer()
                    Text(summary.revenueHistory.last?.label ?? "")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(PikaColor.textMuted)
            }
            .padding(PikaSpacing.md)
            .pikaSurface()
        }
    }

    private func money(_ minorUnits: Int) -> String {
        formatter.string(fromMinorUnits: minorUnits)
    }
}

private struct RevenueSparkline: View {
    let points: [RevenuePoint]

    var body: some View {
        GeometryReader { proxy in
            let samples = normalizedPoints(in: proxy.size)
            ZStack {
                SparklineArea(points: samples)
                    .fill(
                        LinearGradient(
                            colors: [PikaColor.accent.opacity(0.28), PikaColor.accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                SparklineLine(points: samples)
                    .stroke(PikaColor.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = samples.last {
                    Circle()
                        .fill(PikaColor.accent)
                        .frame(width: 7, height: 7)
                        .position(last)
                }
            }
        }
        .accessibilityLabel("Twelve month revenue sparkline")
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard points.count > 1, let maxAmount = points.map(\.amountMinorUnits).max(), maxAmount > 0 else {
            return []
        }

        let padding: CGFloat = 4
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)
        let step = availableWidth / CGFloat(points.count - 1)

        return points.enumerated().map { index, point in
            let x = padding + CGFloat(index) * step
            let y = padding + (1 - CGFloat(point.amountMinorUnits) / CGFloat(maxAmount)) * availableHeight
            return CGPoint(x: x, y: y)
        }
    }
}

private struct SparklineLine: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct SparklineArea: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = SparklineLine(points: points).path(in: rect)
        guard let first = points.first, let last = points.last else { return path }

        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        path.closeSubpath()
        return path
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
