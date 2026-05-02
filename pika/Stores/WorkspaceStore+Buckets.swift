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
        if isUsingNormalizedWorkspacePersistence() {
            try removeBucketFromNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                occurredAt: occurredAt
            )
            return
        }

        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        try mutationPolicy.ensureBucketCanBeRemoved(status: bucket.status)

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
        if isUsingNormalizedWorkspacePersistence() {
            return try createBucketInNormalizedRecords(
                projectID: projectID,
                draft,
                occurredAt: occurredAt
            )
        }

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
        if isUsingNormalizedWorkspacePersistence() {
            return try updateBucketInNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                draft,
                occurredAt: occurredAt
            )
        }

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
        if isUsingNormalizedWorkspacePersistence() {
            try markBucketReadyInNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                occurredAt: occurredAt
            )
            return
        }

        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        try mutationPolicy.ensureBucketCanBeMarkedReady(bucket)

        workspace.projects[projectIndex].buckets[bucketIndex].status = .ready
        appendActivity(
            message: "\(bucket.name) marked ready",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketMarkedReady(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }
}
