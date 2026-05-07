import SwiftUI

struct ProjectWorkbenchContent: View {
    let project: WorkspaceProject
    let currentDate: Date
    let initialSelectedBucketID: WorkspaceBucket.ID?
    @Binding var selectedBucketID: WorkspaceBucket.ID?
    let formatter: MoneyFormatting
    let canMarkSelectedBucketReady: Bool
    let invoiceRow: (WorkspaceBucketDetailProjection, WorkspaceProject) -> WorkspaceInvoiceRowProjection?
    let onCreateBucket: () -> Void
    let onShowFixedCostSheet: () -> Void
    let onAddTimeEntry: (WorkspaceProject.ID, WorkspaceBucket.ID, WorkspaceTimeEntryDraft) -> Void
    let onDeleteEntry: (WorkspaceProject.ID, WorkspaceBucket.ID, WorkspaceBucketEntryRowProjection) -> Void
    let onUpdateEntryDate: (WorkspaceProject.ID, WorkspaceBucket.ID, WorkspaceBucketEntryRowProjection, Date) -> Void
    let onMarkReady: () -> Void
    let onCreateInvoice: (WorkspaceProject.ID, WorkspaceBucket.ID, String, [WorkspaceBucketLineItemProjection]) -> Void
    let onArchiveBucket: (WorkspaceBucket.ID) -> Void
    let onRemoveBucket: (WorkspaceBucket.ID) -> Void

    var body: some View {
        let projection = project.detailProjection(
            selectedBucketID: selectedBucketID,
            formatter: formatter,
            on: currentDate
        )

        ResizableDetailSplitView {
            if let projection {
                bucketColumn(projection: projection)
            } else {
                ProjectWorkbenchEmptyBucketColumn(
                    project: project,
                    onCreateBucket: onCreateBucket
                )
            }
        } detail: {
            if let projection {
                bucketDetail(projection: projection)
            } else {
                BillbiColor.background
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BillbiColor.background)
        .onAppear {
            if let projection {
                selectedBucketID = project.normalizedBucketID(selectedBucketID) ?? projection.selectedBucket.id
                AppTelemetry.projectDetailLoaded(projectName: project.name, bucketCount: projection.bucketRows.count)
            }
        }
        .onChange(of: project.id) { _, _ in
            selectedBucketID = nil
        }
        .onChange(of: initialSelectedBucketID) { _, newValue in
            if let newValue {
                selectedBucketID = newValue
            }
        }
    }

    private func bucketColumn(projection: WorkspaceBucketDetailProjection) -> some View {
        let activeBucketID = project.normalizedBucketID(selectedBucketID) ?? projection.selectedBucket.id

        return ProjectBucketColumn(
            project: project,
            projection: projection,
            selectedBucketID: activeBucketID,
            onSelect: { bucketID in
                selectedBucketID = bucketID
                AppTelemetry.projectBucketSelected(projectName: project.name)
            },
            onCreateBucket: onCreateBucket,
            onArchiveBucket: { bucketID in
                selectedBucketID = bucketID
                onArchiveBucket(bucketID)
            },
            onRemoveBucket: { bucketID in
                selectedBucketID = bucketID
                onRemoveBucket(bucketID)
            }
        )
    }

    private func bucketDetail(projection: WorkspaceBucketDetailProjection) -> some View {
        BucketDetailWorkbench(
            projection: projection,
            draftDate: currentDate,
            invoiceRow: invoiceRow(projection, project),
            canMarkReady: canMarkSelectedBucketReady,
            onAddEntry: { draft in
                onAddTimeEntry(project.id, projection.selectedBucket.id, draft)
            },
            onAddFixedCost: onShowFixedCostSheet,
            onDeleteEntry: { row in
                onDeleteEntry(project.id, projection.selectedBucket.id, row)
            },
            onUpdateEntryDate: { row, date in
                onUpdateEntryDate(project.id, projection.selectedBucket.id, row, date)
            },
            onMarkReady: onMarkReady,
            onCreateInvoice: {
                onCreateInvoice(
                    project.id,
                    projection.selectedBucket.id,
                    projection.totalLabel,
                    projection.lineItems
                )
            }
        )
    }
}
