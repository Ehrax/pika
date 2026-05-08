import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

enum WorkspaceArchiveFileMenuCommandSurface {
    static let exportWorkspaceArchiveTitle = "Export Workspace Archive…"
    static let importWorkspaceArchiveTitle = "Import Workspace Archive…"
    static let revealWorkspaceBackupsTitle = "Reveal Workspace Backups"
    static let localizedExportWorkspaceArchiveTitle = String(localized: "Export Workspace Archive…")
    static let localizedImportWorkspaceArchiveTitle = String(localized: "Import Workspace Archive…")
    static let localizedRevealWorkspaceBackupsTitle = String(localized: "Reveal Workspace Backups")
    static let resetOnboardingTitle = "Reset Onboarding Completion"
    static let localizedResetOnboardingTitle = String(localized: "Reset Onboarding Completion")
    static let commandTitles = [
        exportWorkspaceArchiveTitle,
        importWorkspaceArchiveTitle,
        revealWorkspaceBackupsTitle,
    ]

#if os(macOS)
    static var commandGroupTypeNames: [String] {
        var typeNames = [
            String(describing: WorkspaceArchiveCommands.self),
        ]
#if DEBUG
        typeNames.append(String(describing: WorkspaceOnboardingDebugCommands.self))
#endif
        return typeNames
    }

    @CommandsBuilder
    static var commands: some Commands {
        WorkspaceArchiveCommands()
#if DEBUG
        WorkspaceOnboardingDebugCommands()
#endif
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
                    WorkspaceArchiveFileMenuCommandSurface.localizedImportWorkspaceArchiveTitle,
                    systemImage: "square.and.arrow.down"
                )
            }
            .keyboardShortcut("I", modifiers: [.command, .shift])
            .disabled(workspaceStore == nil)

            Button {
                exportWorkspaceArchive()
            } label: {
                Label(
                    WorkspaceArchiveFileMenuCommandSurface.localizedExportWorkspaceArchiveTitle,
                    systemImage: "square.and.arrow.up"
                )
            }
            .keyboardShortcut("E", modifiers: [.command, .shift])
            .disabled(workspaceStore == nil)

            Button {
                revealWorkspaceBackups()
            } label: {
                Label(
                    WorkspaceArchiveFileMenuCommandSurface.localizedRevealWorkspaceBackupsTitle,
                    systemImage: "folder"
                )
            }
        }
    }

    private func importWorkspaceArchive() {
        guard let workspaceStore else { return }

        let panel = NSOpenPanel()
        panel.title = String(localized: "Import Workspace Archive")
        panel.message = String(localized: "Choose a .billbiarchive file to validate before replacing your workspace.")
        panel.prompt = String(localized: "Validate")
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
        alert.messageText = String(localized: "Replace Current Workspace?")
        alert.informativeText = String(
            localized: "\(formattedSummary(summary))\n\nContinuing will replace the current workspace and cannot be undone."
        )
        alert.addButton(withTitle: String(localized: "Replace Workspace"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        _ = try workspaceStore.importWorkspaceArchive(archiveData)

        let successAlert = NSAlert()
        successAlert.alertStyle = .informational
        successAlert.messageText = String(localized: "Workspace Replaced")
        successAlert.informativeText = String(localized: "The selected archive replaced the current workspace.")
        successAlert.addButton(withTitle: String(localized: "OK"))
        successAlert.runModal()
    }

    private func showImportError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(localized: "Archive Import Failed")
        alert.informativeText = message(for: error)
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private func formattedSummary(_ summary: WorkspaceArchiveImportSummary) -> String {
        [
            String(localized: "Clients: \(summary.clientCount)"),
            String(localized: "Projects: \(summary.projectCount)"),
            String(localized: "Buckets: \(summary.bucketCount)"),
            String(localized: "Time Entries: \(summary.timeEntryCount)"),
            String(localized: "Fixed Charges: \(summary.fixedCostCount)"),
            String(localized: "Invoices: \(summary.invoiceCount)"),
        ].joined(separator: " · ")
    }

    private func message(for error: Error) -> String {
        switch error {
        case WorkspaceArchiveError.invalidFormatMarker(_, let found):
            return String(localized: "Unsupported archive format: \(found).")
        case WorkspaceArchiveError.unsupportedVersion(_, let found):
            return String(localized: "Unsupported archive version: \(found).")
        case WorkspaceArchiveError.invalidExportedAt(let value):
            return String(localized: "Invalid export timestamp: \(value).")
        case WorkspaceArchiveError.invalidDate(let field, let value):
            return String(localized: "Invalid date value in \(field): \(value).")
        case WorkspaceArchiveError.unknownField(let field):
            return String(localized: "Unsupported archive field: \(field).")
        case WorkspaceArchiveError.decodingFailed(let message):
            return String(localized: "Archive decoding failed: \(message)")
        case WorkspaceArchiveImportError.duplicateEntityID(let entity, let id):
            return String(localized: "Duplicate \(entity) identity found: \(id.uuidString).")
        case WorkspaceArchiveImportError.missingRelationship(let entity, let id, let relationship, let targetID):
            return String(localized: "\(entity) \(id.uuidString) references missing \(relationship): \(targetID.uuidString).")
        case WorkspaceArchiveImportError.inconsistentRelationship(let entity, let id, let relationship, let targetID):
            return String(localized: "\(entity) \(id.uuidString) references mismatched \(relationship): \(targetID.uuidString).")
        case WorkspaceArchiveImportError.invalidCurrencyCode(let field, let value):
            return String(localized: "Invalid currency value in \(field): \(value).")
        case WorkspaceArchiveImportError.invalidMoneyValue(let field, let value):
            return String(localized: "Invalid numeric value in \(field): \(value).")
        case WorkspaceArchiveImportError.invalidTermsDays(let field, let value):
            return String(localized: "Invalid terms value in \(field): \(value).")
        case WorkspaceArchiveImportError.invalidInvoiceTemplate(let value):
            return String(localized: "Invalid invoice template: \(value).")
        case WorkspaceArchiveImportError.duplicateInvoiceNumber(let normalizedNumber):
            if normalizedNumber.isEmpty {
                return String(localized: "Invoice numbers must not be empty.")
            }
            return String(localized: "Duplicate invoice number found after normalization: \(normalizedNumber).")
        case WorkspaceArchiveImportError.invoiceTotalMismatch(let invoiceID, let expected, let actual):
            return String(localized: "Invoice \(invoiceID.uuidString) total mismatch. Expected \(expected), got \(actual).")
        case WorkspaceStoreError.persistenceFailed:
            return String(localized: "Workspace replacement failed. The previous workspace was kept.")
        case WorkspaceArchiveActionError.backupsDirectoryUnavailable:
            return String(localized: "Import is blocked because the backups directory could not be located.")
        case WorkspaceArchiveActionError.backupsDirectoryOpenFailed:
            return String(localized: "The backups folder could not be opened.")
        case let decodingError as DecodingError:
            return String(localized: "Archive decoding failed: \(decodingError.localizedDescription)")
        default:
            return String(localized: "Archive validation failed: \(error.localizedDescription)")
        }
    }
}

#endif

#if os(macOS) && DEBUG
struct WorkspaceOnboardingDebugCommands: Commands {
    @FocusedValue(\.workspaceStore) private var workspaceStore

    var body: some Commands {
        CommandMenu("Debug") {
            Button {
                resetOnboarding()
            } label: {
                Label(
                    WorkspaceArchiveFileMenuCommandSurface.localizedResetOnboardingTitle,
                    systemImage: "arrow.counterclockwise"
                )
            }
            .keyboardShortcut("O", modifiers: [.command, .shift, .option])
            .disabled(workspaceStore == nil)
        }
    }

    private func resetOnboarding() {
        guard let workspaceStore else { return }
        try? workspaceStore.resetOnboardingCompletionForDebug()
    }
}
#endif
