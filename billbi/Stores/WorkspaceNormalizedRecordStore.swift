import SwiftData

protocol WorkspaceNormalizedRecordStore {
    func fetch<Record: PersistentModel>(_ descriptor: FetchDescriptor<Record>) throws -> [Record]
    func insert<Record: PersistentModel>(_ record: Record)
    func delete<Record: PersistentModel>(_ record: Record)
}

struct SwiftDataWorkspaceNormalizedRecordStore: WorkspaceNormalizedRecordStore {
    let modelContext: ModelContext

    func fetch<Record: PersistentModel>(_ descriptor: FetchDescriptor<Record>) throws -> [Record] {
        try modelContext.fetch(descriptor)
    }

    func insert<Record: PersistentModel>(_ record: Record) {
        modelContext.insert(record)
    }

    func delete<Record: PersistentModel>(_ record: Record) {
        modelContext.delete(record)
    }
}
