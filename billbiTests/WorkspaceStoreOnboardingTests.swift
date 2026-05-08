import Foundation
import SwiftData
import Testing
@testable import billbi

struct WorkspaceStoreOnboardingTests {
    @Test func skipMarksOnboardingCompleteWithoutCreatingPlaceholderRecords() throws {
        let store = WorkspaceStore(seed: .empty)

        try store.completeOnboarding()

        #expect(store.workspace.onboardingCompleted)
        #expect(store.workspace.clients.isEmpty)
        #expect(store.workspace.projects.isEmpty)
    }

    @Test func onboardingBusinessSaveAllowsBusinessNameOnly() throws {
        let store = WorkspaceStore(seed: .empty)
        #expect(OnboardingBusinessDraft().defaultTermsDays == 0)

        try store.saveOnboardingBusiness(
            OnboardingBusinessDraft(
                businessName: "North Coast Studio",
                email: "",
                address: "",
                currencyCode: "CHF"
            )
        )

        #expect(store.workspace.businessProfile.businessName == "North Coast Studio")
        #expect(store.workspace.businessProfile.email == "")
        #expect(store.workspace.businessProfile.address == "")
        #expect(store.workspace.businessProfile.invoicePrefix == "INV")
        #expect(store.workspace.businessProfile.currencyCode == "CHF")
        #expect(store.workspace.businessProfile.defaultTermsDays == 14)
    }

    @Test func onboardingBusinessSavePersistsConfiguredInvoicePrefix() throws {
        let store = WorkspaceStore(seed: .empty)

        try store.saveOnboardingBusiness(
            OnboardingBusinessDraft(
                businessName: "North Coast Studio",
                invoicePrefix: "  ncs  "
            )
        )

        #expect(store.workspace.businessProfile.invoicePrefix == "NCS")
    }

    @Test func onboardingClientAndProjectRespectThresholdsAndGeneralBucketDefault() throws {
        let store = WorkspaceStore(seed: .empty)

        let emptyClient = try store.saveOnboardingClient(OnboardingClientDraft(name: " "))
        #expect(emptyClient == nil)
        #expect(store.workspace.clients.isEmpty)

        let savedClient = try store.saveOnboardingClient(OnboardingClientDraft(
            name: "Bikepark Thunersee",
            email: "",
            billingAddress: ""
        ))
        let client = try #require(savedClient)
        #expect(client.name == "Bikepark Thunersee")
        #expect(client.email == "")

        let emptyProject = try store.saveOnboardingProject(OnboardingProjectDraft(
            name: "",
            clientID: client.id,
            currencyCode: "",
            firstBucketName: ""
        ))
        #expect(emptyProject == nil)
        #expect(store.workspace.projects.isEmpty)

        let projectWithoutCurrency = try store.saveOnboardingProject(OnboardingProjectDraft(
            name: "Launch site",
            clientID: client.id,
            currencyCode: "",
            firstBucketName: "General",
            hourlyRateMinorUnits: 8_000
        ))
        #expect(projectWithoutCurrency == nil)
        #expect(store.workspace.projects.isEmpty)

        let projectWithoutRate = try store.saveOnboardingProject(OnboardingProjectDraft(
            name: "Launch site",
            clientID: client.id,
            currencyCode: "EUR",
            firstBucketName: "General",
            hourlyRateMinorUnits: 0
        ))
        #expect(projectWithoutRate == nil)
        #expect(store.workspace.projects.isEmpty)

        let savedProject = try store.saveOnboardingProject(OnboardingProjectDraft(
            name: "Launch site",
            clientID: client.id,
            currencyCode: "EUR",
            firstBucketName: " ",
            hourlyRateMinorUnits: 8_000
        ))
        let project = try #require(savedProject)
        #expect(project.name == "Launch site")
        #expect(project.currencyCode == "EUR")
        #expect(project.buckets.map(\.name) == ["General"])
    }

    @Test func persistentOnboardingCompletionReloadsFromWorkspaceData() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        try store.completeOnboarding()

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        #expect(reloadedStore.workspace.onboardingCompleted)
    }

    @Test func debugResetClearsOnlyOnboardingCompletion() throws {
        var workspace = WorkspaceFixtures.demoWorkspace
        workspace.onboardingCompleted = true
        let store = WorkspaceStore(seed: workspace)

        try store.resetOnboardingCompletionForDebug()

        #expect(store.workspace.onboardingCompleted == false)
        #expect(store.workspace.businessProfile.businessName == workspace.businessProfile.businessName)
        #expect(store.workspace.businessProfile.email == workspace.businessProfile.email)
        #expect(store.workspace.clients.map(\.id) == workspace.clients.map(\.id))
        #expect(store.workspace.projects.map(\.id) == workspace.projects.map(\.id))
        #expect(store.workspace.projects.flatMap(\.buckets).map(\.id) == workspace.projects.flatMap(\.buckets).map(\.id))
        #expect(store.workspace.activity.map(\.message) == workspace.activity.map(\.message))
    }
}
