import SwiftData
import SwiftUI

struct AppLaunchConfiguration: Equatable {
    let workspaceSeed: WorkspaceSeed
    let initialWorkspace: WorkspaceSnapshot
    let workspaceStoreURL: URL?

    private static let workspaceStorePathArgument = "--pika-workspace-store-path"
    private static let legacyWorkspacePathArgument = "--pika-workspace-path"
    private static let workspaceStorePathEnvironmentKey = "PIKA_WORKSPACE_STORE_PATH"

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        workspaceSeed = WorkspaceSeed.resolve(arguments: arguments, environment: environment)
        initialWorkspace = workspaceSeed.initialWorkspace
        workspaceStoreURL = Self.resolveWorkspaceStoreURL(arguments: arguments, environment: environment)
    }

    private static func resolveWorkspaceStoreURL(
        arguments: [String],
        environment: [String: String]
    ) -> URL? {
        if let storePath = argumentValue(after: workspaceStorePathArgument, in: arguments), !storePath.isEmpty {
            return URL(fileURLWithPath: storePath)
        }

        if let legacyPath = argumentValue(after: legacyWorkspacePathArgument, in: arguments), !legacyPath.isEmpty {
            return migratedLegacyStoreURL(fromLegacyPath: legacyPath)
        }

        if let environmentPath = environment[workspaceStorePathEnvironmentKey], !environmentPath.isEmpty {
            return URL(fileURLWithPath: environmentPath)
        }

        return nil
    }

    private static func argumentValue(after argument: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument) else { return nil }
        let nextIndex = arguments.index(after: index)
        guard nextIndex < arguments.endIndex else { return nil }
        let value = arguments[nextIndex]
        guard !value.hasPrefix("--") else { return nil }
        return value
    }

    private static func migratedLegacyStoreURL(fromLegacyPath legacyPath: String) -> URL {
        let legacyURL = URL(fileURLWithPath: legacyPath)
        if legacyURL.pathExtension.lowercased() == "json" {
            return legacyURL.deletingPathExtension().appendingPathExtension("store")
        }
        return legacyURL
    }
}

private struct PikaDependencyModifier: ViewModifier {
    @State private var appRouter = AppRouter()
    @State private var workspaceStore: WorkspaceStore

    init(configuration: AppLaunchConfiguration = AppLaunchConfiguration()) {
        let container: ModelContainer
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        do {
            container = try WorkspaceStore.makeModelContainer(
                inMemory: isRunningTests,
                storeURL: isRunningTests ? nil : (configuration.workspaceStoreURL ?? WorkspaceStore.defaultStoreURL())
            )
        } catch {
            fatalError("Could not create workspace persistence container: \(error)")
        }

        _workspaceStore = State(
            initialValue: WorkspaceStore(
                seed: configuration.initialWorkspace,
                modelContext: ModelContext(container)
            )
        )
    }

    func body(content: Content) -> some View {
        content
            .environment(\.appRouter, appRouter)
            .environment(\.appSettings, AppSettings())
            .environment(\.projectStore, NoopProjectStore())
            .environment(\.workspaceStore, workspaceStore)
            .environment(\.invoicePDFService, InvoicePDFService.placeholder())
    }
}

extension View {
    func pikaDependencies(configuration: AppLaunchConfiguration = AppLaunchConfiguration()) -> some View {
        modifier(PikaDependencyModifier(configuration: configuration))
    }
}

private struct AppRouterKey: EnvironmentKey {
    static let defaultValue: AppRouter? = nil
}

private struct AppSettingsKey: EnvironmentKey {
    static let defaultValue = AppSettings()
}

private struct ProjectStoreKey: EnvironmentKey {
    static let defaultValue: any ProjectStore = NoopProjectStore()
}

private struct WorkspaceStoreKey: EnvironmentKey {
    static let defaultValue = WorkspaceStore(seed: .empty)
}

private struct InvoicePDFServiceKey: EnvironmentKey {
    static let defaultValue = InvoicePDFService.placeholder()
}

extension EnvironmentValues {
    var appRouter: AppRouter? {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }

    var appSettings: AppSettings {
        get { self[AppSettingsKey.self] }
        set { self[AppSettingsKey.self] = newValue }
    }

    var projectStore: any ProjectStore {
        get { self[ProjectStoreKey.self] }
        set { self[ProjectStoreKey.self] = newValue }
    }

    var workspaceStore: WorkspaceStore {
        get { self[WorkspaceStoreKey.self] }
        set { self[WorkspaceStoreKey.self] = newValue }
    }

    var invoicePDFService: InvoicePDFService {
        get { self[InvoicePDFServiceKey.self] }
        set { self[InvoicePDFServiceKey.self] = newValue }
    }
}
