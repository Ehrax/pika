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
