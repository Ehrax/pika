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
        if isUsingNormalizedWorkspacePersistence() {
            try updateBucketStatusInNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                to: status,
                activityVerb: activityVerb,
                occurredAt: occurredAt
            )
            return
        }

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

    @discardableResult
    private func createBucketInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        _ draft: WorkspaceBucketDraft,
        occurredAt: Date
    ) throws -> WorkspaceBucket {
        let bucketName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bucketName.isEmpty, draft.hourlyRateMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidBucket
        }

        guard let projectRecord = try projectRecord(projectID) else {
            throw WorkspaceStoreError.projectNotFound
        }

        let now = Date.now
        let bucketRecord = BucketRecord(
            projectID: projectID,
            name: bucketName,
            statusRaw: BucketStatus.open.rawValue,
            createdAt: now,
            updatedAt: now,
            project: projectRecord
        )
        modelContext.insert(bucketRecord)

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        guard let project = workspace.projects.first(where: { $0.id == projectID }),
              let bucket = project.buckets.first(where: { $0.id == bucketRecord.id })
        else {
            throw WorkspaceStoreError.persistenceFailed
        }

        appendActivity(
            message: "\(bucket.name) bucket created",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketCreated(bucketName: bucket.name, projectName: project.name)
        try persistWorkspace()
        return bucket
    }

    @discardableResult
    private func updateBucketInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        _ draft: WorkspaceBucketDraft,
        occurredAt: Date
    ) throws -> WorkspaceBucket {
        let bucketName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bucketName.isEmpty, draft.hourlyRateMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidBucket
        }

        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }

        bucketRecord.name = bucketName
        bucketRecord.updatedAt = .now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        guard let project = workspace.projects.first(where: { $0.id == projectID }),
              let bucket = project.buckets.first(where: { $0.id == bucketID })
        else {
            throw WorkspaceStoreError.persistenceFailed
        }

        appendActivity(
            message: "\(bucket.name) bucket updated",
            detail: project.name,
            occurredAt: occurredAt
        )
        try persistWorkspace()
        return bucket
    }

    private func markBucketReadyInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date
    ) throws {
        let project = try project(projectID)
        let bucket = try bucket(bucketID, in: project)
        guard bucket.status == .open, bucket.effectiveTotalMinorUnits > 0 else {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }

        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }

        bucketRecord.status = .ready
        bucketRecord.updatedAt = .now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        appendActivity(
            message: "\(bucket.name) marked ready",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketMarkedReady(bucketName: bucket.name, projectName: project.name)
        try persistWorkspace()
    }

    private func updateBucketStatusInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        to status: BucketStatus,
        activityVerb: String,
        occurredAt: Date
    ) throws {
        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }

        let currentStatus = bucketRecord.status
        switch status {
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

        let projectName = workspace.projects.first(where: { $0.id == projectID })?.name ?? ""
        let bucketName = workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? bucketRecord.name

        bucketRecord.status = status
        bucketRecord.updatedAt = .now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        appendActivity(
            message: "\(bucketName) \(activityVerb)",
            detail: projectName,
            occurredAt: occurredAt
        )

        if status == .archived {
            AppTelemetry.bucketArchived(bucketName: bucketName, projectName: projectName)
        } else {
            AppTelemetry.bucketRestored(bucketName: bucketName, projectName: projectName)
        }

        try persistWorkspace()
    }

    private func removeBucketFromNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date
    ) throws {
        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }

        let status = bucketRecord.status
        guard status == .archived else {
            throw WorkspaceStoreError.bucketLocked(status)
        }

        let projectName = workspace.projects.first(where: { $0.id == projectID })?.name ?? ""
        let bucketName = workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? bucketRecord.name

        try deleteNormalizedBucketDependencies(bucketID)
        modelContext.delete(bucketRecord)

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        appendActivity(
            message: "\(bucketName) removed",
            detail: projectName,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketRemoved(bucketName: bucketName, projectName: projectName)
        try persistWorkspace()
    }

    private func deleteNormalizedBucketDependencies(_ bucketID: WorkspaceBucket.ID) throws {
        for timeEntry in try timeEntryRecords(for: bucketID) {
            modelContext.delete(timeEntry)
        }

        for fixedCost in try fixedCostRecords(for: bucketID) {
            modelContext.delete(fixedCost)
        }
    }
}
