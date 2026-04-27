import OSLog

enum AppTelemetry {
    private static let subsystem = "dev.ehrax.pika"

    private static let shellLogger = Logger(subsystem: subsystem, category: "shell")
    private static let dashboardLogger = Logger(subsystem: subsystem, category: "dashboard")
    private static let projectLogger = Logger(subsystem: subsystem, category: "projects")
    private static let invoiceLogger = Logger(subsystem: subsystem, category: "invoices")
    private static let clientLogger = Logger(subsystem: subsystem, category: "clients")
    private static let settingsLogger = Logger(subsystem: subsystem, category: "settings")

    static func shellSelectionChanged(_ selection: String) {
        shellLogger.info("shell.selection_changed destination=\(selection, privacy: .public)")
    }

    static func dashboardLoaded(_ summary: DashboardSummary) {
        dashboardLogger.info(
            """
            dashboard.loaded active_projects=\(summary.activeProjectCount, privacy: .public) clients=\(summary.clientCount, privacy: .public) attention_items=\(summary.needsAttention.count, privacy: .public) ready_minor_units=\(summary.readyToInvoiceMinorUnits, privacy: .private) overdue_minor_units=\(summary.overdueMinorUnits, privacy: .private)
            """
        )
    }

    static func projectDetailLoaded(projectName: String, bucketCount: Int) {
        projectLogger.info(
            "project.detail_loaded project=\(projectName, privacy: .private) buckets=\(bucketCount, privacy: .public)"
        )
    }

    static func projectBucketSelected(projectName: String) {
        projectLogger.info("project.bucket_selected project=\(projectName, privacy: .private)")
    }

    static func projectCreated(projectName: String, clientName: String) {
        projectLogger.info("project.created project=\(projectName, privacy: .private) client=\(clientName, privacy: .private)")
    }

    static func bucketCreated(bucketName: String, projectName: String) {
        projectLogger.info("bucket.created bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketMarkedReady(bucketName: String, projectName: String) {
        projectLogger.info("bucket.marked_ready bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketTimeEntryAdded(bucketName: String, projectName: String) {
        projectLogger.info("bucket.time_entry_added bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketFixedCostAdded(bucketName: String, projectName: String) {
        projectLogger.info("bucket.fixed_cost_added bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketFinalized(bucketName: String, projectName: String) {
        projectLogger.info("bucket.finalized bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func invoicesLoaded(invoiceCount: Int) {
        invoiceLogger.info("invoices.loaded count=\(invoiceCount, privacy: .public)")
    }

    static func invoiceCreated(invoiceNumber: String, clientName: String) {
        invoiceLogger.info("invoice.created number=\(invoiceNumber, privacy: .public) client=\(clientName, privacy: .private)")
    }

    static func invoiceFinalized(invoiceNumber: String, clientName: String) {
        invoiceLogger.info("invoice.finalized number=\(invoiceNumber, privacy: .public) client=\(clientName, privacy: .private)")
    }

    static func invoiceMarkedSent(invoiceNumber: String) {
        invoiceLogger.info("invoice.marked_sent number=\(invoiceNumber, privacy: .public)")
    }

    static func invoiceMarkedPaid(invoiceNumber: String) {
        invoiceLogger.info("invoice.marked_paid number=\(invoiceNumber, privacy: .public)")
    }

    static func invoiceCancelled(invoiceNumber: String) {
        invoiceLogger.info("invoice.cancelled number=\(invoiceNumber, privacy: .public)")
    }

    static func invoicePDFOpened(invoiceNumber: String) {
        invoiceLogger.info("invoice.pdf_opened number=\(invoiceNumber, privacy: .public)")
    }

    static func invoicePDFExported(invoiceNumber: String) {
        invoiceLogger.info("invoice.pdf_exported number=\(invoiceNumber, privacy: .public)")
    }

    static func invoicePDFActionFailed(action: String, message: String) {
        invoiceLogger.error("invoice.pdf_action_failed action=\(action, privacy: .public) error=\(message, privacy: .private)")
    }

    static func clientsLoaded(clientCount: Int) {
        clientLogger.info("clients.loaded count=\(clientCount, privacy: .public)")
    }

    static func clientCreated(clientName: String) {
        clientLogger.info("client.created client=\(clientName, privacy: .private)")
    }

    static func settingsSaved() {
        settingsLogger.info("settings.saved")
    }
}
