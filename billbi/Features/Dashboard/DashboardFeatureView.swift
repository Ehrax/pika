import SwiftUI

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
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                DashboardMetricStrip(summary: summary, money: money)

                dashboardPanels(summary: summary)
            }
            .padding(BillbiSpacing.md)
        }
        .background(BillbiColor.background)
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
        VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
            revenuePanelGrid(summary: summary)

            ForEach(DashboardPanelLayoutPolicy.stackedOrder, id: \.self) { panel in
                dashboardPanel(panel, summary: summary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func revenuePanelGrid(summary: DashboardSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: BillbiSpacing.lg) {
                ForEach(DashboardPanelLayoutPolicy.revenuePanels, id: \.self) { panel in
                    dashboardPanel(panel, summary: summary)
                        .frame(minWidth: DashboardPanelLayoutPolicy.revenuePanelMinimumWidth, maxWidth: .infinity, alignment: .topLeading)
                }
            }

            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
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
            DashboardUnbilledProjectRevenuePanel(
                summary: summary,
                chartHeight: DashboardPanelLayoutPolicy.revenueChartHeight,
                money: money,
                selectedUnbilledProjectID: $selectedUnbilledProjectID
            )
        case .revenueHistory:
            DashboardRevenueHistoryPanel(
                summary: summary,
                currentDate: currentDate,
                chartHeight: DashboardPanelLayoutPolicy.revenueChartHeight,
                money: money,
                selectedRevenueRange: $selectedRevenueRange
            )
        case .needsAttention:
            DashboardNeedsAttentionPanel(
                summary: summary,
                money: money,
                onSelectAttentionItem: onSelectAttentionItem
            )
        }
    }

    private func money(_ minorUnits: Int) -> String {
        formatter.string(fromMinorUnits: minorUnits)
    }
}
