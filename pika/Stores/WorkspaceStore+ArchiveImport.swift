import Foundation

extension WorkspaceStore {
    func validateImportedWorkspaceArchive(_ data: Data) throws -> WorkspaceArchiveImportSummary {
        try WorkspaceArchiveImportValidator.validateAndSummarize(data)
    }
}
