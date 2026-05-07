import SwiftUI

struct ProjectWorkbenchToolbarContent: ToolbarContent {
    let hasSelectedProject: Bool
    let hasSelectedBucket: Bool
    let canMarkReady: Bool
    let selectedInvoiceRow: WorkspaceInvoiceRowProjection?
    let selectedBucketStatus: BucketStatus?
    let canArchiveOrRestore: Bool
    let canRemove: Bool
    let onEditBucket: () -> Void
    let onMarkReady: () -> Void
    let onMarkInvoiceSent: (WorkspaceInvoiceRowProjection) -> Void
    let onMarkInvoicePaid: (WorkspaceInvoiceRowProjection) -> Void
    let onCancelInvoice: (WorkspaceInvoiceRowProjection) -> Void
    let onArchiveOrRestore: () -> Void
    let onRemoveBucket: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup {
            bucketActionsMenu
            ControlGroup {
                editBucketButton
                markReadyButton
            }
        }
    }

    private var editBucketButton: some View {
        Button {
            onEditBucket()
        } label: {
            Label("Edit Bucket", systemImage: "pencil")
        }
        .disabled(!hasSelectedProject || !hasSelectedBucket)
        .help("Edit selected bucket")
        .tint(BillbiColor.textPrimary)
    }

    private var markReadyButton: some View {
        Button {
            onMarkReady()
        } label: {
            Label("Mark Ready", systemImage: "checkmark.circle")
        }
        .disabled(!canMarkReady)
        .help("Mark the selected bucket ready for invoicing")
        .tint(BillbiColor.success)
    }

    private var bucketActionsMenu: some View {
        Menu {
            if let invoiceRow = selectedInvoiceRow {
                Button {
                    onMarkInvoiceSent(invoiceRow)
                } label: {
                    Label("Mark Sent", systemImage: "paperplane")
                }
                .disabled(!InvoiceWorkflowPolicy.canMarkSent(status: invoiceRow.status))
                .tint(BillbiColor.brand)

                Button {
                    onMarkInvoicePaid(invoiceRow)
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.seal")
                }
                .disabled(!InvoiceWorkflowPolicy.canMarkPaid(status: invoiceRow.status))
                .tint(BillbiColor.success)

                Button(role: .destructive) {
                    onCancelInvoice(invoiceRow)
                } label: {
                    Label("Cancel Invoice", systemImage: "xmark.circle")
                }
                .disabled(!InvoiceWorkflowPolicy.canCancel(status: invoiceRow.status))

                Divider()
            }

            Button {
                onArchiveOrRestore()
            } label: {
                Label(
                    selectedBucketStatus == .archived ? "Restore Bucket" : "Archive Bucket",
                    systemImage: selectedBucketStatus == .archived ? "arrow.uturn.backward" : "archivebox"
                )
            }
            .disabled(!canArchiveOrRestore)
            .tint(selectedBucketStatus == .archived ? BillbiColor.success : BillbiColor.warning)

            if selectedBucketStatus == .archived {
                Divider()

                Button(role: .destructive) {
                    onRemoveBucket()
                } label: {
                    Label("Remove Bucket", systemImage: "trash")
                }
                .disabled(!canRemove)
            }
        } label: {
            Label("Bucket Actions", systemImage: "ellipsis.circle")
        }
        .help("Bucket actions")
        .tint(BillbiColor.textPrimary)
    }
}
