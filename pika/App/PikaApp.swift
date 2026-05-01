import SwiftData
import SwiftUI

@main
struct PikaApp: App {
    static let defaultLaunchWindowSize = CGSize(width: 1_408, height: 813)

    let sharedModelContainer: ModelContainer

    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        do {
            sharedModelContainer = try Self.makeModelContainer(inMemory: isRunningTests)
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
            BusinessProfileRecord.self,
            ClientRecord.self,
            ProjectRecord.self,
            BucketRecord.self,
            TimeEntryRecord.self,
            FixedCostRecord.self,
            InvoiceRecord.self,
            InvoiceLineItemRecord.self,
            WorkspaceStorageRecord.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

enum MainWindowLayout {
    static let frameAutosaveName = "PikaMainWindowFrame"
    static let frameStorageKey = "pika.mainWindow.frame"
}
