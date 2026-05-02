import SwiftData
import SwiftUI

struct AppLaunchConfiguration: Equatable {
    private static let xctestConfigurationEnvironmentKey = "XCTestConfigurationFilePath"
    private static let uiTestingEnvironmentKey = "PIKA_UI_TESTING"

    let workspaceSeed: WorkspaceSeed
    let initialWorkspace: WorkspaceSnapshot
    let persistenceMode: AppPersistenceMode

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isRunningTests: Bool? = nil
    ) {
        let resolvedIsRunningTests = (isRunningTests == true) || Self.resolveIsRunningTests(environment: environment)
        workspaceSeed = WorkspaceSeed.resolve(arguments: arguments, environment: environment)
        initialWorkspace = workspaceSeed.initialWorkspace
        persistenceMode = Self.resolvePersistenceMode(
            workspaceSeed: workspaceSeed,
            isRunningTests: resolvedIsRunningTests
        )
    }

    private static func resolveIsRunningTests(environment: [String: String]) -> Bool {
        if environment[xctestConfigurationEnvironmentKey] != nil {
            return true
        }

        let uiTestingFlag = environment[uiTestingEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch uiTestingFlag {
        case "1", "true", "yes":
            return true
        default:
            return false
        }
    }

    private static func resolvePersistenceMode(
        workspaceSeed: WorkspaceSeed,
        isRunningTests: Bool
    ) -> AppPersistenceMode {
        if isRunningTests {
            return .inMemory
        }

        switch workspaceSeed {
        case .empty:
            return .cloudKitPrivate
        case .sample, .bikeparkThunersee:
            return .local
        }
    }
}

private struct PikaDependencyModifier: ViewModifier {
    @State private var appRouter = AppRouter()
    @State private var workspaceStore: WorkspaceStore

    init(
        configuration: AppLaunchConfiguration = AppLaunchConfiguration(),
        modelContainer: ModelContainer
    ) {
        _workspaceStore = State(
            initialValue: WorkspaceStore(
                seed: configuration.initialWorkspace,
                modelContext: ModelContext(modelContainer),
                resetForSeedImport: configuration.workspaceSeed.requiresDeterministicResetImport
            )
        )
    }

    func body(content: Content) -> some View {
        content
            .environment(\.appRouter, appRouter)
            .environment(\.appSettings, AppSettings())
            .environment(\.workspaceStore, workspaceStore)
            .environment(\.invoicePDFService, InvoicePDFService.placeholder())
    }
}

extension View {
    func pikaDependencies(
        configuration: AppLaunchConfiguration = AppLaunchConfiguration(),
        modelContainer: ModelContainer
    ) -> some View {
        modifier(PikaDependencyModifier(configuration: configuration, modelContainer: modelContainer))
    }
}

private struct AppRouterKey: EnvironmentKey {
    static let defaultValue: AppRouter? = nil
}

private struct AppSettingsKey: EnvironmentKey {
    static let defaultValue = AppSettings()
}

private struct WorkspaceStoreKey: EnvironmentKey {
    static let defaultValue = WorkspaceStore(seed: .empty)
}

#if os(macOS)
private struct FocusedWorkspaceStoreKey: FocusedValueKey {
    typealias Value = WorkspaceStore
}
#endif

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

    var workspaceStore: WorkspaceStore {
        get { self[WorkspaceStoreKey.self] }
        set { self[WorkspaceStoreKey.self] = newValue }
    }

    var invoicePDFService: InvoicePDFService {
        get { self[InvoicePDFServiceKey.self] }
        set { self[InvoicePDFServiceKey.self] = newValue }
    }
}

#if os(macOS)
extension FocusedValues {
    var workspaceStore: WorkspaceStore? {
        get { self[FocusedWorkspaceStoreKey.self] }
        set { self[FocusedWorkspaceStoreKey.self] = newValue }
    }
}
#endif
