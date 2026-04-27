protocol ProjectStore {
    func placeholderProjects() -> [ProjectRecord]
}

struct NoopProjectStore: ProjectStore {
    func placeholderProjects() -> [ProjectRecord] {
        []
    }
}

protocol WorkspaceStore {
    func workspace() -> WorkspaceSnapshot
}

struct SampleWorkspaceStore: WorkspaceStore {
    func workspace() -> WorkspaceSnapshot {
        .sample
    }
}
