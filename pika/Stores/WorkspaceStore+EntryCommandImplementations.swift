import Foundation
import SwiftData

extension WorkspaceStore {
    func addTimeEntryToNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceTimeEntryDraft,
        occurredAt: Date
    ) throws {
        let project = try project(projectID)
        let bucket = try bucket(bucketID, in: project)

        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !description.isEmpty,
            let durationMinutes = WorkspaceEntryDurationParser.minutes(from: draft.timeInput)
        else {
            throw WorkspaceStoreError.invalidTimeEntry
        }

        let bucketRecord = try editableBucketRecord(projectID: projectID, bucketID: bucketID)

        let now = Date.now
        let timeRange = WorkspaceEntryDurationParser.timeRangeMinutes(from: draft.timeInput)
        let hourlyRateMinorUnits = persistedBucketDefaultRate(for: bucketRecord)
            ?? bucket.hourlyRateMinorUnits
            ?? project.defaultHourlyRateMinorUnits
            ?? 0
        let record = TimeEntryRecord(
            bucketID: bucketID,
            workDate: draft.date,
            startMinuteOfDay: timeRange?.start,
            endMinuteOfDay: timeRange?.end,
            durationMinutes: durationMinutes,
            descriptionText: description,
            isBillable: draft.isBillable,
            hourlyRateMinorUnits: hourlyRateMinorUnits,
            createdAt: now,
            updatedAt: now,
            bucket: bucketRecord
        )
        modelContext.insert(record)

        if bucketRecord.status == .ready {
            bucketRecord.status = .open
        }
        bucketRecord.updatedAt = now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        let bucketName = projectedBucketName(
            projectID: projectID,
            bucketID: bucketID,
            fallback: bucketRecord.name
        )
        appendActivity(
            message: "\(bucketName) entry added",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketTimeEntryAdded(bucketName: bucketName, projectName: project.name)
        try persistWorkspace()
    }

    func addFixedCostToNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceFixedCostDraft,
        occurredAt: Date
    ) throws {
        let project = try project(projectID)
        _ = try bucket(bucketID, in: project)

        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, draft.amountMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidFixedCost
        }

        let bucketRecord = try editableBucketRecord(projectID: projectID, bucketID: bucketID)

        let now = Date.now
        let record = FixedCostRecord(
            bucketID: bucketID,
            date: draft.date,
            descriptionText: description,
            quantity: 1,
            unitPriceMinorUnits: draft.amountMinorUnits,
            isBillable: true,
            createdAt: now,
            updatedAt: now,
            bucket: bucketRecord
        )
        modelContext.insert(record)

        if bucketRecord.status == .ready {
            bucketRecord.status = .open
        }
        bucketRecord.updatedAt = now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        let bucketName = projectedBucketName(
            projectID: projectID,
            bucketID: bucketID,
            fallback: bucketRecord.name
        )
        appendActivity(
            message: "\(bucketName) cost added",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketFixedCostAdded(bucketName: bucketName, projectName: project.name)
        try persistWorkspace()
    }

    func deleteEntryFromNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        rowID: UUID,
        kind: WorkspaceBucketEntryKind,
        isBillable _: Bool,
        occurredAt: Date
    ) throws {
        let project = try project(projectID)
        _ = try bucket(bucketID, in: project)

        let bucketRecord = try editableBucketRecord(projectID: projectID, bucketID: bucketID)

        let deleted: Bool
        switch kind {
        case .time:
            deleted = try deleteTimeEntryRecord(id: rowID, bucketID: bucketID)
        case .fixedCost:
            deleted = try deleteFixedCostRecord(id: rowID, bucketID: bucketID)
        }

        guard deleted else {
            throw WorkspaceStoreError.entryNotFound
        }

        if bucketRecord.status == .ready {
            bucketRecord.status = .open
        }
        bucketRecord.updatedAt = .now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
        let bucketName = projectedBucketName(
            projectID: projectID,
            bucketID: bucketID,
            fallback: bucketRecord.name
        )
        appendActivity(
            message: "\(bucketName) entry deleted",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketEntryDeleted(bucketName: bucketName, projectName: project.name)
        try persistWorkspace()
    }

    private func editableBucketRecord(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID
    ) throws -> BucketRecord {
        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }

        let bucketStatus = bucketRecord.status
        guard !bucketStatus.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucketStatus)
        }

        return bucketRecord
    }

    private func persistedBucketDefaultRate(for bucketRecord: BucketRecord) -> Int? {
        guard bucketRecord.defaultHourlyRateMinorUnits > 0 else { return nil }
        return bucketRecord.defaultHourlyRateMinorUnits
    }

    private func projectedBucketName(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        fallback: String
    ) -> String {
        workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? fallback
    }

    private func deleteTimeEntryRecord(id: UUID, bucketID: WorkspaceBucket.ID) throws -> Bool {
        var descriptor = FetchDescriptor<TimeEntryRecord>(
            predicate: #Predicate { $0.id == id && $0.bucketID == bucketID }
        )
        descriptor.fetchLimit = 1

        guard let record = try modelContext.fetch(descriptor).first else {
            return false
        }

        modelContext.delete(record)
        return true
    }

    private func deleteFixedCostRecord(id: UUID, bucketID: WorkspaceBucket.ID) throws -> Bool {
        var descriptor = FetchDescriptor<FixedCostRecord>(
            predicate: #Predicate { $0.id == id && $0.bucketID == bucketID }
        )
        descriptor.fetchLimit = 1

        guard let record = try modelContext.fetch(descriptor).first else {
            return false
        }

        modelContext.delete(record)
        return true
    }
}
