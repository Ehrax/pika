import Foundation

extension WorkspaceStore {
    func addTimeEntry(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceTimeEntryDraft,
        occurredAt: Date = .now
    ) throws {
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
}
