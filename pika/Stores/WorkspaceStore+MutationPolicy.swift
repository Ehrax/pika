import Foundation

protocol WorkspaceMutationPolicy {
    func ensureBucketCanBeMarkedReady(_ bucket: WorkspaceBucket) throws
    func ensureBucketStatusTransition(from currentStatus: BucketStatus, to targetStatus: BucketStatus) throws
    func ensureBucketCanBeRemoved(status: BucketStatus) throws
    func ensureInvoiceStatusTransition(from sourceStatus: InvoiceStatus, to targetStatus: InvoiceStatus) throws
}

struct DefaultWorkspaceMutationPolicy: WorkspaceMutationPolicy {
    func ensureBucketCanBeMarkedReady(_ bucket: WorkspaceBucket) throws {
        guard bucket.status == .open, bucket.effectiveTotalMinorUnits > 0 else {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }
    }

    func ensureBucketStatusTransition(from currentStatus: BucketStatus, to targetStatus: BucketStatus) throws {
        switch targetStatus {
        case .archived:
            guard !currentStatus.isInvoiceLocked else {
                throw WorkspaceStoreError.bucketLocked(currentStatus)
            }
        case .open:
            guard currentStatus == .archived else {
                throw WorkspaceStoreError.bucketLocked(currentStatus)
            }
        case .ready, .finalized:
            throw WorkspaceStoreError.bucketStatusNotReady(currentStatus)
        }
    }

    func ensureBucketCanBeRemoved(status: BucketStatus) throws {
        guard status == .archived else {
            throw WorkspaceStoreError.bucketLocked(status)
        }
    }

    func ensureInvoiceStatusTransition(from sourceStatus: InvoiceStatus, to targetStatus: InvoiceStatus) throws {
        guard InvoiceWorkflowPolicy.canTransition(from: sourceStatus, to: targetStatus) else {
            throw WorkspaceStoreError.invalidInvoiceStatusTransition(from: sourceStatus, to: targetStatus)
        }
    }
}
