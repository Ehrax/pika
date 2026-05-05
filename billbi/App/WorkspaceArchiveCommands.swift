import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

enum WorkspaceArchiveFileMenuCommandSurface {
    static let exportWorkspaceArchiveTitle = "Export Workspace Archive…"
    static let importWorkspaceArchiveTitle = "Import Workspace Archive…"
    static let revealWorkspaceBackupsTitle = "Reveal Workspace Backups"
    static let commandTitles = [
        exportWorkspaceArchiveTitle,
        importWorkspaceArchiveTitle,
        revealWorkspaceBackupsTitle,
    ]

#if os(macOS)
    static let commandGroupTypeNames = [
        String(describing: WorkspaceArchiveCommands.self),
    ]

    @CommandsBuilder
    static var commands: some Commands {
        WorkspaceArchiveCommands()
    }
#endif
}

#if os(macOS)
struct WorkspaceArchiveCommands: Commands {
    @FocusedValue(\.workspaceStore) private var workspaceStore

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()

            Button {
                importWorkspaceArchive()
            } label: {
                Label(
                    WorkspaceArchiveFileMenuCommandSurface.importWorkspaceArchiveTitle,
                    systemImage: "square.and.arrow.down"
                )
            }
            .keyboardShortcut("I", modifiers: [.command, .shift])
            .disabled(workspaceStore == nil)

            Button {
                exportWorkspaceArchive()
            } label: {
                Label(
                    WorkspaceArchiveFileMenuCommandSurface.exportWorkspaceArchiveTitle,
                    systemImage: "square.and.arrow.up"
                )
            }
            .keyboardShortcut("E", modifiers: [.command, .shift])
            .disabled(workspaceStore == nil)

            Button {
                revealWorkspaceBackups()
            } label: {
                Label(
                    WorkspaceArchiveFileMenuCommandSurface.revealWorkspaceBackupsTitle,
                    systemImage: "folder"
                )
            }
        }
    }

    private func importWorkspaceArchive() {
        guard let workspaceStore else { return }

        let panel = NSOpenPanel()
        panel.title = "Import Workspace Archive"
        panel.message = "Choose a .billbiarchive file to validate before replacing your workspace."
        panel.prompt = "Validate"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false

        if let archiveType = UTType(filenameExtension: "billbiarchive") {
            panel.allowedContentTypes = [archiveType]
        }

        guard panel.runModal() == .OK, let archiveURL = panel.url else {
            return
        }

        do {
            let archiveData = try Data(contentsOf: archiveURL)
            let summary = try workspaceStore.validateImportedWorkspaceArchive(archiveData)
            try runConfirmedReplacement(
                summary: summary,
                archiveData: archiveData,
                workspaceStore: workspaceStore
            )
        } catch {
            showImportError(error)
        }
    }

    private func exportWorkspaceArchive() {
        guard let workspaceStore else { return }

        do {
            try WorkspaceArchiveActions.export(workspaceStore: workspaceStore)
        } catch {
            AppTelemetry.workspaceArchiveExportFailed(message: String(describing: error))
        }
    }

    private func revealWorkspaceBackups() {
        do {
            try WorkspaceArchiveActions.revealWorkspaceBackups()
        } catch {
            AppTelemetry.workspaceArchiveBackupRevealFailed(message: String(describing: error))
        }
    }

    private func runConfirmedReplacement(
        summary: WorkspaceArchiveImportSummary,
        archiveData: Data,
        workspaceStore: WorkspaceStore
    ) throws {
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

        _ = try workspaceStore.importWorkspaceArchive(archiveData)

        let successAlert = NSAlert()
        successAlert.alertStyle = .informational
        successAlert.messageText = "Workspace Replaced"
        successAlert.informativeText = "The selected archive replaced the current workspace."
        successAlert.addButton(withTitle: "OK")
        successAlert.runModal()
    }

    private func showImportError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Archive Import Failed"
        alert.informativeText = message(for: error)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func formattedSummary(_ summary: WorkspaceArchiveImportSummary) -> String {
        [
            "Clients: \(summary.clientCount)",
            "Projects: \(summary.projectCount)",
            "Buckets: \(summary.bucketCount)",
            "Time Entries: \(summary.timeEntryCount)",
            "Fixed Costs: \(summary.fixedCostCount)",
            "Invoices: \(summary.invoiceCount)",
        ].joined(separator: " · ")
    }

    private func message(for error: Error) -> String {
        switch error {
        case WorkspaceArchiveError.invalidFormatMarker(_, let found):
            return "Unsupported archive format: \(found)."
        case WorkspaceArchiveError.unsupportedVersion(_, let found):
            return "Unsupported archive version: \(found)."
        case WorkspaceArchiveError.invalidExportedAt(let value):
            return "Invalid export timestamp: \(value)."
        case WorkspaceArchiveError.invalidDate(let field, let value):
            return "Invalid date value in \(field): \(value)."
        case WorkspaceArchiveError.unknownField(let field):
            return "Unsupported archive field: \(field)."
        case WorkspaceArchiveError.decodingFailed(let message):
            return "Archive decoding failed: \(message)"
        case WorkspaceArchiveImportError.duplicateEntityID(let entity, let id):
            return "Duplicate \(entity) identity found: \(id.uuidString)."
        case WorkspaceArchiveImportError.missingRelationship(let entity, let id, let relationship, let targetID):
            return "\(entity) \(id.uuidString) references missing \(relationship): \(targetID.uuidString)."
        case WorkspaceArchiveImportError.inconsistentRelationship(let entity, let id, let relationship, let targetID):
            return "\(entity) \(id.uuidString) references mismatched \(relationship): \(targetID.uuidString)."
        case WorkspaceArchiveImportError.invalidCurrencyCode(let field, let value):
            return "Invalid currency value in \(field): \(value)."
        case WorkspaceArchiveImportError.invalidMoneyValue(let field, let value):
            return "Invalid numeric value in \(field): \(value)."
        case WorkspaceArchiveImportError.invalidTermsDays(let field, let value):
            return "Invalid terms value in \(field): \(value)."
        case WorkspaceArchiveImportError.invalidInvoiceTemplate(let value):
            return "Invalid invoice template: \(value)."
        case WorkspaceArchiveImportError.duplicateInvoiceNumber(let normalizedNumber):
            if normalizedNumber.isEmpty {
                return "Invoice numbers must not be empty."
            }
            return "Duplicate invoice number found after normalization: \(normalizedNumber)."
        case WorkspaceArchiveImportError.invoiceTotalMismatch(let invoiceID, let expected, let actual):
            return "Invoice \(invoiceID.uuidString) total mismatch. Expected \(expected), got \(actual)."
        case WorkspaceStoreError.persistenceFailed:
            return "Workspace replacement failed. The previous workspace was kept."
        case WorkspaceArchiveActionError.backupsDirectoryUnavailable:
            return "Import is blocked because the backups directory could not be located."
        case WorkspaceArchiveActionError.backupsDirectoryOpenFailed:
            return "The backups folder could not be opened."
        case let decodingError as DecodingError:
            return "Archive decoding failed: \(decodingError.localizedDescription)"
        default:
            return "Archive validation failed: \(error.localizedDescription)"
        }
    }
}

#endif
