import SwiftUI

enum DashboardPanel: String, Hashable {
    case unbilledProjectRevenue
    case revenueHistory
    case needsAttention
}

enum DashboardPanelLayoutMode: Equatable {
    case stackedAtAllWidths
}

struct DashboardPanelLayoutPolicy: Equatable {
    static let layoutMode: DashboardPanelLayoutMode = .stackedAtAllWidths
    static let revenuePanels: [DashboardPanel] = [.unbilledProjectRevenue, .revenueHistory]
    static let stackedOrder: [DashboardPanel] = [.needsAttention]
    static let revenuePanelMinimumWidth: CGFloat = 360
    static let revenueChartHeight: CGFloat = 220
    static let revenuePanelContentHeight: CGFloat = 290
}

struct DashboardFeatureView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date
    let onSelectAttentionItem: (DashboardAttentionItem) -> Void

    @State private var selectedRevenueRange: DashboardRevenueRange = .twelveMonths
    @State private var selectedUnbilledProjectID: WorkspaceProject.ID?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    init(
        workspace: WorkspaceSnapshot,
        currentDate: Date,
        onSelectAttentionItem: @escaping (DashboardAttentionItem) -> Void = { _ in }
    ) {
        self.workspace = workspace
        self.currentDate = currentDate
        self.onSelectAttentionItem = onSelectAttentionItem
    }

    var body: some View {
        let summary = workspace.dashboardSummary(on: currentDate)

        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                metricStrip(summary: summary)

                dashboardPanels(summary: summary)
            }
            .padding(PikaSpacing.md)
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

    private func dashboardPanels(summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: PikaSpacing.lg) {
            revenuePanelGrid(summary: summary)

            ForEach(DashboardPanelLayoutPolicy.stackedOrder, id: \.self) { panel in
                dashboardPanel(panel, summary: summary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func revenuePanelGrid(summary: DashboardSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: PikaSpacing.lg) {
                ForEach(DashboardPanelLayoutPolicy.revenuePanels, id: \.self) { panel in
                    dashboardPanel(panel, summary: summary)
                        .frame(minWidth: DashboardPanelLayoutPolicy.revenuePanelMinimumWidth, maxWidth: .infinity, alignment: .topLeading)
                }
            }

            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                ForEach(DashboardPanelLayoutPolicy.revenuePanels, id: \.self) { panel in
                    dashboardPanel(panel, summary: summary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dashboardPanel(_ panel: DashboardPanel, summary: DashboardSummary) -> some View {
        switch panel {
        case .unbilledProjectRevenue:
            unbilledProjectRevenue(summary: summary, chartHeight: DashboardPanelLayoutPolicy.revenueChartHeight)
        case .revenueHistory:
            revenueHistory(summary: summary, chartHeight: DashboardPanelLayoutPolicy.revenueChartHeight)
        case .needsAttention:
            needsAttention(summary: summary)
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
            .pikaSurface()
        }
    }

    private func revenueHistory(summary: DashboardSummary, chartHeight: CGFloat) -> some View {
        let visiblePoints = selectedRevenueRange.visiblePoints(from: summary.revenueHistory, endingAt: currentDate)

        return VStack(alignment: .leading, spacing: PikaSpacing.md) {
            revenueHeader(visiblePoints: visiblePoints)

            VStack(alignment: .leading, spacing: PikaSpacing.md) {
                Text(money(visiblePoints.map(\.amountMinorUnits).reduce(0, +)))
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PikaColor.textPrimary)

                RevenueSparkline(points: visiblePoints)
                    .frame(height: chartHeight)

                HStack {
                    Text(visiblePoints.first?.label ?? "")
                    Spacer()
                    Text(visiblePoints.last?.label ?? "")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(PikaColor.textMuted)
            }
            .padding(PikaSpacing.md)
            .frame(height: DashboardPanelLayoutPolicy.revenuePanelContentHeight, alignment: .topLeading)
            .pikaSurface()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: selectedRevenueRange) { _, newRange in
            AppTelemetry.dashboardRevenueRangeSelected(
                range: newRange.rawValue,
                visiblePointCount: newRange.visiblePoints(from: summary.revenueHistory, endingAt: currentDate).count
            )
        }
    }

    private func unbilledProjectRevenue(summary: DashboardSummary, chartHeight: CGFloat) -> some View {
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

        return VStack(alignment: .leading, spacing: PikaSpacing.md) {
            unbilledProjectHeader(projects: points, selectedProject: selectedPoint)

            VStack(alignment: .leading, spacing: PikaSpacing.md) {
                Text(money(selectedPoint?.amountMinorUnits ?? 0))
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PikaColor.textPrimary)

                ProjectRevenueSparkline(points: selectedHistory)
                    .frame(height: chartHeight)

                HStack {
                    Text(selectedHistory.first?.label ?? "")
                    Spacer()
                    Text(selectedHistory.last?.label ?? "")
                }
                .font(.caption)
                .foregroundStyle(PikaColor.textMuted)
            }
            .padding(PikaSpacing.md)
            .frame(height: DashboardPanelLayoutPolicy.revenuePanelContentHeight, alignment: .topLeading)
            .pikaSurface()
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
        HStack(alignment: .center, spacing: PikaSpacing.md) {
            Text("Unbilled · Projects")
                .font(PikaTypography.subheading)
                .foregroundStyle(PikaColor.textPrimary)

            Spacer(minLength: PikaSpacing.md)

            Menu {
                ForEach(projects) { project in
                    Button {
                        selectedUnbilledProjectID = project.projectID
                    } label: {
                        Text(project.projectName)
                    }
                }
            } label: {
                HStack(spacing: PikaSpacing.xs) {
                    Text(selectedProject?.projectName ?? "No projects")
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PikaColor.textMuted)
                }
                .font(PikaTypography.small)
                .padding(.horizontal, PikaSpacing.sm)
                .padding(.vertical, PikaSpacing.xs)
                .background(PikaColor.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: PikaRadius.sm))
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(projects.isEmpty)
            .accessibilityLabel("Unbilled project")
            .accessibilityHint("Changes the project shown in the unbilled revenue chart")
        }
    }

    private func revenueHeader(visiblePoints: [RevenuePoint]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: PikaSpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: PikaSpacing.sm) {
                    Text("Revenue · \(selectedRevenueRange.rawValue)")
                        .font(PikaTypography.subheading)
                        .foregroundStyle(PikaColor.textPrimary)

                    Text(revenueRangeDetail(visiblePoints))
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textSecondary)
                }

                Spacer(minLength: PikaSpacing.md)

                revenueRangePicker()
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                SectionHeader(title: "Revenue · \(selectedRevenueRange.rawValue)", detail: revenueRangeDetail(visiblePoints))

                revenueRangePicker()
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func revenueRangePicker() -> some View {
        Picker("Revenue range", selection: $selectedRevenueRange) {
            ForEach(DashboardRevenueRange.allCases) { range in
                Text(range.rawValue).tag(range)
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

    private func money(_ minorUnits: Int) -> String {
        formatter.string(fromMinorUnits: minorUnits)
    }

    private func attentionAccessibilityHint(for item: DashboardAttentionItem) -> String {
        switch item.target {
        case .invoice:
            "Open this invoice"
        case .bucket:
            "Open this bucket"
        }
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

private struct ProjectRevenueSparkline: View {
    let points: [ProjectRevenueHistoryPoint]

    var body: some View {
        GeometryReader { proxy in
            let samples = normalizedPoints(in: proxy.size)

            ZStack {
                if samples.isEmpty {
                    Text("No unbilled revenue yet")
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    SparklineArea(points: samples.map(\.point))
                        .fill(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.28), primaryColor.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    SparklineLine(points: samples.map(\.point))
                        .stroke(primaryColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    ForEach(samples) { sample in
                        Circle()
                            .fill(sample.color)
                            .frame(width: 7, height: 7)
                            .position(sample.point)
                    }
                }
            }
        }
        .accessibilityLabel("Unbilled revenue sparkline by project")
    }

    private var primaryColor: Color {
        points.first.map(color(for:)) ?? PikaColor.accent
    }

    private func normalizedPoints(in size: CGSize) -> [ProjectSparklineSample] {
        guard !points.isEmpty, let maxAmount = points.map(\.amountMinorUnits).max(), maxAmount > 0 else {
            return []
        }

        let padding: CGFloat = 4
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)
        let step = points.count > 1 ? availableWidth / CGFloat(points.count - 1) : availableWidth
        let orderedPoints = points.count > 1 ? points : [
            points[0],
            points[0],
        ]

        return orderedPoints.enumerated().map { index, point in
            let x = points.count > 1 ? padding + CGFloat(index) * step : padding + CGFloat(index) * step
            let y = padding + (1 - CGFloat(point.amountMinorUnits) / CGFloat(maxAmount)) * availableHeight
            return ProjectSparklineSample(id: "\(point.id)-\(index)", point: CGPoint(x: x, y: y), color: color(for: point))
        }
    }

    private func color(for point: ProjectRevenueHistoryPoint) -> Color {
        PikaColor.projectDotPalette[point.colorIndex % PikaColor.projectDotPalette.count]
    }
}

private struct ProjectSparklineSample: Identifiable {
    let id: String
    let point: CGPoint
    let color: Color
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
            HStack(alignment: .firstTextBaseline, spacing: PikaSpacing.md) {
                badge

                inlineDescription
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

                inlineDescription
            }
            .padding(PikaSpacing.md)
        }
    }

    private var badge: some View {
        StatusBadge(item.tone, title: item.tone == .danger ? "Overdue" : "Ready")
            .fixedSize(horizontal: true, vertical: false)
    }

    private var inlineDescription: some View {
        HStack(alignment: .firstTextBaseline, spacing: PikaSpacing.xs) {
            Text(item.title)
                .font(PikaTypography.body.weight(.medium))
                .foregroundStyle(PikaColor.textPrimary)
                .lineLimit(1)

            Text(item.detail)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textSecondary)
                .lineLimit(1)
        }
        .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
    }

    private var amountText: some View {
        Text(amount)
            .font(PikaTypography.body.monospacedDigit())
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
