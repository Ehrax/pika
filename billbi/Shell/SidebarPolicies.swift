import SwiftUI

struct PrimarySidebarColumnLayout: Equatable {
    static let minimumWidth = 220.0
    static let idealWidth = 242.0
    static let maximumWidth = 520.0
    static let widthStorageKey = "billbi.primarySidebar.width"

    static func clamped(_ width: Double) -> Double {
        min(max(width, minimumWidth), maximumWidth)
    }
}

struct SidebarProjectsDisclosurePolicy: Equatable {
    static let isExpandedByDefault = true
    static let disclosurePlacement = SidebarDisclosurePlacement.leading

    static func showsDisclosure(activeProjectCount: Int) -> Bool {
        activeProjectCount > 0
    }
}

enum SidebarDisclosurePlacement: Equatable {
    case leading
    case trailing
}

struct SidebarProjectsFolderRowLayout: Equatable {
    static let listInsets = SidebarRowInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
}

struct SidebarRowInsets: Equatable {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat

    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

struct SidebarProjectRowLayout: Equatable {
    static let listInsets = SidebarRowInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
    static let contentLeadingPadding: CGFloat = 24
    static let contentHorizontalPadding = BillbiSpacing.sm
    static let expandsSelectionToAvailableWidth = true
    static let displaysProjectDot = true
    static let projectDotSize: CGFloat = 7
    static let displaysClientSubtitle = false
}

enum SidebarProjectDotPalette {
    static let colors = ProjectColorPalette.colors

    static var colorCount: Int {
        ProjectColorPalette.colorCount
    }

    static func color(forProjectAt index: Int) -> Color {
        ProjectColorPalette.color(forProjectAt: index)
    }

    static func colorIndex(forProjectAt index: Int) -> Int {
        ProjectColorPalette.colorIndex(forProjectAt: index)
    }
}

enum SidebarProjectSelectionTreatment: Equatable {
    case none
    case primarySidebarSelection
}

struct SidebarProjectRowAppearance: Equatable {
    let isSelected: Bool

    var selectionTreatment: SidebarProjectSelectionTreatment {
        isSelected ? .primarySidebarSelection : .none
    }

    var selectionBackgroundColor: Color? {
        switch selectionTreatment {
        case .none:
            nil
        case .primarySidebarSelection:
            BillbiColor.primarySidebarSelection
        }
    }

    var textColor: Color {
        switch selectionTreatment {
        case .none:
            BillbiColor.textPrimary
        case .primarySidebarSelection:
            Color.white
        }
    }
}
