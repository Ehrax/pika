import CoreGraphics
import OSLog

enum AppTelemetry {
    private static let subsystem = "dev.ehrax.pika"

    private static let shellLogger = Logger(subsystem: subsystem, category: "shell")
    private static let dashboardLogger = Logger(subsystem: subsystem, category: "dashboard")
    private static let projectLogger = Logger(subsystem: subsystem, category: "projects")
    private static let invoiceLogger = Logger(subsystem: subsystem, category: "invoices")
    private static let clientLogger = Logger(subsystem: subsystem, category: "clients")
    private static let settingsLogger = Logger(subsystem: subsystem, category: "settings")
    private static let layoutLogger = Logger(subsystem: subsystem, category: "layout")
    private static let persistenceLogger = Logger(subsystem: subsystem, category: "persistence")

    static func shellSelectionChanged(_ selection: String) {
        shellLogger.info("shell.selection_changed destination=\(selection, privacy: .public)")
    }

    static func mainWindowFrameObserved(frame: CGRect, event: String) {
        layoutLogger.info(
            """
            layout.window_frame event=\(event, privacy: .public) x=\(frame.origin.x, privacy: .public) y=\(frame.origin.y, privacy: .public) width=\(frame.width, privacy: .public) height=\(frame.height, privacy: .public)
            """
        )
    }

    static func primarySidebarWidthObserved(width: Double) {
        layoutLogger.info("layout.primary_sidebar width=\(width, privacy: .public)")
    }

    static func secondarySidebarWidthObserved(width: Double, event: String) {
        layoutLogger.info("layout.secondary_sidebar event=\(event, privacy: .public) width=\(width, privacy: .public)")
    }

    static func dashboardLoaded(_ summary: DashboardSummary) {
        dashboardLogger.info(
            """
            dashboard.loaded active_projects=\(summary.activeProjectCount, privacy: .public) clients=\(summary.clientCount, privacy: .public) attention_items=\(summary.needsAttention.count, privacy: .public) ready_minor_units=\(summary.readyToInvoiceMinorUnits, privacy: .private) overdue_minor_units=\(summary.overdueMinorUnits, privacy: .private)
            """
        )
    }

    static func dashboardAttentionSelected(itemID: String) {
        dashboardLogger.info("dashboard.attention_selected item=\(itemID, privacy: .public)")
    }

    static func dashboardRevenueRangeSelected(range: String, visiblePointCount: Int) {
        dashboardLogger.info("dashboard.revenue_range_selected range=\(range, privacy: .public) points=\(visiblePointCount, privacy: .public)")
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

    static func projectUpdated(projectName: String, clientName: String) {
        projectLogger.info("project.updated project=\(projectName, privacy: .private) client=\(clientName, privacy: .private)")
    }

    static func projectArchived(projectName: String) {
        projectLogger.info("project.archived project=\(projectName, privacy: .private)")
    }

    static func projectRestored(projectName: String) {
        projectLogger.info("project.restored project=\(projectName, privacy: .private)")
    }

    static func projectRemoved(projectName: String) {
        projectLogger.info("project.removed project=\(projectName, privacy: .private)")
    }

    static func bucketCreated(bucketName: String, projectName: String) {
        projectLogger.info("bucket.created bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketMarkedReady(bucketName: String, projectName: String) {
        projectLogger.info("bucket.marked_ready bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketArchived(bucketName: String, projectName: String) {
        projectLogger.info("bucket.archived bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketRestored(bucketName: String, projectName: String) {
        projectLogger.info("bucket.restored bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketRemoved(bucketName: String, projectName: String) {
        projectLogger.info("bucket.removed bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketTimeEntryAdded(bucketName: String, projectName: String) {
        projectLogger.info("bucket.time_entry_added bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketFixedCostAdded(bucketName: String, projectName: String) {
        projectLogger.info("bucket.fixed_cost_added bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
    }

    static func bucketEntryDeleted(bucketName: String, projectName: String) {
        projectLogger.info("bucket.entry_deleted bucket=\(bucketName, privacy: .private) project=\(projectName, privacy: .private)")
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

    static func clientUpdated(clientName: String) {
        clientLogger.info("client.updated client=\(clientName, privacy: .private)")
    }

    static func clientArchived(clientName: String) {
        clientLogger.info("client.archived client=\(clientName, privacy: .private)")
    }

    static func clientRestored(clientName: String) {
        clientLogger.info("client.restored client=\(clientName, privacy: .private)")
    }

    static func clientRemoved(clientName: String) {
        clientLogger.info("client.removed client=\(clientName, privacy: .private)")
    }

    static func settingsSaved() {
        settingsLogger.info("settings.saved")
    }

    static func persistenceContainerRecoveryAttempted(storePath: String, reason: String) {
        persistenceLogger.warning(
            "persistence.recovery_attempted store=\(storePath, privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    static func persistenceContainerRecovered(storePath: String) {
        persistenceLogger.info("persistence.recovered store=\(storePath, privacy: .public)")
    }

    static func persistenceContainerRecoveryFailed(storePath: String, message: String) {
        persistenceLogger.error(
            "persistence.recovery_failed store=\(storePath, privacy: .public) error=\(message, privacy: .private)"
        )
    }
}
