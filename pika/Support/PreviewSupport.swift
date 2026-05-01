import SwiftData

enum PreviewSupport {
    static func makeModelContainer() throws -> ModelContainer {
        try PikaApp.makeModelContainer(mode: .inMemory)
    }
}
