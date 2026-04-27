import SwiftData
import SwiftUI

@main
struct PikaApp: App {
    static let defaultLaunchWindowSize = CGSize(width: 1_200, height: 780)

    let sharedModelContainer: ModelContainer

    init() {
        do {
            sharedModelContainer = try Self.makeModelContainer(inMemory: false)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .pikaDependencies()
                .tint(PikaColor.accent)
        }
        .modelContainer(sharedModelContainer)
#if os(macOS)
        .defaultSize(Self.defaultLaunchWindowSize)
#endif
    }

    static func makeModelContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([
            ProjectRecord.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
