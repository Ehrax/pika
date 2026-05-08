import Foundation

extension WorkspaceStore {
    @discardableResult
    func commitNormalizedWorkspaceMutation<Result>(
        projectedResult: () throws -> Result,
        activity: (Result) -> WorkspaceActivity?,
        telemetry: (Result) -> Void = { _ in }
    ) throws -> Result {
        try saveAndReloadNormalizedWorkspacePreservingActivity()
        let result = try projectedResult()

        if let activity = activity(result) {
            workspace.activity.append(activity)
        }

        telemetry(result)
        try persistWorkspace()
        return result
    }
}
