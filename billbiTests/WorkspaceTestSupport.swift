import Foundation
import SwiftData
@testable import billbi

func makePersistentModelContext() throws -> (ModelContext, URL) {
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("billbi-workspace-\(UUID().uuidString)")
        .appendingPathComponent("workspace.store")
    let container = try WorkspaceStore.makeModelContainer(mode: .local, storeURL: storeURL)
    return (ModelContext(container), storeURL)
}

func makePersistentModelContainer() throws -> (ModelContainer, URL) {
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("billbi-workspace-\(UUID().uuidString)")
        .appendingPathComponent("workspace.store")
    let container = try WorkspaceStore.makeModelContainer(mode: .local, storeURL: storeURL)
    return (container, storeURL)
}
