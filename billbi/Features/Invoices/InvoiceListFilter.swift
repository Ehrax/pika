import Foundation

enum InvoiceListFilter: String, CaseIterable, Equatable, Identifiable {
    case all = "All"
    case finalized = "Finalized"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .all:
            String(localized: "All")
        case .finalized:
            String(localized: "Finalized")
        case .sent:
            String(localized: "Sent")
        case .paid:
            String(localized: "Paid")
        case .overdue:
            String(localized: "Overdue")
        case .cancelled:
            String(localized: "Cancelled")
        }
    }

    var sectionTitle: String {
        switch self {
        case .all:
            String(localized: "All Invoices")
        case .finalized:
            String(localized: "Finalized Invoices")
        case .sent:
            String(localized: "Sent Invoices")
        case .paid:
            String(localized: "Paid Invoices")
        case .overdue:
            String(localized: "Overdue Invoices")
        case .cancelled:
            String(localized: "Cancelled Invoices")
        }
    }

    var tone: BillbiStatusTone? {
        switch self {
        case .all:
            nil
        case .finalized:
            .warning
        case .sent:
            .info
        case .paid:
            .success
        case .overdue:
            .danger
        case .cancelled:
            .neutral
        }
    }

    func count(in summary: InvoiceListSummary) -> Int {
        switch self {
        case .all:
            summary.total
        case .finalized:
            summary.finalized
        case .sent:
            summary.sent
        case .paid:
            summary.paid
        case .overdue:
            summary.overdue
        case .cancelled:
            summary.cancelled
        }
    }

    func includes(_ row: WorkspaceInvoiceRowProjection) -> Bool {
        switch self {
        case .all:
            true
        case .finalized:
            row.status == .finalized && !row.isOverdue
        case .sent:
            row.status == .sent && !row.isOverdue
        case .paid:
            row.status == .paid
        case .overdue:
            row.isOverdue
        case .cancelled:
            row.status == .cancelled
        }
    }
}

struct InvoiceListSummary {
    let total: Int
    let finalized: Int
    let sent: Int
    let paid: Int
    let overdue: Int
    let cancelled: Int

    init(rows: [WorkspaceInvoiceRowProjection]) {
        total = rows.count
        finalized = rows.filter { $0.status == .finalized && !$0.isOverdue }.count
        sent = rows.filter { $0.status == .sent && !$0.isOverdue }.count
        paid = rows.filter { $0.status == .paid }.count
        overdue = rows.filter(\.isOverdue).count
        cancelled = rows.filter { $0.status == .cancelled }.count
    }

    var displayText: String {
        String(
            localized: "\(total) total · \(finalized) finalized · \(sent) sent · \(paid) paid · \(overdue) overdue · \(cancelled) cancelled"
        )
    }
}
