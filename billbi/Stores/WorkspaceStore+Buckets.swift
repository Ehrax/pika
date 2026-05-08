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
        guard Self.isValidBucketDraft(draft, name: bucketName, mode: draft.billingMode) else {
            throw WorkspaceStoreError.invalidBucket
        }

        let bucket = WorkspaceBucket(
            id: UUID(),
            name: bucketName,
            status: .open,
            billingMode: draft.billingMode,
            totalMinorUnits: 0,
            billableMinutes: 0,
            fixedCostMinorUnits: 0,
            defaultHourlyRateMinorUnits: draft.billingMode == .hourly ? draft.hourlyRateMinorUnits : nil,
            fixedAmountMinorUnits: draft.billingMode == .fixed ? draft.fixedAmountMinorUnits : nil,
            retainerAmountMinorUnits: draft.billingMode == .retainer ? draft.retainerAmountMinorUnits : nil,
            retainerPeriodLabel: draft.billingMode == .retainer ? draft.retainerPeriodLabel.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            retainerIncludedMinutes: draft.billingMode == .retainer ? draft.retainerIncludedMinutes : nil,
            retainerOverageRateMinorUnits: draft.billingMode == .retainer ? draft.retainerOverageRateMinorUnits : nil
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
        let currentMode = workspace.projects[projectIndex].buckets[bucketIndex].billingMode
        let bucketName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidBucketDraft(draft, name: bucketName, mode: currentMode) else {
            throw WorkspaceStoreError.invalidBucket
        }

        workspace.projects[projectIndex].buckets[bucketIndex].name = bucketName
        switch currentMode {
        case .hourly:
            workspace.projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = draft.hourlyRateMinorUnits
            workspace.projects[projectIndex].buckets[bucketIndex].fixedAmountMinorUnits = nil
            workspace.projects[projectIndex].buckets[bucketIndex].retainerAmountMinorUnits = nil
            workspace.projects[projectIndex].buckets[bucketIndex].retainerPeriodLabel = ""
            workspace.projects[projectIndex].buckets[bucketIndex].retainerIncludedMinutes = nil
            workspace.projects[projectIndex].buckets[bucketIndex].retainerOverageRateMinorUnits = nil
        case .fixed:
            workspace.projects[projectIndex].buckets[bucketIndex].fixedAmountMinorUnits = draft.fixedAmountMinorUnits
            workspace.projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = nil
            workspace.projects[projectIndex].buckets[bucketIndex].retainerAmountMinorUnits = nil
            workspace.projects[projectIndex].buckets[bucketIndex].retainerPeriodLabel = ""
            workspace.projects[projectIndex].buckets[bucketIndex].retainerIncludedMinutes = nil
            workspace.projects[projectIndex].buckets[bucketIndex].retainerOverageRateMinorUnits = nil
        case .retainer:
            workspace.projects[projectIndex].buckets[bucketIndex].retainerAmountMinorUnits = draft.retainerAmountMinorUnits
            workspace.projects[projectIndex].buckets[bucketIndex].retainerPeriodLabel = draft.retainerPeriodLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            workspace.projects[projectIndex].buckets[bucketIndex].retainerIncludedMinutes = draft.retainerIncludedMinutes
            workspace.projects[projectIndex].buckets[bucketIndex].retainerOverageRateMinorUnits = draft.retainerOverageRateMinorUnits
            workspace.projects[projectIndex].buckets[bucketIndex].defaultHourlyRateMinorUnits = nil
            workspace.projects[projectIndex].buckets[bucketIndex].fixedAmountMinorUnits = nil
        }
        let bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        appendActivity(
            message: "\(bucket.name) bucket updated",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        try persistWorkspace()
        return bucket
    }

    static func isValidBucketDraft(
        _ draft: WorkspaceBucketDraft,
        name bucketName: String,
        mode: WorkspaceBucketBillingMode
    ) -> Bool {
        guard !bucketName.isEmpty else { return false }

        switch mode {
        case .hourly:
            return draft.hourlyRateMinorUnits > 0
        case .fixed:
            return (draft.fixedAmountMinorUnits ?? 0) > 0
        case .retainer:
            guard (draft.retainerAmountMinorUnits ?? 0) > 0 else { return false }
            if let included = draft.retainerIncludedMinutes, included < 0 {
                return false
            }
            if let overageRate = draft.retainerOverageRateMinorUnits, overageRate < 0 {
                return false
            }
            return true
        }
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
