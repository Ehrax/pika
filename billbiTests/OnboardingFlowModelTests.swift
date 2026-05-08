import Foundation
import Testing
@testable import billbi

struct OnboardingFlowModelTests {
    @Test func continueAlwaysAdvancesThroughFiveVisualSteps() {
        var flow = OnboardingFlowModel()

        #expect(flow.step == .welcome)
        flow.advance()
        #expect(flow.step == .business)
        flow.advance()
        #expect(flow.step == .client)
        flow.advance()
        #expect(flow.step == .project)
        flow.advance()
        #expect(flow.step == .ready)
        flow.advance()
        #expect(flow.step == .ready)
    }

    @Test func emptyWorkspaceBusinessDraftLeavesPreviewDefaultsAsPlaceholders() {
        let draft = OnboardingBusinessDraft(profile: WorkspaceSnapshot.empty.businessProfile)

        #expect(draft.invoicePrefix == "")
        #expect(draft.defaultTermsDays == 0)
    }

    @Test func savedBusinessProfileDraftKeepsConfiguredInvoiceDefaults() {
        let draft = OnboardingBusinessDraft(profile: BusinessProfileProjection(
            businessName: "North Coast Studio",
            email: "",
            address: "",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 1,
            currencyCode: "EUR",
            paymentDetails: "",
            taxNote: "",
            defaultTermsDays: 21
        ))

        #expect(draft.invoicePrefix == "NCS")
        #expect(draft.defaultTermsDays == 21)
    }

    @Test func readySummaryOnlyIncludesExistingSetupData() {
        let workspace = WorkspaceSnapshot(
            onboardingCompleted: false,
            businessProfile: BusinessProfileProjection(
                businessName: "North Coast Studio",
                email: "",
                address: "",
                invoicePrefix: "NCS",
                nextInvoiceNumber: 1,
                currencyCode: "EUR",
                paymentDetails: "",
                taxNote: "",
                defaultTermsDays: 14
            ),
            clients: [],
            projects: [],
            activity: []
        )

        #expect(OnboardingFlowModel.summaryCards(for: workspace) == [.business])
        #expect(OnboardingFlowModel.primaryCTA(for: workspace) == .dashboard)
    }

    @Test func readySummaryProjectsCardsCopyTipsBadgeAndCTAFromWorkspaceData() throws {
        let skippedSummary = OnboardingFlowModel.readySummary(for: .empty)
        #expect(skippedSummary.cards == [])
        #expect(skippedSummary.badgeState == .neutral)
        #expect(skippedSummary.badgeTitle == "SETUP SKIPPED")
        #expect(skippedSummary.title == "You're ready.")
        #expect(skippedSummary.subtitle == "You can start from the dashboard and fill details later.")
        #expect(skippedSummary.tips == [
            "Add your business profile in Settings",
            "Create your first client",
            "Open a project with a starter bucket",
        ])
        #expect(skippedSummary.primaryCTA == .dashboard)

        let businessOnlyWorkspace = WorkspaceSnapshot(
            onboardingCompleted: false,
            businessProfile: BusinessProfileProjection(
                businessName: "North Coast Studio",
                email: "",
                address: "",
                invoicePrefix: "NCS",
                nextInvoiceNumber: 1,
                currencyCode: "EUR",
                paymentDetails: "",
                taxNote: "",
                defaultTermsDays: 14
            ),
            clients: [],
            projects: [],
            activity: []
        )
        let businessOnlySummary = OnboardingFlowModel.readySummary(for: businessOnlyWorkspace)
        #expect(businessOnlySummary.cards == [.business])
        #expect(businessOnlySummary.badgeState == .success)
        #expect(businessOnlySummary.badgeTitle == "READY")
        #expect(businessOnlySummary.subtitle == "North Coast Studio is saved. Add clients and projects next.")
        #expect(businessOnlySummary.tips == [
            "Create your first client",
            "Open a project",
            "Review invoice details before finalizing",
        ])
        #expect(businessOnlySummary.primaryCTA == .dashboard)

        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000046")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000046")!
        let client = WorkspaceFixtures.demoWorkspace.clients[0]
        let completeWorkspace = WorkspaceSnapshot(
            onboardingCompleted: false,
            businessProfile: BusinessProfileProjection(
                businessName: "North Coast Studio",
                personName: "Mara",
                email: "",
                address: "",
                invoicePrefix: "NCS",
                nextInvoiceNumber: 1,
                currencyCode: "EUR",
                paymentDetails: "",
                taxNote: "",
                defaultTermsDays: 14
            ),
            clients: [client],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: client.id,
                    name: "Launch site",
                    clientName: client.name,
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "General",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0,
                            defaultHourlyRateMinorUnits: 8_000
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )
        let completeSummary = OnboardingFlowModel.readySummary(for: completeWorkspace)
        #expect(completeSummary.cards == [.business, .client, .project, .bucket])
        #expect(completeSummary.badgeState == .success)
        #expect(completeSummary.badgeTitle == "READY")
        #expect(completeSummary.title == "You're ready, Mara.")
        #expect(completeSummary.subtitle == "Launch site is ready with General.")
        #expect(completeSummary.tips == [
            "Log time in the first bucket",
            "Mark work ready when it is invoiceable",
            "Finalize invoices after details are complete",
        ])
        #expect(completeSummary.primaryCTA == .dashboard)
    }

    @Test func readyCTAOpensDashboardWhenProjectAndBucketExist() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000045")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000045")!
        let workspace = WorkspaceSnapshot(
            onboardingCompleted: false,
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: WorkspaceFixtures.demoWorkspace.clients[0].id,
                    name: "Launch site",
                    clientName: WorkspaceFixtures.demoWorkspace.clients[0].name,
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "General",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0,
                            defaultHourlyRateMinorUnits: 8_000
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )

        #expect(OnboardingFlowModel.summaryCards(for: workspace) == [.business, .client, .project, .bucket])
        #expect(OnboardingFlowModel.primaryCTA(for: workspace) == .dashboard)
    }

    @Test func continueActionDescribesSaveThresholdsAndCompletionHandoff() throws {
        let businessDraft = OnboardingBusinessDraft(businessName: "North Coast Studio")
        let clientDraft = OnboardingClientDraft(name: "Bikepark Thunersee")
        let emptyProjectDraft = OnboardingProjectDraft(name: "Launch site")
        let client = WorkspaceFixtures.demoWorkspace.clients[0]
        let workspaceWithClient = WorkspaceSnapshot(
            onboardingCompleted: false,
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [client],
            projects: [],
            activity: []
        )

        var flow = OnboardingFlowModel()
        #expect(flow.continueAction(
            workspace: .empty,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: emptyProjectDraft
        ) == .advanceOnly)

        flow.advance()
        #expect(flow.continueAction(
            workspace: .empty,
            businessDraft: OnboardingBusinessDraft(businessName: " "),
            clientDraft: clientDraft,
            projectDraft: emptyProjectDraft
        ) == .advanceOnly)
        #expect(flow.continueAction(
            workspace: .empty,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: emptyProjectDraft
        ) == .saveBusiness(businessDraft))

        flow.advance()
        #expect(flow.continueAction(
            workspace: .empty,
            businessDraft: businessDraft,
            clientDraft: OnboardingClientDraft(name: " "),
            projectDraft: emptyProjectDraft
        ) == .advanceOnly)
        #expect(flow.continueAction(
            workspace: .empty,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: emptyProjectDraft
        ) == .saveClient(clientDraft))

        flow.advance()
        #expect(flow.continueAction(
            workspace: .empty,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: emptyProjectDraft
        ) == .advanceOnly)
        #expect(flow.continueAction(
            workspace: workspaceWithClient,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: OnboardingProjectDraft(
                name: "Launch site",
                clientID: client.id,
                currencyCode: "",
                firstBucketName: "Strategy",
                hourlyRateMinorUnits: 8_000
            )
        ) == .advanceOnly)
        #expect(flow.continueAction(
            workspace: workspaceWithClient,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: OnboardingProjectDraft(
                name: "Launch site",
                clientID: client.id,
                currencyCode: "EUR",
                firstBucketName: "Strategy",
                hourlyRateMinorUnits: 0
            )
        ) == .advanceOnly)
        #expect(flow.continueAction(
            workspace: workspaceWithClient,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: OnboardingProjectDraft(
                name: "Launch site",
                clientID: client.id,
                currencyCode: "EUR",
                firstBucketName: "",
                hourlyRateMinorUnits: 8_000
            )
        ) == .saveProject(OnboardingProjectDraft(
            name: "Launch site",
            clientID: client.id,
            currencyCode: "EUR",
            firstBucketName: "",
            hourlyRateMinorUnits: 8_000
        )))

        flow.advance()
        #expect(flow.continueAction(
            workspace: workspaceWithClient,
            businessDraft: businessDraft,
            clientDraft: clientDraft,
            projectDraft: emptyProjectDraft
        ) == .complete(.dashboard))
    }
}
