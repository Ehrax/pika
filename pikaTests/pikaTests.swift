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

    @Test func selectedSidebarProjectUsesAccentSelectionTreatment() {
        #expect(SidebarProjectRowAppearance(isSelected: true).selectionTreatment == .sidebarAccent)
        #expect(SidebarProjectRowAppearance(isSelected: false).selectionTreatment == .none)
    }

    @Test func sidebarProjectRowsAreOneLineWithDot() {
        #expect(SidebarProjectRowLayout.displaysProjectDot)
        #expect(SidebarProjectRowLayout.displaysClientSubtitle == false)
    }

    @Test func sidebarProjectDotsUseThemePalette() {
        #expect(SidebarProjectDotPalette.colorCount == 15)
        #expect(SidebarProjectDotPalette.colorIndex(forProjectAt: 0) == 0)
        #expect(SidebarProjectDotPalette.colorIndex(forProjectAt: 1) == 7)
        #expect(SidebarProjectDotPalette.colorIndex(forProjectAt: 2) == 14)
    }

    @Test func sidebarProjectDotPaletteDoesNotRepeatBeforePaletteIsExhausted() {
        let firstPalettePass = (0..<SidebarProjectDotPalette.colorCount)
            .map(SidebarProjectDotPalette.colorIndex(forProjectAt:))

        #expect(Set(firstPalettePass).count == SidebarProjectDotPalette.colorCount)
    }

    @Test func sidebarProjectRowsUseFullWidthSelectionWithChildIndentation() {
        #expect(SidebarProjectRowLayout.listInsets.leading == 0)
        #expect(SidebarProjectRowLayout.listInsets.trailing == SidebarProjectRowLayout.listInsets.leading)
        #expect(SidebarProjectsFolderRowLayout.listInsets.trailing == SidebarProjectsFolderRowLayout.listInsets.leading)
        #expect(SidebarProjectRowLayout.contentLeadingPadding == 24)
        #expect(SidebarProjectRowLayout.contentHorizontalPadding == PikaSpacing.sm)
        #expect(SidebarProjectRowLayout.expandsSelectionToAvailableWidth)
    }

    @Test func sidebarProjectsFolderStartsExpanded() {
        #expect(SidebarProjectsDisclosurePolicy.isExpandedByDefault)
        #expect(SidebarProjectsDisclosurePolicy.disclosurePlacement == .leading)
    }

    @Test func sidebarProjectsDisclosureOnlyShowsWhenProjectsExist() {
        #expect(SidebarProjectsDisclosurePolicy.showsDisclosure(activeProjectCount: 1))
        #expect(!SidebarProjectsDisclosurePolicy.showsDisclosure(activeProjectCount: 0))
    }

    @Test func clientRowsUseFullCellHitTargets() {
        #expect(ClientRowHitTargetPolicy.hitTarget == .fullCell)
    }

    @Test func dashboardStackedLayoutPromotesRevenueBeforeAttention() {
        #expect(DashboardPanelLayoutPolicy.layoutMode == .stackedAtAllWidths)
        #expect(DashboardPanelLayoutPolicy.stackedOrder == [.revenueHistory, .needsAttention])
        #expect(DashboardPanelLayoutPolicy.revenueChartHeight == 220)
    }

    @Test func moneyFormattingFormatsEuroMinorUnits() {
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        #expect(formatter.string(fromMinorUnits: 12345) == "EUR 123.45")
    }

    @Test func currencyTextFormattingSeparatesPastedAmountsFromCodes() {
        #expect(CurrencyTextFormatting.normalizedInput("500EUR") == "500 EUR")
        #expect(CurrencyTextFormatting.normalizedInput("50.00eur") == "50.00 EUR")
        #expect(CurrencyTextFormatting.normalizedInput(" EUR ") == "EUR")
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
        #expect(PikaApp.defaultLaunchWindowSize.width == 1_408)
        #expect(PikaApp.defaultLaunchWindowSize.height == 813)
        #expect(MainWindowLayout.frameAutosaveName == "PikaMainWindowFrame")
        #expect(MainWindowLayout.frameStorageKey == "pika.mainWindow.frame")
    }

    @Test func macOSPrimarySidebarPolicyStartsWithBreathingRoom() {
        #expect(PrimarySidebarColumnLayout.minimumWidth == 220)
        #expect(PrimarySidebarColumnLayout.idealWidth == 242)
        #expect(PrimarySidebarColumnLayout.maximumWidth == 520)
        #expect(PrimarySidebarColumnLayout.widthStorageKey == "pika.primarySidebar.width")
    }

    @Test func resizableDetailSplitPolicyPersistsWideSecondarySidebar() {
        #expect(ResizableDetailSplitLayout.leadingMinimumWidth == 240)
        #expect(ResizableDetailSplitLayout.leadingIdealWidth == 403)
        #expect(ResizableDetailSplitLayout.leadingMaximumWidth == 720)
        #expect(ResizableDetailSplitLayout.detailMinimumWidth == 520)
        #expect(ResizableDetailSplitLayout.leadingWidthStorageKey == "pika.resizableDetailSplit.leadingWidth")
    }

    @Test func secondarySidebarHeaderAvoidsMacWindowChromeWhenItBecomesLeadingColumn() {
        #expect(PikaSecondarySidebarLayout.headerTopPadding >= PikaSpacing.md)
        #expect(PikaSecondarySidebarLayout.leadingChromeClearance(forColumnMinX: 0) >= 116)
        #expect(PikaSecondarySidebarLayout.leadingChromeClearance(forColumnMinX: 260) == 0)
    }

    @Test func workspaceStoreStartsEmptyByDefault() {
        let store = WorkspaceStore()

        #expect(store.workspace.clients.isEmpty)
        #expect(store.workspace.projects.isEmpty)
        #expect(store.workspace.activity.isEmpty)
        #expect(store.workspace.businessProfile.invoicePrefix == "INV")
        #expect(store.workspace.businessProfile.nextInvoiceNumber == 1)
    }

    @Test func appLaunchConfigurationUsesBikeparkWorkspaceByDefault() {
        let configuration = AppLaunchConfiguration(arguments: ["pika"], environment: [:])

        #expect(configuration.initialWorkspace == .bikeparkThunersee)
    }

    @Test func appLaunchConfigurationCanUseProjectLocalPersistencePath() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-workspace-path", "/tmp/pika-empty-workspace.json"],
            environment: [:]
        )

        #expect(configuration.persistenceURL?.path == "/tmp/pika-empty-workspace.json")
    }

#if DEBUG
    @Test func appLaunchConfigurationCanOptIntoSampleWorkspaceForDevelopment() {
        let argumentConfiguration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-seed-workspace"],
            environment: [:]
        )
        let environmentConfiguration = AppLaunchConfiguration(
            arguments: ["pika"],
            environment: ["PIKA_SEED_WORKSPACE": "1"]
        )

        #expect(argumentConfiguration.initialWorkspace == .sample)
        #expect(environmentConfiguration.initialWorkspace == .sample)
    }

    @Test func appLaunchConfigurationCanOptIntoBikeparkWorkspaceForDevelopment() {
        let argumentConfiguration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-seed-bikepark-thunersee"],
            environment: [:]
        )
        let environmentConfiguration = AppLaunchConfiguration(
            arguments: ["pika"],
            environment: ["PIKA_SEED_WORKSPACE": "bikepark-thunersee"]
        )

        #expect(argumentConfiguration.initialWorkspace == .bikeparkThunersee)
        #expect(environmentConfiguration.initialWorkspace == .bikeparkThunersee)
    }
#endif

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
