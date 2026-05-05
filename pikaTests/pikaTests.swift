import Foundation
@testable import pika
import SwiftData
import SwiftUI
import Testing

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
        let firstPalettePass = (0 ..< SidebarProjectDotPalette.colorCount)
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

    @Test func dashboardLayoutPromotesRevenuePanelsBeforeAttention() {
        #expect(DashboardPanelLayoutPolicy.layoutMode == .stackedAtAllWidths)
        #expect(DashboardPanelLayoutPolicy.revenuePanels == [.unbilledProjectRevenue, .revenueHistory])
        #expect(DashboardPanelLayoutPolicy.stackedOrder == [.needsAttention])
        #expect(DashboardPanelLayoutPolicy.revenuePanelMinimumWidth == 360)
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

    @Test func normalizedPersistenceRecordsUseCloudKitFriendlyDefaultsAndTypedEnums() throws {
        let clientID = try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000501"))
        let projectID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000501"))
        let bucketID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000501"))
        let invoiceID = try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000501"))
        let lineItemID = try #require(UUID(uuidString: "50000000-0000-0000-0000-000000000501"))

        let profile = BusinessProfileRecord()
        let client = ClientRecord(id: clientID, name: "Northstar Labs")
        let project = ProjectRecord(clientID: clientID, name: "Client work")
        let bucket = BucketRecord(projectID: projectID, name: "April sprint")
        let entry = TimeEntryRecord(bucketID: bucketID)
        let cost = FixedCostRecord(bucketID: bucketID)
        let invoice = InvoiceRecord(
            id: invoiceID,
            projectID: projectID,
            bucketID: bucketID,
            templateRaw: "classic",
            statusRaw: "unknown"
        )
        let lineItem = InvoiceLineItemRecord(id: lineItemID, invoiceID: invoiceID)

        #expect(profile.invoicePrefix == "INV")
        #expect(profile.nextInvoiceNumber == 1)
        #expect(profile.defaultTermsDays == 14)
        #expect(client.defaultTermsDays == 14)
        #expect(project.clientID == clientID)
        #expect(project.client == nil)
        #expect(project.currencyCode == "EUR")
        #expect(project.isArchived == false)
        #expect(bucket.projectID == projectID)
        #expect(bucket.project == nil)
        #expect(bucket.status == .open)
        #expect(entry.bucketID == bucketID)
        #expect(entry.bucket == nil)
        #expect(cost.bucketID == bucketID)
        #expect(cost.bucket == nil)
        #expect(cost.quantity == 1)
        #expect(invoice.projectID == projectID)
        #expect(invoice.bucketID == bucketID)
        #expect(invoice.project == nil)
        #expect(invoice.bucket == nil)
        #expect(invoice.status == .finalized)
        #expect(invoice.template == .kleinunternehmerClassic)
        #expect(lineItem.invoiceID == invoiceID)
        #expect(lineItem.invoice == nil)
        #expect(lineItem.sortOrder == 0)

        bucket.status = .ready
        invoice.status = .paid
        invoice.template = .kleinunternehmerClassic

        #expect(bucket.statusRaw == BucketStatus.ready.rawValue)
        #expect(invoice.statusRaw == InvoiceStatus.paid.rawValue)
        #expect(invoice.templateRaw == InvoiceTemplate.kleinunternehmerClassic.rawValue)
    }

    @Test func appModelContainerCanPersistNormalizedRecordsInMemory() throws {
        let container = try PikaApp.makeModelContainer(mode: .inMemory)

        let context = ModelContext(container)
        let client = ClientRecord(name: "Preview client", email: "billing@preview.example", billingAddress: "1 Preview Way")
        let project = ProjectRecord(clientID: client.id, name: "Preview project")
        project.client = client
        context.insert(client)
        context.insert(project)
        try context.save()

        let clients = try context.fetch(FetchDescriptor<ClientRecord>())
        let records = try context.fetch(FetchDescriptor<ProjectRecord>())
        #expect(clients.map(\.name) == ["Preview client"])
        #expect(records.map(\.name) == ["Preview project"])
        #expect(records.first?.clientID == clients.first?.id)
    }

    @Test func macOSLaunchWindowPolicyStartsWithRoomForSidebarAndContent() {
        #expect(PikaApp.defaultLaunchWindowSize.width == 1408)
        #expect(PikaApp.defaultLaunchWindowSize.height == 813)
        #expect(MainWindowLayout.frameAutosaveName == "PikaMainWindowFrame")
        #expect(MainWindowLayout.frameStorageKey == "pika.mainWindow.frame")
    }

    @Test func macOSLaunchChecksCoverArchiveFileMenuCommandSurfaceOnly() {
        #expect(WorkspaceArchiveFileMenuCommandSurface.commandTitles == [
            "Export Workspace Archive…",
            "Import Workspace Archive…",
            "Reveal Workspace Backups",
        ])
    }

    @Test func macOSLaunchChecksConfirmArchiveCommandGroupsAreWiredToFileMenu() {
        #expect(PikaApp.workspaceArchiveCommandGroupTypeNames == WorkspaceArchiveFileMenuCommandSurface.commandGroupTypeNames)
        #expect(PikaApp.workspaceArchiveCommandGroupTypeNames == [
            "WorkspaceArchiveCommands",
        ])
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

    @Test func appLaunchConfigurationUsesEmptyWorkspaceByDefault() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika"],
            environment: [:],
            isRunningTests: false
        )

        #expect(configuration.workspaceSeed == .empty)
        #expect(configuration.initialWorkspace == .empty)
        #expect(configuration.persistenceMode == .cloudKitPrivate)
    }

    @Test func appEnvironmentResolvesDevelopmentMetadata() throws {
        let environment = try AppEnvironment.resolve(
            infoDictionary: [
                AppEnvironment.environmentNameInfoDictionaryKey: "dev",
                AppEnvironment.cloudKitContainerIdentifierInfoDictionaryKey: "iCloud.ehrax.dev.pika.dev",
            ]
        )

        #expect(environment == .development)
    }

    @Test func appEnvironmentResolvesProductionMetadata() throws {
        let environment = try AppEnvironment.resolve(
            infoDictionary: [
                AppEnvironment.environmentNameInfoDictionaryKey: "prod",
                AppEnvironment.cloudKitContainerIdentifierInfoDictionaryKey: "iCloud.ehrax.dev.pika",
            ]
        )

        #expect(environment == .production)
    }

    @Test func appEnvironmentRejectsMissingCloudKitContainerMetadata() {
        #expect(throws: AppEnvironment.ResolveError.missingInfoDictionaryValue(
            key: AppEnvironment.cloudKitContainerIdentifierInfoDictionaryKey
        )) {
            try AppEnvironment.resolve(
                infoDictionary: [
                    AppEnvironment.environmentNameInfoDictionaryKey: "dev",
                ]
            )
        }
    }

    @Test func cloudKitPrivatePersistenceUsesResolvedEnvironmentContainer() {
        let schema = PikaPersistenceSchema.makeSchema()
        let configuration = AppPersistenceMode.cloudKitPrivate.makeModelConfiguration(
            schema: schema,
            storeURL: PikaApp.defaultStoreURL(
                mode: .cloudKitPrivate,
                appEnvironment: .development,
                bundleIdentifier: "ehrax.dev.pika.dev"
            ),
            appEnvironment: .development
        )

        #expect(String(describing: configuration).contains("iCloud.ehrax.dev.pika.dev"))
    }

    @Test func persistentStoreURLsAreSeparatedByEnvironmentAndBundleIdentifier() throws {
        let devStoreURL = try #require(PikaApp.defaultStoreURL(
            mode: .cloudKitPrivate,
            appEnvironment: .development,
            bundleIdentifier: "ehrax.dev.pika.dev"
        ))
        let prodStoreURL = try #require(PikaApp.defaultStoreURL(
            mode: .cloudKitPrivate,
            appEnvironment: .production,
            bundleIdentifier: "ehrax.dev.pika"
        ))

        #expect(devStoreURL != prodStoreURL)
        #expect(devStoreURL.path().contains("/Pika/dev/ehrax.dev.pika.dev/"))
        #expect(prodStoreURL.path().contains("/Pika/prod/ehrax.dev.pika/"))
    }

    @Test func inMemoryPersistenceDoesNotResolvePersistentStoreURL() {
        let storeURL = PikaApp.defaultStoreURL(
            mode: .inMemory,
            appEnvironment: .development,
            bundleIdentifier: "ehrax.dev.pika.dev"
        )

        #expect(storeURL == nil)
    }

    @Test func workspaceBackupsDirectoryIsSeparatedByEnvironmentAndBundleIdentifier() throws {
        let temporaryApplicationSupportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryApplicationSupportURL)
        }

        let backupsURL = try WorkspaceArchiveActions.workspaceBackupsDirectoryURL(
            appSupportDirectoryURL: temporaryApplicationSupportURL
        )

        #expect(backupsURL.path().contains("/Pika/dev/ehrax.dev.pika.dev/Backups"))
    }

    @Test func appLaunchConfigurationIgnoresUnknownArguments() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "pika",
                "--not-a-real-argument", "unexpected-value",
            ],
            environment: [:],
            isRunningTests: false
        )

        #expect(configuration.workspaceSeed == .empty)
        #expect(configuration.initialWorkspace == .empty)
        #expect(configuration.persistenceMode == .cloudKitPrivate)
    }

    @Test func appLaunchConfigurationUsesLocalModeForExplicitSeedResets() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-workspace-seed", "sample"],
            environment: [:],
            isRunningTests: false
        )

        #expect(configuration.workspaceSeed == .sample)
        #expect(configuration.persistenceMode == .local)
    }

    @Test func appLaunchConfigurationUsesExplicitLocalPersistenceOverride() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-persistence", "local"],
            environment: [:],
            isRunningTests: false
        )

        #expect(configuration.workspaceSeed == .empty)
        #expect(configuration.persistenceMode == .local)
    }

    @Test func appLaunchConfigurationUsesExplicitInMemoryPersistenceOverride() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika"],
            environment: ["PIKA_PERSISTENCE": "in-memory"],
            isRunningTests: false
        )

        #expect(configuration.workspaceSeed == .empty)
        #expect(configuration.persistenceMode == .inMemory)
    }

    @Test func appLaunchConfigurationUsesInMemoryModeDuringTests() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-workspace-seed", "sample"],
            environment: [:],
            isRunningTests: true
        )

        #expect(configuration.persistenceMode == .inMemory)
    }

    @Test func buildAndRunScriptDoesNotUseLegacyWorkspaceStorePathOverrides() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = repositoryRoot.appendingPathComponent("script/build_and_run.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        #expect(script.contains("--pika-workspace-store-path") == false)
        #expect(script.contains("PIKA_WORKSPACE_STORE_PATH") == false)
        #expect(script.contains("--prod") == true)
        #expect(script.contains("--pika-persistence") == true)
    }

    @Test func prodArtifactScriptBuildsFinderOnlyLocalAndCloudArtifacts() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = repositoryRoot.appendingPathComponent("script/build_prod_artifact.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        #expect(script.contains("Release Prod") == true)
        #expect(script.contains("PikaProdLocal") == true)
        #expect(script.contains("PikaProdCloud") == true)
        #expect(script.contains("LSEnvironment:PIKA_PERSISTENCE") == true)
        #expect(script.contains("open \"$ARTIFACT_DIR\"") == true)
    }

    @Test func codexDevActionsUseExplicitLocalPersistence() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let environmentURL = repositoryRoot.appendingPathComponent(".codex/environments/environment.toml")
        let environment = try String(contentsOf: environmentURL, encoding: .utf8)

        #expect(environment.contains("name = \"Dev Empty\"") == true)
        #expect(environment.contains("command = \"./script/build_and_run.sh --verify --empty --local\"") == true)
        #expect(environment.contains("command = \"./script/build_and_run.sh --verify --seeded --local\"") == true)
        #expect(environment.contains("command = \"./script/build_and_run.sh --verify --bikepark --local\"") == true)
    }

    @Test func appLaunchConfigurationUsesInMemoryModeForExplicitUITestEnvironment() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika"],
            environment: ["PIKA_UI_TESTING": "1"],
            isRunningTests: false
        )

        #expect(configuration.persistenceMode == .inMemory)
    }

    @Test func appLaunchConfigurationCanExplicitlyUseEmptyWorkspace() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--empty"],
            environment: [:]
        )

        #expect(configuration.workspaceSeed == .empty)
        #expect(configuration.initialWorkspace == .empty)
    }

    @Test func appLaunchConfigurationParsesDemoWorkspaceSeed() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-workspace-seed", "sample"],
            environment: [:]
        )

        #expect(configuration.workspaceSeed == .sample)
    }

    @Test func appLaunchConfigurationParsesLegacyDemoWorkspaceSeedFlag() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-seed-workspace"],
            environment: [:]
        )

        #expect(configuration.workspaceSeed == .sample)
    }

    @Test func appLaunchConfigurationParsesBikeparkWorkspaceSeed() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika", "--pika-workspace-seed", "bikepark-thunersee"],
            environment: [:]
        )

        #expect(configuration.workspaceSeed == .bikeparkThunersee)
    }

    @Test func appLaunchConfigurationParsesEnvironmentWorkspaceSeed() {
        let configuration = AppLaunchConfiguration(
            arguments: ["pika"],
            environment: ["PIKA_WORKSPACE_SEED": "sample"]
        )

        #expect(configuration.workspaceSeed == .sample)
    }

    #if DEBUG
        @Test func appLaunchConfigurationResolvesDemoWorkspaceSeedForDevelopment() {
            let configuration = AppLaunchConfiguration(
                arguments: ["pika", "--pika-workspace-seed", "sample"],
                environment: [:]
            )

            #expect(configuration.initialWorkspace == WorkspaceSeedLibrary.demoWorkspace)
        }

        @Test func appLaunchConfigurationResolvesBikeparkWorkspaceSeedForDevelopment() {
            let configuration = AppLaunchConfiguration(
                arguments: ["pika", "--pika-workspace-seed", "bikepark-thunersee"],
                environment: [:]
            )

            #expect(configuration.initialWorkspace == WorkspaceSeedLibrary.bikeparkThunersee)
        }
    #else
        @Test func appLaunchConfigurationFallsBackToEmptyForDevelopmentOnlySeedsInRelease() {
            let demoConfiguration = AppLaunchConfiguration(
                arguments: ["pika", "--pika-workspace-seed", "sample"],
                environment: [:]
            )
            let bikeparkConfiguration = AppLaunchConfiguration(
                arguments: ["pika", "--pika-workspace-seed", "bikepark-thunersee"],
                environment: [:]
            )

            #expect(demoConfiguration.workspaceSeed == .sample)
            #expect(demoConfiguration.initialWorkspace == .empty)
            #expect(bikeparkConfiguration.workspaceSeed == .bikeparkThunersee)
            #expect(bikeparkConfiguration.initialWorkspace == .empty)
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

    @Test func cloudKitSyncConfigurationIncludesRequiredCapabilitiesAndPersistenceTelemetryHooks() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementsURL = repositoryRoot.appendingPathComponent("pika/pika.entitlements")
        let projectURL = repositoryRoot.appendingPathComponent("pika.xcodeproj/project.pbxproj")
        let devSchemeURL = repositoryRoot.appendingPathComponent("pika.xcodeproj/xcshareddata/xcschemes/Pika Dev.xcscheme")
        let prodSchemeURL = repositoryRoot.appendingPathComponent("pika.xcodeproj/xcshareddata/xcschemes/Pika Prod.xcscheme")
        let telemetryURL = repositoryRoot.appendingPathComponent("pika/Services/AppTelemetry.swift")
        let workspacePersistenceURL = repositoryRoot.appendingPathComponent("pika/Stores/WorkspaceStore+Persistence.swift")

        let entitlements = try String(contentsOf: entitlementsURL, encoding: .utf8)
        let project = try String(contentsOf: projectURL, encoding: .utf8)
        let devScheme = try String(contentsOf: devSchemeURL, encoding: .utf8)
        let prodScheme = try String(contentsOf: prodSchemeURL, encoding: .utf8)
        let telemetry = try String(contentsOf: telemetryURL, encoding: .utf8)
        let workspacePersistence = try String(contentsOf: workspacePersistenceURL, encoding: .utf8)
        let remoteNotificationBackgroundModeSettings = [
            #""INFOPLIST_KEY_UIBackgroundModes[sdk=iphoneos*]" = "remote-notification";"#,
            #""INFOPLIST_KEY_UIBackgroundModes[sdk=iphonesimulator*]" = "remote-notification";"#,
        ]
        let requiredConfigurationNames = [
            "Debug Dev",
            "Release Dev",
            "Debug Prod",
            "Release Prod",
        ]

        #expect(entitlements.contains("<key>com.apple.developer.icloud-container-identifiers</key>"))
        #expect(entitlements.contains("<string>$(PIKA_CLOUDKIT_CONTAINER_IDENTIFIER)</string>"))
        #expect(entitlements.contains("<string>$(TeamIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)</string>"))
        #expect(entitlements.contains("<string>CloudKit</string>"))
        for setting in remoteNotificationBackgroundModeSettings {
            #expect(project.contains(setting))
        }
        for configurationName in requiredConfigurationNames {
            #expect(project.contains("/* \(configurationName) */"))
        }
        #expect(devScheme.contains(#"buildConfiguration = "Debug Dev""#))
        #expect(devScheme.contains(#"buildConfiguration = "Release Dev""#))
        #expect(devScheme.contains(#"BuildableName = "pika-dev.app""#))
        #expect(prodScheme.contains(#"buildConfiguration = "Debug Prod""#))
        #expect(prodScheme.contains(#"buildConfiguration = "Release Prod""#))
        #expect(prodScheme.contains(#"BuildableName = "pika.app""#))
        #expect(telemetry.contains("persistence.container_configured"))
        #expect(telemetry.contains("persistence.save_failed"))
        #expect(telemetry.contains("persistence.projection_reload_failed"))
        #expect(workspacePersistence.contains("AppTelemetry.persistenceSaveFailed("))
        #expect(workspacePersistence.contains("AppTelemetry.persistenceProjectionReloadFailed("))
    }

}
