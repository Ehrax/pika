import SwiftData
import SwiftUI

@main
struct BillbiApp: App {
    static let defaultLaunchWindowSize = CGSize(width: 1_408, height: 813)
#if os(macOS)
    static let workspaceArchiveCommandGroupTypeNames = WorkspaceArchiveFileMenuCommandSurface.commandGroupTypeNames
#endif

    let launchConfiguration: AppLaunchConfiguration
    let appEnvironment: AppEnvironment
    let sharedModelContainer: ModelContainer

    init() {
        launchConfiguration = AppLaunchConfiguration()
        do {
            appEnvironment = try AppEnvironment.resolve()
            sharedModelContainer = try Self.makeModelContainer(
                mode: launchConfiguration.persistenceMode,
                appEnvironment: appEnvironment
            )
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
                .billbiDependencies(
                    configuration: launchConfiguration,
                    modelContainer: sharedModelContainer
                )
                .font(BillbiTypography.body)
                .tint(BillbiColor.actionAccent)
                .accentColor(BillbiColor.actionAccent)
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
        overrideStoreURL: URL? = nil,
        appEnvironment: AppEnvironment = .production
    ) throws -> ModelContainer {
        let schema = BillbiPersistenceSchema.makeSchema()
        let storeURL = overrideStoreURL ?? defaultStoreURL(
            mode: mode,
            appEnvironment: appEnvironment
        )
        try prepareStoreDirectoryIfNeeded(storeURL: storeURL)
        let configuration = mode.makeModelConfiguration(
            schema: schema,
            storeURL: storeURL,
            appEnvironment: appEnvironment
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func defaultStoreURL(
        mode: AppPersistenceMode,
        appEnvironment: AppEnvironment,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "ehrax.dev.billbi"
    ) -> URL? {
        guard mode.usesPersistentStore else { return nil }

        let sanitizedBundleIdentifier = bundleIdentifier
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: ".")
        let applicationSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupportDirectory
            .appendingPathComponent("Billbi", isDirectory: true)
            .appendingPathComponent(appEnvironment.name, isDirectory: true)
            .appendingPathComponent(sanitizedBundleIdentifier, isDirectory: true)
            .appendingPathComponent("Billbi.store")
    }

    private static func prepareStoreDirectoryIfNeeded(
        storeURL: URL?
    ) throws {
        guard let storeURL else { return }

        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }
}

enum AppPersistenceMode: Equatable {
    case cloudKitPrivate
    case local
    case inMemory

    nonisolated init?(launchValue: String) {
        switch launchValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "cloudkit", "cloudkit-private", "cloudkit_private":
            self = .cloudKitPrivate
        case "local", "disk":
            self = .local
        case "memory", "in-memory", "in_memory":
            self = .inMemory
        default:
            return nil
        }
    }

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
        storeURL: URL? = nil,
        appEnvironment: AppEnvironment = .production
    ) -> ModelConfiguration {
        switch self {
        case .cloudKitPrivate:
            if let storeURL {
                return ModelConfiguration(
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .private(appEnvironment.cloudKitContainerIdentifier)
                )
            } else {
                return ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private(appEnvironment.cloudKitContainerIdentifier)
                )
            }
        case .local:
            if let storeURL {
                return ModelConfiguration(
                    schema: schema,
                    url: storeURL,
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

    var usesPersistentStore: Bool {
        switch self {
        case .cloudKitPrivate, .local:
            true
        case .inMemory:
            false
        }
    }
}

enum MainWindowLayout {
    static let frameAutosaveName = "BillbiMainWindowFrame"
    static let frameStorageKey = "billbi.mainWindow.frame"
}
