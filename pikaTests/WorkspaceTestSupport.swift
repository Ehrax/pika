import Foundation
import SwiftData
@testable import pika

func makePersistentModelContext() throws -> (ModelContext, URL) {
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("pika-workspace-\(UUID().uuidString)")
        .appendingPathComponent("workspace.store")
    let container = try WorkspaceStore.makeModelContainer(mode: .local, storeURL: storeURL)
    return (ModelContext(container), storeURL)
}
