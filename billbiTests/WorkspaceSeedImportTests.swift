import Foundation
import SwiftData
import Testing
@testable import billbi

struct WorkspaceSeedImportTests {
    @Test func bikeparkWorkspaceSeedContainsRealProjectAndWorklog() throws {
        let workspace = WorkspaceFixtures.bikeparkWorkspace
        let project = try #require(workspace.project(named: "Play Bikepark"))
        let bucket = try #require(project.buckets.first)

        #expect(workspace.businessProfile.businessName == "ehrax.dev")
        #expect(workspace.businessProfile.taxIdentifier == "151/260/41486")
        #expect(workspace.businessProfile.economicIdentifier == "DE320253387")
        #expect(workspace.clients.map(\.name) == ["Verein Bikepark Thunersee"])
        #expect(workspace.clients.first?.billingAddress == "Untere Ttüelmatt 4\n3624 Goldiwil\nSchweiz")
        #expect(bucket.name == "Trailpass Launch")
        #expect(bucket.status == .ready)
        #expect(bucket.timeEntries.count == 31)
        #expect(bucket.effectiveBillableMinutes == 4_440)
        #expect(bucket.effectiveTotalMinorUnits == 370_000)
        #expect(bucket.timeEntries.first?.date == Date.billbiDate(year: 2026, month: 3, day: 2))
        #expect(bucket.timeEntries.first?.description == "Initial MVP scaffold and webhook pipeline")
        #expect(bucket.timeEntries.map(\.date).contains(Date.billbiDate(year: 2036, month: 3, day: 26)) == false)
        #expect(bucket.timeEntries.map(\.date).contains(Date.billbiDate(year: 2026, month: 3, day: 26)))
    }

    @Test func explicitSeedResetReplacesExistingLocalRecordsWithDeterministicNormalizedImport() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let baselineStore = WorkspaceStore(
            seed: WorkspaceSnapshot(
                businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
                clients: [
                    WorkspaceClient(
                        id: UUID(uuidString: "10000000-0000-0000-0000-000000009511")!,
                        name: "Legacy local client",
                        email: "legacy@example.com",
                        billingAddress: "1 Legacy Road",
                        defaultTermsDays: 14
                    ),
                ],
                projects: [],
                activity: []
            ),
            modelContext: modelContext
        )

        #expect(baselineStore.workspace.clients.map(\.name) == ["Legacy local client"])

        let seededSample = WorkspaceStore(
            seed: WorkspaceFixtures.demoWorkspace,
            modelContext: modelContext,
            resetForSeedImport: true
        )

        let sampleClients = try modelContext.fetch(FetchDescriptor<ClientRecord>())
        let sampleProjects = try modelContext.fetch(FetchDescriptor<ProjectRecord>())
        let sampleBuckets = try modelContext.fetch(FetchDescriptor<BucketRecord>())
        let sampleEntries = try modelContext.fetch(FetchDescriptor<TimeEntryRecord>())
        let sampleFixedCosts = try modelContext.fetch(FetchDescriptor<FixedCostRecord>())
        let sampleInvoices = try modelContext.fetch(FetchDescriptor<InvoiceRecord>())
        let sampleInvoiceLineItems = try modelContext.fetch(FetchDescriptor<InvoiceLineItemRecord>())

        #expect(seededSample.workspace.clients.map(\.name).contains("Legacy local client") == false)
        #expect(seededSample.workspace.clients.map(\.name) == WorkspaceFixtures.demoWorkspace.clients.map(\.name))
        #expect(sampleClients.count == WorkspaceFixtures.demoWorkspace.clients.count)
        #expect(sampleProjects.count == WorkspaceFixtures.demoWorkspace.projects.count)
        #expect(sampleBuckets.count > 0)
        #expect(sampleEntries.count > 0)
        #expect(sampleFixedCosts.count > 0)
        #expect(sampleInvoices.count > 0)
        #expect(sampleInvoiceLineItems.count > 0)

        let seededBikepark = WorkspaceStore(
            seed: WorkspaceFixtures.bikeparkWorkspace,
            modelContext: modelContext,
            resetForSeedImport: true
        )
        let bikeparkClients = try modelContext.fetch(FetchDescriptor<ClientRecord>())
        let bikeparkProjects = try modelContext.fetch(FetchDescriptor<ProjectRecord>())
        let bikeparkEntries = try modelContext.fetch(FetchDescriptor<TimeEntryRecord>())

        #expect(
            seededBikepark.workspace.projects.map(\.name) ==
                WorkspaceFixtures.bikeparkWorkspace.projects.map(\.name)
        )
        #expect(bikeparkClients.count == WorkspaceFixtures.bikeparkWorkspace.clients.count)
        #expect(bikeparkProjects.count == WorkspaceFixtures.bikeparkWorkspace.projects.count)
        #expect(
            bikeparkEntries.count ==
                WorkspaceFixtures.bikeparkWorkspace.projects.flatMap(\.buckets).flatMap(\.timeEntries).count
        )
    }
}
