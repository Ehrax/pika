import Foundation

enum SettingsCategory: String, CaseIterable, Identifiable {
    case profile
    case invoicing
    case tax
    case payment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile:
            String(localized: "Profile")
        case .invoicing:
            String(localized: "Invoicing")
        case .tax:
            String(localized: "Tax")
        case .payment:
            String(localized: "Payment")
        }
    }

    var detail: String {
        switch self {
        case .profile:
            String(localized: "Used on every invoice header and PDF.")
        case .invoicing:
            String(localized: "Numbering, currency, and payment terms.")
        case .tax:
            String(localized: "Identifiers for invoice compliance.")
        case .payment:
            String(localized: "Bank details printed in invoice footers.")
        }
    }

    var systemImage: String {
        switch self {
        case .profile:
            "person.crop.square"
        case .invoicing:
            "doc.text"
        case .tax:
            "percent"
        case .payment:
            "creditcard"
        }
    }
}

struct SettingsSaveFailure: Identifiable {
    let id = UUID()
    let message: String
}
