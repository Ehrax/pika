import Foundation
import SwiftData

extension WorkspaceStore {
    func updateBucketStatus(
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

        try mutationPolicy.ensureBucketStatusTransition(from: bucket.status, to: status)

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
    func createBucketInNormalizedRecords(
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
            defaultHourlyRateMinorUnits: draft.hourlyRateMinorUnits,
            createdAt: now,
            updatedAt: now,
            project: projectRecord
        )
        normalizedRecordStore.insert(bucketRecord)

        let committed = try commitNormalizedWorkspaceMutation {
            guard let project = workspace.projects.first(where: { $0.id == projectID }),
                  let bucket = project.buckets.first(where: { $0.id == bucketRecord.id })
            else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return (project: project, bucket: bucket)
        } activity: { project, bucket in
            WorkspaceActivity(
                message: "\(bucket.name) bucket created",
                detail: project.name,
                occurredAt: occurredAt
            )
        } telemetry: { project, bucket in
            AppTelemetry.bucketCreated(bucketName: bucket.name, projectName: project.name)
        }
        return committed.1
    }

    @discardableResult
    func updateBucketInNormalizedRecords(
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
        bucketRecord.defaultHourlyRateMinorUnits = draft.hourlyRateMinorUnits
        bucketRecord.updatedAt = .now

        let committed = try commitNormalizedWorkspaceMutation {
            guard let project = workspace.projects.first(where: { $0.id == projectID }),
                  let bucket = project.buckets.first(where: { $0.id == bucketID })
            else {
                throw WorkspaceStoreError.persistenceFailed
            }
            return (project: project, bucket: bucket)
        } activity: { project, bucket in
            WorkspaceActivity(
                message: "\(bucket.name) bucket updated",
                detail: project.name,
                occurredAt: occurredAt
            )
        }
        return committed.1
    }

    func markBucketReadyInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        occurredAt: Date
    ) throws {
        let project = try project(projectID)
        let bucket = try bucket(bucketID, in: project)
        try mutationPolicy.ensureBucketCanBeMarkedReady(bucket)

        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }

        bucketRecord.status = .ready
        bucketRecord.updatedAt = .now

        try commitNormalizedWorkspaceMutation {
            (project, bucket)
        } activity: { project, bucket in
            WorkspaceActivity(
                message: "\(bucket.name) marked ready",
                detail: project.name,
                occurredAt: occurredAt
            )
        } telemetry: { project, bucket in
            AppTelemetry.bucketMarkedReady(bucketName: bucket.name, projectName: project.name)
        }
    }

    func updateBucketStatusInNormalizedRecords(
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
        try mutationPolicy.ensureBucketStatusTransition(from: currentStatus, to: status)

        let projectName = workspace.projects.first(where: { $0.id == projectID })?.name ?? ""
        let bucketName = workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? bucketRecord.name

        bucketRecord.status = status
        bucketRecord.updatedAt = .now

        try commitNormalizedWorkspaceMutation {
            (projectName, bucketName)
        } activity: { projectName, bucketName in
            WorkspaceActivity(
                message: "\(bucketName) \(activityVerb)",
                detail: projectName,
                occurredAt: occurredAt
            )
        } telemetry: { projectName, bucketName in
            if status == .archived {
                AppTelemetry.bucketArchived(bucketName: bucketName, projectName: projectName)
            } else {
                AppTelemetry.bucketRestored(bucketName: bucketName, projectName: projectName)
            }
        }
    }

    func removeBucketFromNormalizedRecords(
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
        try mutationPolicy.ensureBucketCanBeRemoved(status: status)

        let projectName = workspace.projects.first(where: { $0.id == projectID })?.name ?? ""
        let bucketName = workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? bucketRecord.name

        try deleteNormalizedBucketDependencies(bucketID)
        normalizedRecordStore.delete(bucketRecord)

        try commitNormalizedWorkspaceMutation {
            (projectName, bucketName)
        } activity: { projectName, bucketName in
            WorkspaceActivity(
                message: "\(bucketName) removed",
                detail: projectName,
                occurredAt: occurredAt
            )
        } telemetry: { projectName, bucketName in
            AppTelemetry.bucketRemoved(bucketName: bucketName, projectName: projectName)
        }
    }

    private func deleteNormalizedBucketDependencies(_ bucketID: WorkspaceBucket.ID) throws {
        for timeEntry in try timeEntryRecords(for: bucketID) {
            normalizedRecordStore.delete(timeEntry)
        }

        for fixedCost in try fixedCostRecords(for: bucketID) {
            normalizedRecordStore.delete(fixedCost)
        }
    }
}
