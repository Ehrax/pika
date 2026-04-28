import Foundation

extension WorkspaceStore {
    func archiveBucket(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date = .now
    ) throws {
        try updateBucketStatus(
            projectID: projectID,
            bucketID: bucketID,
            to: .archived,
            activityVerb: "archived",
            occurredAt: occurredAt
        )
    }

    func restoreBucket(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date = .now
    ) throws {
        try updateBucketStatus(
            projectID: projectID,
            bucketID: bucketID,
            to: .open,
            activityVerb: "restored",
            occurredAt: occurredAt
        )
    }

    func removeBucket(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date = .now
    ) throws {
        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard bucket.status == .archived else {
            throw WorkspaceStoreError.bucketLocked(bucket.status)
        }

        workspace.projects[projectIndex].buckets.remove(at: bucketIndex)
        appendActivity(
            message: "\(bucket.name) removed",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketRemoved(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }

    @discardableResult
    func createBucket(
        projectID: WorkspaceProject.ID,
        _ draft: WorkspaceBucketDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceBucket {
        let projectIndex = try projectIndex(projectID)
        let bucketName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bucketName.isEmpty, draft.hourlyRateMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidBucket
        }

        let bucket = WorkspaceBucket(
            id: UUID(),
            name: bucketName,
            status: .open,
            totalMinorUnits: 0,
            billableMinutes: 0,
            fixedCostMinorUnits: 0,
            defaultHourlyRateMinorUnits: draft.hourlyRateMinorUnits
        )

        workspace.projects[projectIndex].buckets.append(bucket)
        appendActivity(
            message: "\(bucket.name) bucket created",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketCreated(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
        return bucket
    }

    @discardableResult
    func updateBucket(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        _ draft: WorkspaceBucketDraft,
        occurredAt: Date = .now
    ) throws -> WorkspaceBucket {
        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let bucketName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bucketName.isEmpty, draft.hourlyRateMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidBucket
        }

        workspace.projects[projectIndex].buckets[bucketIndex].name = bucketName
        workspace.projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = draft.hourlyRateMinorUnits
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        appendActivity(
            message: "\(bucket.name) bucket updated",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        try persistWorkspace()
        return bucket
    }

    func markBucketReady(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date = .now
    ) throws {
        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard bucket.status == .open, bucket.effectiveTotalMinorUnits > 0 else {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }

        workspace.projects[projectIndex].buckets[bucketIndex].status = .ready
        appendActivity(
            message: "\(bucket.name) marked ready",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketMarkedReady(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }

    private func updateBucketStatus(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        to status: BucketStatus,
        activityVerb: String,
        occurredAt: Date
    ) throws {
        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        switch status {
        case .archived:
            guard !bucket.status.isInvoiceLocked else {
                throw WorkspaceStoreError.bucketLocked(bucket.status)
            }
        case .open:
            guard bucket.status == .archived else {
                throw WorkspaceStoreError.bucketLocked(bucket.status)
            }
        case .ready, .finalized:
            throw WorkspaceStoreError.bucketStatusNotReady(bucket.status)
        }

        workspace.projects[projectIndex].buckets[bucketIndex].status = status
        appendActivity(
            message: "\(bucket.name) \(activityVerb)",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )

        if status == .archived {
            AppTelemetry.bucketArchived(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        } else {
            AppTelemetry.bucketRestored(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        }

        try persistWorkspace()
    }
}
