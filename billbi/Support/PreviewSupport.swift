import SwiftData

enum PreviewSupport {
    static func makeModelContainer() throws -> ModelContainer {
        try BillbiApp.makeModelContainer(mode: .inMemory)
    }
}
