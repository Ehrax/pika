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

        guard bucket.billingMode != .fixed else {
            throw WorkspaceStoreError.invalidTimeEntry
        }

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
        normalizedRecordStore.insert(record)

        if bucketRecord.status == .ready {
            bucketRecord.status = .open
        }
        bucketRecord.updatedAt = now

        try commitNormalizedWorkspaceMutation {
            projectedBucketName(
                projectID: projectID,
                bucketID: bucketID,
                fallback: bucketRecord.name
            )
        } activity: { bucketName in
            WorkspaceActivity(
                message: "\(bucketName) entry added",
                detail: project.name,
                occurredAt: occurredAt
            )
        } telemetry: { bucketName in
            AppTelemetry.bucketTimeEntryAdded(bucketName: bucketName, projectName: project.name)
        }
    }

    func addFixedCostToNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceFixedCostDraft,
        occurredAt: Date
    ) throws {
        let project = try project(projectID)
        let bucket = try bucket(bucketID, in: project)

        guard bucket.billingMode != .fixed else {
            throw WorkspaceStoreError.invalidFixedCost
        }

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
        normalizedRecordStore.insert(record)

        if bucketRecord.status == .ready {
            bucketRecord.status = .open
        }
        bucketRecord.updatedAt = now

        try commitNormalizedWorkspaceMutation {
            projectedBucketName(
                projectID: projectID,
                bucketID: bucketID,
                fallback: bucketRecord.name
            )
        } activity: { bucketName in
            WorkspaceActivity(
                message: "\(bucketName) cost added",
                detail: project.name,
                occurredAt: occurredAt
            )
        } telemetry: { bucketName in
            AppTelemetry.bucketFixedCostAdded(bucketName: bucketName, projectName: project.name)
        }
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

        try commitNormalizedWorkspaceMutation {
            projectedBucketName(
                projectID: projectID,
                bucketID: bucketID,
                fallback: bucketRecord.name
            )
        } activity: { bucketName in
            WorkspaceActivity(
                message: "\(bucketName) entry deleted",
                detail: project.name,
                occurredAt: occurredAt
            )
        } telemetry: { bucketName in
            AppTelemetry.bucketEntryDeleted(bucketName: bucketName, projectName: project.name)
        }
    }

    func updateEntryDateInNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        rowID: UUID,
        kind: WorkspaceBucketEntryKind,
        date: Date
    ) throws {
        let project = try project(projectID)
        _ = try bucket(bucketID, in: project)

        let bucketRecord = try editableBucketRecord(projectID: projectID, bucketID: bucketID)
        let now = Date.now

        let updated: Bool
        switch kind {
        case .time:
            updated = try updateTimeEntryRecordDate(id: rowID, bucketID: bucketID, date: date, updatedAt: now)
        case .fixedCost:
            updated = try updateFixedCostRecordDate(id: rowID, bucketID: bucketID, date: date, updatedAt: now)
        }

        guard updated else {
            throw WorkspaceStoreError.entryNotFound
        }

        if bucketRecord.status == .ready {
            bucketRecord.status = .open
        }
        bucketRecord.updatedAt = now

        try saveAndReloadNormalizedWorkspacePreservingActivity()
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

        guard let record = try normalizedRecordStore.fetch(descriptor).first else {
            return false
        }

        normalizedRecordStore.delete(record)
        return true
    }

    private func deleteFixedCostRecord(id: UUID, bucketID: WorkspaceBucket.ID) throws -> Bool {
        var descriptor = FetchDescriptor<FixedCostRecord>(
            predicate: #Predicate { $0.id == id && $0.bucketID == bucketID }
        )
        descriptor.fetchLimit = 1

        guard let record = try normalizedRecordStore.fetch(descriptor).first else {
            return false
        }

        normalizedRecordStore.delete(record)
        return true
    }

    private func updateTimeEntryRecordDate(
        id: UUID,
        bucketID: WorkspaceBucket.ID,
        date: Date,
        updatedAt: Date
    ) throws -> Bool {
        var descriptor = FetchDescriptor<TimeEntryRecord>(
            predicate: #Predicate { $0.id == id && $0.bucketID == bucketID }
        )
        descriptor.fetchLimit = 1

        guard let record = try normalizedRecordStore.fetch(descriptor).first else {
            return false
        }

        record.workDate = date
        record.updatedAt = updatedAt
        return true
    }

    private func updateFixedCostRecordDate(
        id: UUID,
        bucketID: WorkspaceBucket.ID,
        date: Date,
        updatedAt: Date
    ) throws -> Bool {
        var descriptor = FetchDescriptor<FixedCostRecord>(
            predicate: #Predicate { $0.id == id && $0.bucketID == bucketID }
        )
        descriptor.fetchLimit = 1

        guard let record = try normalizedRecordStore.fetch(descriptor).first else {
            return false
        }

        record.date = date
        record.updatedAt = updatedAt
        return true
    }
}
