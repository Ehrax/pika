import SwiftUI

extension View {
    func projectWorkbenchPresentation(
        invoiceDraft: Binding<InvoiceDraftPresentation?>,
        actionFailure: Binding<WorkflowActionFailure?>,
        showsArchiveBucketConfirmation: Binding<Bool>,
        showsRemoveBucketConfirmation: Binding<Bool>,
        bucketPendingRemovalID: Binding<WorkspaceBucket.ID?>,
        showsEditBucket: Binding<Bool>,
        showsCreateBucket: Binding<Bool>,
        showsFixedCostSheet: Binding<Bool>,
        selectedBucket: WorkspaceBucket?,
        project: WorkspaceProject?,
        currentDate: Date,
        archiveSelectedBucket: @escaping () -> Void,
        removePendingBucket: @escaping () -> Void,
        updateSelectedBucket: @escaping (WorkspaceBucketDraft) -> Void,
        createBucket: @escaping (WorkspaceBucketDraft) -> Void,
        addFixedCost: @escaping (WorkspaceFixedCostDraft) -> Void,
        finalizeInvoice: @escaping (InvoiceDraftPresentation, InvoiceFinalizationDraft) -> Bool
    ) -> some View {
        modifier(
            ProjectWorkbenchPresentationModifier(
                invoiceDraft: invoiceDraft,
                actionFailure: actionFailure,
                showsArchiveBucketConfirmation: showsArchiveBucketConfirmation,
                showsRemoveBucketConfirmation: showsRemoveBucketConfirmation,
                bucketPendingRemovalID: bucketPendingRemovalID,
                showsEditBucket: showsEditBucket,
                showsCreateBucket: showsCreateBucket,
                showsFixedCostSheet: showsFixedCostSheet,
                selectedBucket: selectedBucket,
                project: project,
                currentDate: currentDate,
                archiveSelectedBucket: archiveSelectedBucket,
                removePendingBucket: removePendingBucket,
                updateSelectedBucket: updateSelectedBucket,
                createBucket: createBucket,
                addFixedCost: addFixedCost,
                finalizeInvoice: finalizeInvoice
            )
        )
    }
}

private struct ProjectWorkbenchPresentationModifier: ViewModifier {
    @Binding var invoiceDraft: InvoiceDraftPresentation?
    @Binding var actionFailure: WorkflowActionFailure?
    @Binding var showsArchiveBucketConfirmation: Bool
    @Binding var showsRemoveBucketConfirmation: Bool
    @Binding var bucketPendingRemovalID: WorkspaceBucket.ID?
    @Binding var showsEditBucket: Bool
    @Binding var showsCreateBucket: Bool
    @Binding var showsFixedCostSheet: Bool
    let selectedBucket: WorkspaceBucket?
    let project: WorkspaceProject?
    let currentDate: Date
    let archiveSelectedBucket: () -> Void
    let removePendingBucket: () -> Void
    let updateSelectedBucket: (WorkspaceBucketDraft) -> Void
    let createBucket: (WorkspaceBucketDraft) -> Void
    let addFixedCost: (WorkspaceFixedCostDraft) -> Void
    let finalizeInvoice: (InvoiceDraftPresentation, InvoiceFinalizationDraft) -> Bool

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Archive this bucket?",
                isPresented: $showsArchiveBucketConfirmation,
                titleVisibility: .visible
            ) {
                Button("Archive Bucket", role: .destructive) {
                    archiveSelectedBucket()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Archived buckets stay in the project history, but are locked for new entries.")
            }
            .confirmationDialog(
                "Remove this bucket?",
                isPresented: $showsRemoveBucketConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove Bucket", role: .destructive) {
                    removePendingBucket()
                }

                Button("Cancel", role: .cancel) {
                    bucketPendingRemovalID = nil
                }
            } message: {
                Text("Removed buckets are deleted from this project. This action cannot be undone.")
            }
            .sheet(item: $invoiceDraft) { presentation in
                CreateInvoiceConfirmationSheet(
                    presentation: presentation,
                    onCancel: { invoiceDraft = nil },
                    onSave: { draft in
                        finalizeInvoice(presentation, draft)
                    }
                )
            }
            .sheet(isPresented: $showsEditBucket) {
                if let selectedBucket, let project {
                    CreateBucketSheet(
                        defaultRateMinorUnits: selectedBucket.hourlyRateMinorUnits ?? 8_000,
                        currencyCode: project.currencyCode,
                        initialName: selectedBucket.name,
                        initialBillingMode: selectedBucket.billingMode,
                        initialFixedAmountMinorUnits: selectedBucket.fixedAmountMinorUnits,
                        initialRetainerAmountMinorUnits: selectedBucket.retainerAmountMinorUnits,
                        initialRetainerPeriodLabel: selectedBucket.retainerPeriodLabel,
                        initialRetainerIncludedMinutes: selectedBucket.retainerIncludedMinutes,
                        initialRetainerOverageRateMinorUnits: selectedBucket.retainerOverageRateMinorUnits,
                        isBillingModeEditable: false,
                        saveLabel: "Save Bucket",
                        saveSystemImage: "checkmark.circle",
                        onCancel: { showsEditBucket = false },
                        onSave: updateSelectedBucket
                    )
                }
            }
            .sheet(isPresented: $showsCreateBucket) {
                CreateBucketSheet(
                    defaultRateMinorUnits: selectedBucket?.hourlyRateMinorUnits ?? 8_000,
                    currencyCode: project?.currencyCode ?? "EUR",
                    onCancel: { showsCreateBucket = false },
                    onSave: createBucket
                )
            }
            .sheet(isPresented: $showsFixedCostSheet) {
                CreateFixedCostSheet(
                    date: currentDate,
                    currencyCode: project?.currencyCode ?? "EUR",
                    onCancel: { showsFixedCostSheet = false },
                    onSave: addFixedCost
                )
            }
            .alert(item: $actionFailure) { failure in
                Alert(
                    title: Text("Workflow Action Failed"),
                    message: Text(failure.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

struct WorkflowActionFailure: Identifiable {
    let id = UUID()
    let message: String
}

struct InvoiceDraftPresentation: Identifiable {
    let id = UUID()
    let projectID: WorkspaceProject.ID
    let bucketID: WorkspaceBucket.ID
    let draft: InvoiceFinalizationDraft
    let totalLabel: String
    let lineItems: [WorkspaceBucketLineItemProjection]
}
