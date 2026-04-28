import SwiftUI

struct AppLaunchConfiguration: Equatable {
    static let workspacePathArgument = "--pika-workspace-path"

    let workspaceSeed: WorkspaceSeed
    let initialWorkspace: WorkspaceSnapshot
    let persistenceURL: URL?

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        workspaceSeed = WorkspaceSeed.resolve(arguments: arguments, environment: environment)
        initialWorkspace = workspaceSeed.initialWorkspace
        persistenceURL = Self.persistenceURL(arguments: arguments)
            ?? WorkspaceStore.defaultPersistenceURL()
    }

    private static func persistenceURL(arguments: [String]) -> URL? {
        guard let pathIndex = arguments.firstIndex(of: workspacePathArgument) else {
            return nil
        }

        let valueIndex = arguments.index(after: pathIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return URL(fileURLWithPath: arguments[valueIndex])
    }
}

private struct PikaDependencyModifier: ViewModifier {
    @State private var appRouter = AppRouter()
    @State private var workspaceStore: WorkspaceStore

    init(configuration: AppLaunchConfiguration = AppLaunchConfiguration()) {
        _workspaceStore = State(
            initialValue: WorkspaceStore(
                seed: configuration.initialWorkspace,
                persistenceURL: configuration.persistenceURL
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
