import SwiftData
import SwiftUI

@main
struct PikaApp: App {
    static let defaultLaunchWindowSize = CGSize(width: 1_408, height: 813)
#if os(macOS)
    static let workspaceArchiveCommandGroupTypeNames = WorkspaceArchiveFileMenuCommandSurface.commandGroupTypeNames
#endif

    let launchConfiguration: AppLaunchConfiguration
    let sharedModelContainer: ModelContainer

    init() {
        launchConfiguration = AppLaunchConfiguration()
        do {
            sharedModelContainer = try Self.makeModelContainer(mode: launchConfiguration.persistenceMode)
            AppTelemetry.persistenceContainerConfigured(
                mode: launchConfiguration.persistenceMode.telemetryName,
                cloudKitEnabled: launchConfiguration.persistenceMode.cloudKitEnabled
            )
        } catch {
            AppTelemetry.persistenceContainerCreationFailed(
                mode: launchConfiguration.persistenceMode.telemetryName,
                cloudKitEnabled: launchConfiguration.persistenceMode.cloudKitEnabled,
                message: String(describing: error)
            )
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .pikaDependencies(
                    configuration: launchConfiguration,
                    modelContainer: sharedModelContainer
                )
                .font(PikaTypography.body)
                .tint(PikaColor.accent)
#if os(macOS)
                .background(MainWindowPersistenceView())
#endif
        }
        .modelContainer(sharedModelContainer)
#if os(macOS)
        .defaultSize(Self.defaultLaunchWindowSize)
        .commands {
            WorkspaceArchiveFileMenuCommandSurface.commands
        }
#endif
    }

    static func makeModelContainer(
        mode: AppPersistenceMode,
        overrideStoreURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = PikaPersistenceSchema.makeSchema()
        try prepareStoreDirectoryIfNeeded(mode: mode, overrideStoreURL: overrideStoreURL)
        let configuration = mode.makeModelConfiguration(
            schema: schema,
            overrideStoreURL: overrideStoreURL
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func prepareStoreDirectoryIfNeeded(
        mode: AppPersistenceMode,
        overrideStoreURL: URL?
    ) throws {
        guard mode == .local, let overrideStoreURL else { return }

        let directory = overrideStoreURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }
}

enum AppPersistenceMode: Equatable {
    static let cloudKitContainerIdentifier = "iCloud.ehrax.dev.pika"

    case cloudKitPrivate
    case local
    case inMemory

    var telemetryName: String {
        switch self {
        case .cloudKitPrivate:
            "cloudkit_private"
        case .local:
            "local"
        case .inMemory:
            "in_memory"
        }
    }

    var cloudKitEnabled: Bool {
        switch self {
        case .cloudKitPrivate:
            true
        case .local, .inMemory:
            false
        }
    }

    func makeModelConfiguration(
        schema: Schema,
        overrideStoreURL: URL? = nil
    ) -> ModelConfiguration {
        switch self {
        case .cloudKitPrivate:
            return ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
            )
        case .local:
            if let overrideStoreURL {
                return ModelConfiguration(
                    schema: schema,
                    url: overrideStoreURL,
                    cloudKitDatabase: .none
                )
            } else {
                return ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .none
                )
            }
        case .inMemory:
            return ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        }
    }
}

enum MainWindowLayout {
    static let frameAutosaveName = "PikaMainWindowFrame"
    static let frameStorageKey = "pika.mainWindow.frame"
}
