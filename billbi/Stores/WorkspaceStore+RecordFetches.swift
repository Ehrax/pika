import Foundation
import SwiftData

extension WorkspaceStore {
    func clientRecord(_ id: WorkspaceClient.ID) throws -> ClientRecord? {
        var descriptor = FetchDescriptor<ClientRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try normalizedRecordStore.fetch(descriptor).first
    }

    func projectRecord(_ id: WorkspaceProject.ID) throws -> ProjectRecord? {
        var descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try normalizedRecordStore.fetch(descriptor).first
    }

    func bucketRecord(_ id: WorkspaceBucket.ID) throws -> BucketRecord? {
        var descriptor = FetchDescriptor<BucketRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try normalizedRecordStore.fetch(descriptor).first
    }

    func hasProjectRecordLinked(to clientID: WorkspaceClient.ID) throws -> Bool {
        var descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { $0.clientID == clientID }
        )
        descriptor.fetchLimit = 1
        return try !normalizedRecordStore.fetch(descriptor).isEmpty
    }

    func bucketRecords(for projectID: WorkspaceProject.ID) throws -> [BucketRecord] {
        let descriptor = FetchDescriptor<BucketRecord>(
            predicate: #Predicate { $0.projectID == projectID }
        )
        return try normalizedRecordStore.fetch(descriptor)
    }

    func invoiceRecords(for projectID: WorkspaceProject.ID) throws -> [InvoiceRecord] {
        let descriptor = FetchDescriptor<InvoiceRecord>(
            predicate: #Predicate { $0.projectID == projectID }
        )
        return try normalizedRecordStore.fetch(descriptor)
    }

    func timeEntryRecords(for bucketID: WorkspaceBucket.ID) throws -> [TimeEntryRecord] {
        let descriptor = FetchDescriptor<TimeEntryRecord>(
            predicate: #Predicate { $0.bucketID == bucketID }
        )
        return try normalizedRecordStore.fetch(descriptor)
    }

    func fixedCostRecords(for bucketID: WorkspaceBucket.ID) throws -> [FixedCostRecord] {
        let descriptor = FetchDescriptor<FixedCostRecord>(
            predicate: #Predicate { $0.bucketID == bucketID }
        )
        return try normalizedRecordStore.fetch(descriptor)
    }

    func invoiceLineItemRecords(for invoiceID: WorkspaceInvoice.ID) throws -> [InvoiceLineItemRecord] {
        let descriptor = FetchDescriptor<InvoiceLineItemRecord>(
            predicate: #Predicate { $0.invoiceID == invoiceID }
        )
        return try normalizedRecordStore.fetch(descriptor)
    }
}
