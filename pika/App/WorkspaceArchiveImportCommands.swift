#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceArchiveImportCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("Import Workspace Archive…") {
                WorkspaceArchiveImportCommand.run()
            }
            .keyboardShortcut("I", modifiers: [.command, .shift])
        }
    }
}

@MainActor
private enum WorkspaceArchiveImportCommand {
    private static let archiveType = UTType(filenameExtension: "pikaarchive")

    static func run() {
        let panel = NSOpenPanel()
        panel.title = "Import Workspace Archive"
        panel.message = "Choose a .pikaarchive file to validate before replacing your workspace."
        panel.prompt = "Validate"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false

        if let archiveType {
            panel.allowedContentTypes = [archiveType]
        }

        guard panel.runModal() == .OK, let archiveURL = panel.url else {
            return
        }

        do {
            let archiveData = try Data(contentsOf: archiveURL)
            let summary = try WorkspaceArchiveImportValidator.validateAndSummarize(archiveData)
            showConfirmation(summary: summary)
        } catch {
            showValidationError(error)
        }
    }

    private static func showConfirmation(summary: WorkspaceArchiveImportSummary) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Replace Current Workspace?"
        alert.informativeText = "\(formattedSummary(summary))\n\nContinuing will replace the current workspace and cannot be undone."
        alert.addButton(withTitle: "Replace Workspace")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        let pendingAlert = NSAlert()
        pendingAlert.alertStyle = .informational
        pendingAlert.messageText = "Replacement Not Implemented Yet"
        pendingAlert.informativeText = "Archive validation completed. Actual workspace replacement is tracked in a follow-up step."
        pendingAlert.addButton(withTitle: "OK")
        pendingAlert.runModal()
    }

    private static func showValidationError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Archive Import Failed"
        alert.informativeText = message(for: error)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func formattedSummary(_ summary: WorkspaceArchiveImportSummary) -> String {
        [
            "Clients: \(summary.clientCount)",
            "Projects: \(summary.projectCount)",
            "Buckets: \(summary.bucketCount)",
            "Time Entries: \(summary.timeEntryCount)",
            "Fixed Costs: \(summary.fixedCostCount)",
            "Invoices: \(summary.invoiceCount)",
        ].joined(separator: " · ")
    }

    private static func message(for error: Error) -> String {
        switch error {
        case WorkspaceArchiveError.unsupportedFormat(let format):
            return "Unsupported archive format: \(format)."
        case WorkspaceArchiveError.unsupportedVersion(let version):
            return "Unsupported archive version: \(version)."
        case WorkspaceArchiveImportError.duplicateEntityID(let entity, let id):
            return "Duplicate \(entity) identity found: \(id.uuidString)."
        case WorkspaceArchiveImportError.missingRelationship(let entity, let id, let relationship, let targetID):
            return "\(entity) \(id.uuidString) references missing \(relationship): \(targetID.uuidString)."
        case WorkspaceArchiveImportError.invalidCurrencyCode(let field, let value):
            return "Invalid currency value in \(field): \(value)."
        case WorkspaceArchiveImportError.invalidMoneyValue(let field, let value):
            return "Invalid numeric value in \(field): \(value)."
        case WorkspaceArchiveImportError.invalidTermsDays(let field, let value):
            return "Invalid terms value in \(field): \(value)."
        case WorkspaceArchiveImportError.duplicateInvoiceNumber(let normalizedNumber):
            if normalizedNumber.isEmpty {
                return "Invoice numbers must not be empty."
            }
            return "Duplicate invoice number found after normalization: \(normalizedNumber)."
        case WorkspaceArchiveImportError.invoiceTotalMismatch(let invoiceID, let expected, let actual):
            return "Invoice \(invoiceID.uuidString) total mismatch. Expected \(expected), got \(actual)."
        case let decodingError as DecodingError:
            return "Archive decoding failed: \(decodingError.localizedDescription)"
        default:
            return "Archive validation failed: \(error.localizedDescription)"
        }
    }
}
#endif
