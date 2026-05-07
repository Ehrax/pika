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

    @Test func readyCTAOpensProjectWorkbenchWhenProjectAndBucketExist() throws {
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
        #expect(OnboardingFlowModel.primaryCTA(for: workspace) == .project(projectID: projectID, bucketID: bucketID))
    }
}
