import Foundation

enum InvoiceWorkflowPolicy {
    static func canTransition(from source: InvoiceStatus, to target: InvoiceStatus) -> Bool {
        switch (source, target) {
        case (.finalized, .sent), (.finalized, .paid), (.finalized, .cancelled), (.sent, .paid), (.sent, .cancelled):
            true
        default:
            false
        }
    }

    static func canMarkSent(status: InvoiceStatus) -> Bool {
        status == .finalized
    }

    static func canMarkPaid(status: InvoiceStatus) -> Bool {
        status == .finalized || status == .sent
    }

    static func canCancel(status: InvoiceStatus) -> Bool {
        status == .finalized || status == .sent
    }

    static func statusTitle(status: InvoiceStatus, isOverdue: Bool) -> String {
        isOverdue ? "Overdue" : status.rawValue.capitalized
    }

    static func statusTone(status: InvoiceStatus, isOverdue: Bool) -> PikaStatusTone {
        if isOverdue { return .danger }

        switch status {
        case .finalized:
            return .warning
        case .sent:
            return .neutral
        case .paid:
            return .success
        case .cancelled:
            return .neutral
        }
    }

    static func statusIconName(status: InvoiceStatus, isOverdue: Bool) -> String {
        if isOverdue { return "exclamationmark.circle" }

        switch status {
        case .finalized:
            return "doc.text"
        case .sent:
            return "paperplane"
        case .paid:
            return "checkmark.seal"
        case .cancelled:
            return "xmark.circle"
        }
    }
}
