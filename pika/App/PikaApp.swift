import SwiftData
import SwiftUI

@main
struct PikaApp: App {
    static let defaultLaunchWindowSize = CGSize(width: 1_408, height: 813)

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
                .font(PikaTypography.body)
                .tint(PikaColor.accent)
#if os(macOS)
                .background(MainWindowPersistenceView())
#endif
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
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

enum MainWindowLayout {
    static let frameAutosaveName = "PikaMainWindowFrame"
    static let frameStorageKey = "pika.mainWindow.frame"
}
