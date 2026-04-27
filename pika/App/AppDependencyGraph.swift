import SwiftUI

private struct PikaDependencyModifier: ViewModifier {
    @State private var appRouter = AppRouter()

    func body(content: Content) -> some View {
        content
            .environment(\.appRouter, appRouter)
            .environment(\.appSettings, AppSettings())
            .environment(\.projectStore, NoopProjectStore())
            .environment(\.invoicePDFService, InvoicePDFService.placeholder())
    }
}

extension View {
    func pikaDependencies() -> some View {
        modifier(PikaDependencyModifier())
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

    var invoicePDFService: InvoicePDFService {
        get { self[InvoicePDFServiceKey.self] }
        set { self[InvoicePDFServiceKey.self] = newValue }
    }
}
