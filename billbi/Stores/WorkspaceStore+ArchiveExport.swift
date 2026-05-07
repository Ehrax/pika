import Foundation
import SwiftData

extension WorkspaceStore {
    func workspaceArchiveEnvelope(
        exportedAt: Date = .now,
        generator: WorkspaceArchiveGenerator? = nil
    ) throws -> WorkspaceArchiveEnvelope {
        if isUsingNormalizedWorkspacePersistence() {
            return try normalizedWorkspaceArchiveEnvelope(exportedAt: exportedAt, generator: generator)
        }

        return snapshotWorkspaceArchiveEnvelope(exportedAt: exportedAt, generator: generator)
    }

    private func normalizedWorkspaceArchiveEnvelope(
        exportedAt: Date,
        generator: WorkspaceArchiveGenerator?
    ) throws -> WorkspaceArchiveEnvelope {
        let context = workspacePersistenceModelContext()
        let profileRecords = try context.fetch(FetchDescriptor<BusinessProfileRecord>())
        let clientRecords = try context.fetch(FetchDescriptor<ClientRecord>())
        let projectRecords = try context.fetch(FetchDescriptor<ProjectRecord>())
        let bucketRecords = try context.fetch(FetchDescriptor<BucketRecord>())
        let timeEntryRecords = try context.fetch(FetchDescriptor<TimeEntryRecord>())
        let fixedCostRecords = try context.fetch(FetchDescriptor<FixedCostRecord>())
        let invoiceRecords = try context.fetch(FetchDescriptor<InvoiceRecord>())
        let invoiceLineItemRecords = try context.fetch(FetchDescriptor<InvoiceLineItemRecord>())

        guard let profileRecord = latestArchiveBusinessProfileRecord(in: profileRecords) else {
            throw WorkspaceStoreError.persistenceFailed
        }

        return WorkspaceArchiveEnvelope.v1(
            exportedAt: exportedAt,
            generator: generator,
            workspace: WorkspaceArchiveV1Workspace(
                onboardingCompleted: profileRecord.onboardingCompleted,
                businessProfile: WorkspaceArchiveV1Workspace.BusinessProfile(
                    businessName: profileRecord.businessName,
                    personName: profileRecord.personName,
                    email: profileRecord.email,
                    phone: profileRecord.phone,
                    address: profileRecord.address,
                    taxIdentifier: profileRecord.taxIdentifier,
                    economicIdentifier: profileRecord.economicIdentifier,
                    invoicePrefix: profileRecord.invoicePrefix,
                    nextInvoiceNumber: profileRecord.nextInvoiceNumber,
                    currencyCode: profileRecord.currencyCode,
                    paymentDetails: profileRecord.paymentDetails,
                    taxNote: profileRecord.taxNote,
                    defaultTermsDays: profileRecord.defaultTermsDays
                ),
                clients: sortedForArchive(clientRecords).map { record in
                    WorkspaceArchiveV1Workspace.Client(
                        id: record.id,
                        name: record.name,
                        email: record.email,
                        billingAddress: record.billingAddress,
                        defaultTermsDays: record.defaultTermsDays,
                        isArchived: record.isArchived
                    )
                },
                projects: sortedForArchive(projectRecords).map { record in
                    WorkspaceArchiveV1Workspace.Project(
                        id: record.id,
                        clientID: record.clientID,
                        name: record.name,
                        currencyCode: record.currencyCode,
                        isArchived: record.isArchived
                    )
                },
                buckets: sortedForArchive(bucketRecords).map { record in
                    WorkspaceArchiveV1Workspace.Bucket(
                        id: record.id,
                        projectID: record.projectID,
                        name: record.name,
                        status: Self.archiveStatus(record.status),
                        defaultHourlyRateMinorUnits: record.defaultHourlyRateMinorUnits
                    )
                },
                timeEntries: sortedForArchive(timeEntryRecords).map { record in
                    WorkspaceArchiveV1Workspace.TimeEntry(
                        id: record.id,
                        bucketID: record.bucketID,
                        date: Self.archiveDateString(from: record.workDate),
                        startMinuteOfDay: record.startMinuteOfDay,
                        endMinuteOfDay: record.endMinuteOfDay,
                        durationMinutes: record.durationMinutes,
                        description: record.descriptionText,
                        isBillable: record.isBillable,
                        hourlyRateMinorUnits: record.hourlyRateMinorUnits
                    )
                },
                fixedCosts: sortedForArchive(fixedCostRecords).map { record in
                    WorkspaceArchiveV1Workspace.FixedCost(
                        id: record.id,
                        bucketID: record.bucketID,
                        date: Self.archiveDateString(from: record.date),
                        description: record.descriptionText,
                        amountMinorUnits: record.quantity * record.unitPriceMinorUnits
                    )
                },
                invoices: sortedForArchive(invoiceRecords).map { record in
                    WorkspaceArchiveV1Workspace.Invoice(
                        id: record.id,
                        projectID: record.projectID,
                        bucketID: record.bucketID,
                        number: record.number,
                        businessSnapshot: WorkspaceArchiveV1Workspace.BusinessSnapshot(
                            businessName: record.businessName,
                            personName: record.businessPersonName,
                            email: record.businessEmail,
                            phone: record.businessPhone,
                            address: record.businessAddress,
                            taxIdentifier: record.businessTaxIdentifier,
                            economicIdentifier: record.businessEconomicIdentifier,
                            paymentDetails: record.businessPaymentDetails,
                            taxNote: record.businessTaxNote
                        ),
                        clientSnapshot: WorkspaceArchiveV1Workspace.ClientSnapshot(
                            name: record.clientName,
                            email: record.clientEmail,
                            billingAddress: record.clientBillingAddress
                        ),
                        template: record.template.rawValue,
                        issueDate: Self.archiveDateString(from: record.issueDate),
                        dueDate: Self.archiveDateString(from: record.dueDate),
                        servicePeriod: record.servicePeriod,
                        status: Self.archiveStatus(record.status),
                        totalMinorUnits: record.totalMinorUnits,
                        currencyCode: record.currencyCode,
                        note: Self.nilIfEmpty(record.note)
                    )
                },
                invoiceLineItems: sortedForArchive(invoiceLineItemRecords).map { record in
                    WorkspaceArchiveV1Workspace.InvoiceLineItem(
                        id: record.id,
                        invoiceID: record.invoiceID,
                        sortOrder: record.sortOrder,
                        description: record.descriptionText,
                        quantityLabel: record.quantityLabel,
                        amountMinorUnits: record.amountMinorUnits
                    )
                }
            )
        )
    }

    private func snapshotWorkspaceArchiveEnvelope(
        exportedAt: Date,
        generator: WorkspaceArchiveGenerator?
    ) -> WorkspaceArchiveEnvelope {
        let snapshot = workspace
        let clientIDByName = snapshot.clients.reduce(into: [String: WorkspaceClient.ID]()) { result, client in
            result[client.name] = result[client.name] ?? client.id
        }

        let projects = snapshot.projects.map { project in
            WorkspaceArchiveV1Workspace.Project(
                id: project.id,
                clientID: project.clientID ?? clientIDByName[project.clientName] ?? project.id,
                name: project.name,
                currencyCode: project.currencyCode,
                isArchived: project.isArchived
            )
        }

        let buckets = snapshot.projects.flatMap { project in
            project.buckets.map { bucket in
                WorkspaceArchiveV1Workspace.Bucket(
                    id: bucket.id,
                    projectID: project.id,
                    name: bucket.name,
                    status: Self.archiveStatus(bucket.status),
                    defaultHourlyRateMinorUnits: bucket.hourlyRateMinorUnits ?? 0
                )
            }
        }

        let timeEntries = snapshot.projects.flatMap { project in
            project.buckets.flatMap { bucket in
                bucket.timeEntries.map { entry in
                    WorkspaceArchiveV1Workspace.TimeEntry(
                        id: entry.id,
                        bucketID: bucket.id,
                        date: Self.archiveDateString(from: entry.date),
                        startMinuteOfDay: Self.minuteOfDay(entry.startTime),
                        endMinuteOfDay: Self.minuteOfDay(entry.endTime),
                        durationMinutes: entry.durationMinutes,
                        description: entry.description,
                        isBillable: entry.isBillable,
                        hourlyRateMinorUnits: entry.hourlyRateMinorUnits
                    )
                }
            }
        }

        let fixedCosts = snapshot.projects.flatMap { project in
            project.buckets.flatMap { bucket in
                bucket.fixedCostEntries.map { entry in
                    WorkspaceArchiveV1Workspace.FixedCost(
                        id: entry.id,
                        bucketID: bucket.id,
                        date: Self.archiveDateString(from: entry.date),
                        description: entry.description,
                        amountMinorUnits: entry.amountMinorUnits
                    )
                }
            }
        }

        let invoices = snapshot.projects.flatMap { project in
            project.invoices.map { invoice in
                let projectID = invoice.projectID ?? project.id
                let bucketID = invoice.bucketID ?? project.buckets.first?.id ?? UUID()
                let business = invoice.businessSnapshot ?? snapshot.businessProfile
                let client = invoice.clientSnapshot ?? snapshot.clients.firstMatching(id: invoice.clientID, name: invoice.clientName)

                return WorkspaceArchiveV1Workspace.Invoice(
                    id: invoice.id,
                    projectID: projectID,
                    bucketID: bucketID,
                    number: invoice.number,
                    businessSnapshot: WorkspaceArchiveV1Workspace.BusinessSnapshot(
                        businessName: business.businessName,
                        personName: business.personName,
                        email: business.email,
                        phone: business.phone,
                        address: business.address,
                        taxIdentifier: business.taxIdentifier,
                        economicIdentifier: business.economicIdentifier,
                        paymentDetails: business.paymentDetails,
                        taxNote: business.taxNote
                    ),
                    clientSnapshot: WorkspaceArchiveV1Workspace.ClientSnapshot(
                        name: client?.name ?? invoice.clientName,
                        email: client?.email ?? "",
                        billingAddress: client?.billingAddress ?? ""
                    ),
                    template: invoice.template.rawValue,
                    issueDate: Self.archiveDateString(from: invoice.issueDate),
                    dueDate: Self.archiveDateString(from: invoice.dueDate),
                    servicePeriod: invoice.servicePeriod,
                    status: Self.archiveStatus(invoice.status),
                    totalMinorUnits: invoice.totalMinorUnits,
                    currencyCode: invoice.currencyCode,
                    note: invoice.note
                )
            }
        }

        let lineItems = invoices.flatMap { invoice in
            let sourceInvoice = snapshot.projects
                .flatMap(\.invoices)
                .first(where: { $0.id == invoice.id })

            return (sourceInvoice?.lineItems ?? []).enumerated().map { index, lineItem in
                WorkspaceArchiveV1Workspace.InvoiceLineItem(
                    id: lineItem.id,
                    invoiceID: invoice.id,
                    sortOrder: index,
                    description: lineItem.description,
                    quantityLabel: lineItem.quantityLabel,
                    amountMinorUnits: lineItem.amountMinorUnits
                )
            }
        }

        return WorkspaceArchiveEnvelope.v1(
            exportedAt: exportedAt,
            generator: generator,
            workspace: WorkspaceArchiveV1Workspace(
                onboardingCompleted: snapshot.onboardingCompleted,
                businessProfile: WorkspaceArchiveV1Workspace.BusinessProfile(
                    businessName: snapshot.businessProfile.businessName,
                    personName: snapshot.businessProfile.personName,
                    email: snapshot.businessProfile.email,
                    phone: snapshot.businessProfile.phone,
                    address: snapshot.businessProfile.address,
                    taxIdentifier: snapshot.businessProfile.taxIdentifier,
                    economicIdentifier: snapshot.businessProfile.economicIdentifier,
                    invoicePrefix: snapshot.businessProfile.invoicePrefix,
                    nextInvoiceNumber: snapshot.businessProfile.nextInvoiceNumber,
                    currencyCode: snapshot.businessProfile.currencyCode,
                    paymentDetails: snapshot.businessProfile.paymentDetails,
                    taxNote: snapshot.businessProfile.taxNote,
                    defaultTermsDays: snapshot.businessProfile.defaultTermsDays
                ),
                clients: snapshot.clients.map { client in
                    WorkspaceArchiveV1Workspace.Client(
                        id: client.id,
                        name: client.name,
                        email: client.email,
                        billingAddress: client.billingAddress,
                        defaultTermsDays: client.defaultTermsDays,
                        isArchived: client.isArchived
                    )
                },
                projects: projects,
                buckets: buckets,
                timeEntries: timeEntries,
                fixedCosts: fixedCosts,
                invoices: invoices,
                invoiceLineItems: lineItems
            )
        )
    }

    private func latestArchiveBusinessProfileRecord(in records: [BusinessProfileRecord]) -> BusinessProfileRecord? {
        records.max {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt < $1.updatedAt
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func sortedForArchive<Record: ArchiveSortableRecord>(_ records: [Record]) -> [Record] {
        records.sorted { left, right in
            if left.createdAt != right.createdAt {
                return left.createdAt < right.createdAt
            }
            if left.updatedAt != right.updatedAt {
                return left.updatedAt < right.updatedAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func archiveStatus(_ status: BucketStatus) -> WorkspaceArchiveBucketStatus {
        switch status {
        case .open:
            return .open
        case .ready:
            return .ready
        case .finalized:
            return .finalized
        case .archived:
            return .archived
        }
    }

    private static func archiveStatus(_ status: InvoiceStatus) -> WorkspaceArchiveInvoiceStatus {
        switch status {
        case .finalized:
            return .finalized
        case .sent:
            return .sent
        case .paid:
            return .paid
        case .cancelled:
            return .cancelled
        }
    }

    private static func archiveDateString(from date: Date) -> String {
        WorkspaceArchiveDateCoding.dateOnlyString(from: date)
    }

    private static func nilIfEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private static func minuteOfDay(_ label: String) -> Int? {
        let segments = label.split(separator: ":")
        guard segments.count == 2,
              let hour = Int(segments[0]),
              let minute = Int(segments[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }

        return (hour * 60) + minute
    }
}

private protocol ArchiveSortableRecord {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

extension ClientRecord: ArchiveSortableRecord {}
extension ProjectRecord: ArchiveSortableRecord {}
extension BucketRecord: ArchiveSortableRecord {}
extension TimeEntryRecord: ArchiveSortableRecord {}
extension FixedCostRecord: ArchiveSortableRecord {}
extension InvoiceRecord: ArchiveSortableRecord {}
extension InvoiceLineItemRecord: ArchiveSortableRecord {}
