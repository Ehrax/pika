import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftData
import SwiftUI
import Testing
@testable import pika

struct PikaScaffoldTests {
    @Test func designTokensExposeExpectedScaffoldValues() {
        #expect(PikaSpacing.md == 16)
        #expect(PikaRadius.lg == 8)
        #expect(PikaStatusTone.success.accessibilityLabel == "Success")
    }

    @Test func moneyFormattingFormatsEuroMinorUnits() {
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        #expect(formatter.string(fromMinorUnits: 12345) == "EUR 123.45")
    }

    @Test func projectRecordDefaultsArePikaSpecificAndFlexible() {
        let createdAt = Date(timeIntervalSince1970: 1_776_000_000)
        let project = ProjectRecord(title: "Client work", createdAt: createdAt)

        #expect(project.title == "Client work")
        #expect(project.createdAt == createdAt)
        #expect(project.isArchived == false)
        #expect(project.id.uuidString.isEmpty == false)
    }

    @Test func appModelContainerCanBeCreatedInMemory() throws {
        let container = try PikaApp.makeModelContainer(inMemory: true)

        let context = ModelContext(container)
        let project = ProjectRecord(title: "Preview project")
        context.insert(project)
        try context.save()

        let records = try context.fetch(FetchDescriptor<ProjectRecord>())
        #expect(records.map(\.title) == ["Preview project"])
    }

    @MainActor
    @Test func navigationBoundariesAreHashableValueState() {
        let projectID = UUID()
        let route = AppRoute.project(id: projectID)
        let matchingRoute = AppRoute.project(id: projectID)
        let sheet = SheetDestination.projectEditor(id: projectID)
        let newProjectSheet = SheetDestination.projectEditor(id: nil)

        #expect(route == matchingRoute)
        #expect(Set([route, matchingRoute]).count == 1)
        #expect(sheet == SheetDestination.projectEditor(id: projectID))
        #expect(sheet.id == "projectEditor-\(projectID.uuidString)")
        #expect(newProjectSheet.id == "projectEditor-new")
    }

    @MainActor
    @Test func appRouterSheetPresentationDoesNotMutatePath() {
        let projectID = UUID()
        let route = AppRoute.project(id: projectID)
        let sheet = SheetDestination.projectEditor(id: projectID)
        let router = AppRouter()

        router.push(route)
        let pathBeforeSheetPresentation = router.path

        router.present(sheet: sheet)

        #expect(router.path == pathBeforeSheetPresentation)
        #expect(router.sheet == sheet)

        router.dismissSheet()

        #expect(router.path == pathBeforeSheetPresentation)
        #expect(router.sheet == nil)
    }

    @MainActor
    @Test func dependencyEnvironmentDoesNotCreateSharedRouterFallback() {
        var environment = EnvironmentValues()

        #expect(environment.appRouter == nil)
        #expect(environment.appSettings.defaultPaymentTermsDays == 14)
        #expect(environment.projectStore.placeholderProjects().isEmpty)
        #expect(throws: InvoicePDFService.Error.notImplemented) {
            try environment.invoicePDFService.renderDraftPDF()
        }

        let router = AppRouter()
        environment.appRouter = router

        #expect(environment.appRouter === router)
    }

    @MainActor
    @Test func pikaDependenciesInjectsBoundaryDefaultsIntoViewEnvironment() throws {
        let probe = DependencyProbeBox()
        renderDependencyProbe(
            DependencyProbeView(probe: probe)
                .pikaDependencies()
        )

        let snapshot = try #require(probe.snapshot)
        #expect(snapshot.router != nil)
        #expect(snapshot.defaultPaymentTermsDays == 14)
        #expect(snapshot.placeholderProjectsAreEmpty)
        #expect(snapshot.pdfThrowsNotImplemented)
    }

    @Test func appSettingsExposeDefaultPaymentTerms() {
        let settings = AppSettings()

        #expect(settings.defaultPaymentTermsDays == 14)
    }

    @Test func placeholderInvoicePDFServiceThrowsNotImplemented() {
        let service = InvoicePDFService.placeholder()

        #expect(throws: InvoicePDFService.Error.notImplemented) {
            try service.renderDraftPDF()
        }
    }
}

@MainActor
private final class DependencyProbeBox {
    var snapshot: DependencySnapshot?
}

private struct DependencySnapshot {
    let router: AppRouter?
    let defaultPaymentTermsDays: Int
    let placeholderProjectsAreEmpty: Bool
    let pdfThrowsNotImplemented: Bool
}

@MainActor
private func renderDependencyProbe<Content: View>(_ content: Content) {
    #if os(macOS)
    let hostingView = NSHostingView(rootView: content)
    hostingView.frame = NSRect(x: 0, y: 0, width: 10, height: 10)
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    #elseif os(iOS)
    let hostingController = UIHostingController(rootView: content)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    window.rootViewController = hostingController
    window.makeKeyAndVisible()
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    #endif
}

private struct DependencyProbeView: View {
    @Environment(\.appRouter) private var appRouter
    @Environment(\.appSettings) private var appSettings
    @Environment(\.projectStore) private var projectStore
    @Environment(\.invoicePDFService) private var invoicePDFService

    let probe: DependencyProbeBox

    var body: some View {
        Color.clear
            .onAppear {
                probe.snapshot = DependencySnapshot(
                    router: appRouter,
                    defaultPaymentTermsDays: appSettings.defaultPaymentTermsDays,
                    placeholderProjectsAreEmpty: projectStore.placeholderProjects().isEmpty,
                    pdfThrowsNotImplemented: pdfThrowsNotImplemented()
                )
            }
    }

    private func pdfThrowsNotImplemented() -> Bool {
        do {
            _ = try invoicePDFService.renderDraftPDF()
            return false
        } catch InvoicePDFService.Error.notImplemented {
            return true
        } catch {
            return false
        }
    }
}
