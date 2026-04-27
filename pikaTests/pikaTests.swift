import Foundation
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

    @Test func selectedSidebarProjectCountUsesHighContrastForeground() {
        #expect(SidebarProjectRowAppearance(isSelected: true).readyCountContrast == .selectedForeground)
        #expect(SidebarProjectRowAppearance(isSelected: false).readyCountContrast == .success)
    }

    @Test func clientRowsUseFullCellHitTargets() {
        #expect(ClientRowHitTargetPolicy.hitTarget == .fullCell)
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

    @Test func macOSLaunchWindowPolicyStartsWithRoomForSidebarAndContent() {
        #expect(PikaApp.defaultLaunchWindowSize.width >= 1_200)
        #expect(PikaApp.defaultLaunchWindowSize.height >= 780)
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
