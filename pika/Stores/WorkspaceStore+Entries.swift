import Foundation
import SwiftData

extension WorkspaceStore {
    func addTimeEntry(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceTimeEntryDraft,
        occurredAt: Date = .now
    ) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try addTimeEntryToNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                draft: draft,
                occurredAt: occurredAt
            )
            return
        }

        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        var bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard !bucket.status.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucket.status)
        }

        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !description.isEmpty,
            let durationMinutes = WorkspaceEntryDurationParser.minutes(from: draft.timeInput)
        else {
            throw WorkspaceStoreError.invalidTimeEntry
        }

        bucket.backfillLegacyRowsForEditing(on: draft.date)
        let labels = WorkspaceEntryDurationParser.timeRangeLabels(from: draft.timeInput)
        let displayLabel = WorkspaceEntryDurationParser.displayLabel(from: draft.timeInput)
        bucket.timeEntries.append(WorkspaceTimeEntry(
            date: draft.date,
            startTime: labels?.start ?? displayLabel,
            endTime: labels?.end ?? "",
            durationMinutes: durationMinutes,
            description: description,
            isBillable: draft.isBillable,
            hourlyRateMinorUnits: bucket.hourlyRateMinorUnits ?? workspace.projects[projectIndex].defaultHourlyRateMinorUnits ?? 0
        ))
        if bucket.status == .ready {
            bucket.status = .open
        }

        workspace.projects[projectIndex].buckets[bucketIndex] = bucket
        appendActivity(
            message: "\(bucket.name) entry added",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketTimeEntryAdded(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }

    func addFixedCost(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceFixedCostDraft,
        occurredAt: Date = .now
    ) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try addFixedCostToNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                draft: draft,
                occurredAt: occurredAt
            )
            return
        }

        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        var bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard !bucket.status.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucket.status)
        }

        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, draft.amountMinorUnits > 0 else {
            throw WorkspaceStoreError.invalidFixedCost
        }

        bucket.backfillLegacyRowsForEditing(on: draft.date)
        bucket.fixedCostEntries.append(WorkspaceFixedCostEntry(
            date: draft.date,
            description: description,
            amountMinorUnits: draft.amountMinorUnits
        ))
        if bucket.status == .ready {
            bucket.status = .open
        }

        workspace.projects[projectIndex].buckets[bucketIndex] = bucket
        appendActivity(
            message: "\(bucket.name) cost added",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketFixedCostAdded(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }

    func deleteEntry(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        rowID: UUID,
        kind: WorkspaceBucketEntryKind,
        isBillable: Bool,
        occurredAt: Date = .now
    ) throws {
        if isUsingNormalizedWorkspacePersistence() {
            try deleteEntryFromNormalizedRecords(
                projectID: projectID,
                bucketID: bucketID,
                rowID: rowID,
                kind: kind,
                isBillable: isBillable,
                occurredAt: occurredAt
            )
            return
        }

        let projectIndex = try projectIndex(projectID)
        let bucketIndex = try bucketIndex(bucketID, in: workspace.projects[projectIndex])
        var bucket = workspace.projects[projectIndex].buckets[bucketIndex]

        guard !bucket.status.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucket.status)
        }

        guard bucket.deleteEntry(rowID: rowID, kind: kind, isBillable: isBillable) else {
            throw WorkspaceStoreError.entryNotFound
        }

        if bucket.status == .ready {
            bucket.status = .open
        }

        workspace.projects[projectIndex].buckets[bucketIndex] = bucket
        appendActivity(
            message: "\(bucket.name) entry deleted",
            detail: workspace.projects[projectIndex].name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketEntryDeleted(bucketName: bucket.name, projectName: workspace.projects[projectIndex].name)
        try persistWorkspace()
    }

    private func addTimeEntryToNormalizedRecords(
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

        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }
        let bucketStatus = bucketRecord.status
        guard !bucketStatus.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucketStatus)
        }

        let now = Date.now
        let timeRange = WorkspaceEntryDurationParser.timeRangeMinutes(from: draft.timeInput)
        let hourlyRateMinorUnits = bucket.hourlyRateMinorUnits
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
        let bucketName = workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? bucketRecord.name
        appendActivity(
            message: "\(bucketName) entry added",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketTimeEntryAdded(bucketName: bucketName, projectName: project.name)
        try persistWorkspace()
    }

    private func addFixedCostToNormalizedRecords(
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

        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }
        let bucketStatus = bucketRecord.status
        guard !bucketStatus.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucketStatus)
        }

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
        let bucketName = workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? bucketRecord.name
        appendActivity(
            message: "\(bucketName) cost added",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketFixedCostAdded(bucketName: bucketName, projectName: project.name)
        try persistWorkspace()
    }

    private func deleteEntryFromNormalizedRecords(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        rowID: UUID,
        kind: WorkspaceBucketEntryKind,
        isBillable _: Bool,
        occurredAt: Date
    ) throws {
        let project = try project(projectID)
        _ = try bucket(bucketID, in: project)

        guard let bucketRecord = try bucketRecord(bucketID),
              bucketRecord.projectID == projectID
        else {
            throw WorkspaceStoreError.bucketNotFound
        }
        let bucketStatus = bucketRecord.status
        guard !bucketStatus.isInvoiceLocked else {
            throw WorkspaceStoreError.bucketLocked(bucketStatus)
        }

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
        let bucketName = workspace.projects
            .first(where: { $0.id == projectID })?
            .buckets
            .first(where: { $0.id == bucketID })?
            .name ?? bucketRecord.name
        appendActivity(
            message: "\(bucketName) entry deleted",
            detail: project.name,
            occurredAt: occurredAt
        )
        AppTelemetry.bucketEntryDeleted(bucketName: bucketName, projectName: project.name)
        try persistWorkspace()
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
