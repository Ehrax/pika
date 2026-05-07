import SwiftData
import SwiftUI

struct AppLaunchConfiguration: Equatable {
    private static let xctestConfigurationEnvironmentKey = "XCTestConfigurationFilePath"
    private static let uiTestingEnvironmentKey = "BILLBI_UI_TESTING"
    private static let persistenceArgument = "--billbi-persistence"
    private static let persistenceEnvironmentKey = "BILLBI_PERSISTENCE"

    let workspaceSeed: WorkspaceSeed
    let initialWorkspace: WorkspaceSnapshot
    let persistenceMode: AppPersistenceMode
    let resetsPersistentWorkspaceForSeedImport: Bool

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isRunningTests: Bool? = nil
    ) {
        let resolvedIsRunningTests = (isRunningTests == true) || Self.resolveIsRunningTests(environment: environment)
        workspaceSeed = WorkspaceSeed.resolve(arguments: arguments, environment: environment)
        initialWorkspace = workspaceSeed.initialWorkspace
        resetsPersistentWorkspaceForSeedImport = WorkspaceSeed.isExplicitlyRequested(
            arguments: arguments,
            environment: environment
        )
        persistenceMode = Self.resolvePersistenceMode(
            arguments: arguments,
            environment: environment,
            workspaceSeed: workspaceSeed,
            shouldResetForSeedImport: resetsPersistentWorkspaceForSeedImport,
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
        arguments: [String],
        environment: [String: String],
        workspaceSeed: WorkspaceSeed,
        shouldResetForSeedImport: Bool,
        isRunningTests: Bool
    ) -> AppPersistenceMode {
        if isRunningTests {
            return .inMemory
        }

        if let explicitPersistenceMode = resolveExplicitPersistenceMode(
            arguments: arguments,
            environment: environment
        ) {
            return explicitPersistenceMode
        }

        if shouldResetForSeedImport {
            return .local
        }

        switch workspaceSeed {
        case .empty:
            return .cloudKitPrivate
        case .sample, .bikeparkThunersee:
            return .local
        }
    }

    private static func resolveExplicitPersistenceMode(
        arguments: [String],
        environment: [String: String]
    ) -> AppPersistenceMode? {
        if let argumentIndex = arguments.firstIndex(of: persistenceArgument),
           arguments.indices.contains(argumentIndex + 1),
           let mode = AppPersistenceMode(launchValue: arguments[argumentIndex + 1]) {
            return mode
        }

        return environment[persistenceEnvironmentKey].flatMap(AppPersistenceMode.init(launchValue:))
    }
}

private struct BillbiDependencyModifier: ViewModifier {
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
                resetForSeedImport: configuration.resetsPersistentWorkspaceForSeedImport
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
    func billbiDependencies(
        configuration: AppLaunchConfiguration = AppLaunchConfiguration(),
        modelContainer: ModelContainer
    ) -> some View {
        modifier(BillbiDependencyModifier(configuration: configuration, modelContainer: modelContainer))
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
