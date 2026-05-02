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
        let profileRecords = try modelContext.fetch(FetchDescriptor<BusinessProfileRecord>())
        let clientRecords = try modelContext.fetch(FetchDescriptor<ClientRecord>())
        let projectRecords = try modelContext.fetch(FetchDescriptor<ProjectRecord>())
        let bucketRecords = try modelContext.fetch(FetchDescriptor<BucketRecord>())
        let timeEntryRecords = try modelContext.fetch(FetchDescriptor<TimeEntryRecord>())
        let fixedCostRecords = try modelContext.fetch(FetchDescriptor<FixedCostRecord>())
        let invoiceRecords = try modelContext.fetch(FetchDescriptor<InvoiceRecord>())
        let invoiceLineItemRecords = try modelContext.fetch(FetchDescriptor<InvoiceLineItemRecord>())

        guard let profileRecord = latestProfileRecord(in: profileRecords) else {
            throw WorkspaceStoreError.persistenceFailed
        }

        return WorkspaceArchiveEnvelope(
            format: WorkspaceArchiveEnvelope.v1Format,
            version: WorkspaceArchiveEnvelope.v1Version,
            exportedAt: exportedAt,
            generator: generator,
            workspace: WorkspaceArchiveWorkspace(
                businessProfile: WorkspaceArchiveBusinessProfile(
                    id: profileRecord.id,
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
                    WorkspaceArchiveClient(
                        id: record.id,
                        name: record.name,
                        email: record.email,
                        billingAddress: record.billingAddress,
                        defaultTermsDays: record.defaultTermsDays,
                        isArchived: record.isArchived
                    )
                },
                projects: sortedForArchive(projectRecords).map { record in
                    WorkspaceArchiveProject(
                        id: record.id,
                        clientID: record.clientID,
                        name: record.name,
                        currencyCode: record.currencyCode,
                        isArchived: record.isArchived
                    )
                },
                buckets: sortedForArchive(bucketRecords).map { record in
                    WorkspaceArchiveBucket(
                        id: record.id,
                        projectID: record.projectID,
                        name: record.name,
                        status: record.status,
                        defaultHourlyRateMinorUnits: record.defaultHourlyRateMinorUnits
                    )
                },
                timeEntries: sortedForArchive(timeEntryRecords).map { record in
                    WorkspaceArchiveTimeEntry(
                        id: record.id,
                        bucketID: record.bucketID,
                        workDate: record.workDate,
                        startMinuteOfDay: record.startMinuteOfDay,
                        endMinuteOfDay: record.endMinuteOfDay,
                        durationMinutes: record.durationMinutes,
                        description: record.descriptionText,
                        isBillable: record.isBillable,
                        hourlyRateMinorUnits: record.hourlyRateMinorUnits
                    )
                },
                fixedCosts: sortedForArchive(fixedCostRecords).map { record in
                    WorkspaceArchiveFixedCost(
                        id: record.id,
                        bucketID: record.bucketID,
                        date: record.date,
                        description: record.descriptionText,
                        quantity: record.quantity,
                        unitPriceMinorUnits: record.unitPriceMinorUnits,
                        isBillable: record.isBillable
                    )
                },
                invoices: sortedForArchive(invoiceRecords).map { record in
                    WorkspaceArchiveInvoice(
                        id: record.id,
                        projectID: record.projectID,
                        bucketID: record.bucketID,
                        number: record.number,
                        template: record.template,
                        issueDate: record.issueDate,
                        dueDate: record.dueDate,
                        servicePeriod: record.servicePeriod,
                        status: record.status,
                        totalMinorUnits: record.totalMinorUnits,
                        currencyCode: record.currencyCode,
                        note: record.note,
                        businessProfileSnapshot: WorkspaceArchiveBusinessProfileSnapshot(
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
                        clientSnapshot: WorkspaceArchiveClientSnapshot(
                            name: record.clientName,
                            email: record.clientEmail,
                            billingAddress: record.clientBillingAddress
                        ),
                        projectSnapshot: WorkspaceArchiveProjectSnapshot(name: record.projectName),
                        bucketSnapshot: WorkspaceArchiveBucketSnapshot(name: record.bucketName)
                    )
                },
                invoiceLineItems: sortedForArchive(invoiceLineItemRecords).map { record in
                    WorkspaceArchiveInvoiceLineItem(
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
        let clientByName = Dictionary(uniqueKeysWithValues: snapshot.clients.map { ($0.name, $0.id) })
        let fallbackBusinessProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let projects = snapshot.projects.map { project in
            WorkspaceArchiveProject(
                id: project.id,
                clientID: project.clientID ?? clientByName[project.clientName] ?? project.id,
                name: project.name,
                currencyCode: project.currencyCode,
                isArchived: project.isArchived
            )
        }

        let buckets = snapshot.projects.flatMap { project in
            project.buckets.map { bucket in
                WorkspaceArchiveBucket(
                    id: bucket.id,
                    projectID: project.id,
                    name: bucket.name,
                    status: bucket.status,
                    defaultHourlyRateMinorUnits: bucket.hourlyRateMinorUnits ?? 0
                )
            }
        }

        let timeEntries = snapshot.projects.flatMap { project in
            project.buckets.flatMap { bucket in
                bucket.timeEntries.map { entry in
                    WorkspaceArchiveTimeEntry(
                        id: entry.id,
                        bucketID: bucket.id,
                        workDate: entry.date,
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
                    WorkspaceArchiveFixedCost(
                        id: entry.id,
                        bucketID: bucket.id,
                        date: entry.date,
                        description: entry.description,
                        quantity: 1,
                        unitPriceMinorUnits: entry.amountMinorUnits,
                        isBillable: true
                    )
                }
            }
        }

        let invoices = snapshot.projects.flatMap { project in
            project.invoices.map { invoice in
                let business = invoice.businessSnapshot ?? snapshot.businessProfile
                let client = invoice.clientSnapshot ?? snapshot.clients.firstMatching(id: invoice.clientID, name: invoice.clientName)
                let bucketName = invoice.bucketName.isEmpty ? project.buckets.first(where: { $0.id == invoice.bucketID })?.name ?? "" : invoice.bucketName
                return WorkspaceArchiveInvoice(
                    id: invoice.id,
                    projectID: invoice.projectID ?? project.id,
                    bucketID: invoice.bucketID ?? project.buckets.first?.id ?? UUID(),
                    number: invoice.number,
                    template: invoice.template,
                    issueDate: invoice.issueDate,
                    dueDate: invoice.dueDate,
                    servicePeriod: invoice.servicePeriod,
                    status: invoice.status,
                    totalMinorUnits: invoice.totalMinorUnits,
                    currencyCode: invoice.currencyCode,
                    note: invoice.note ?? "",
                    businessProfileSnapshot: WorkspaceArchiveBusinessProfileSnapshot(
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
                    clientSnapshot: WorkspaceArchiveClientSnapshot(
                        name: client?.name ?? invoice.clientName,
                        email: client?.email ?? "",
                        billingAddress: client?.billingAddress ?? ""
                    ),
                    projectSnapshot: WorkspaceArchiveProjectSnapshot(name: invoice.projectName.isEmpty ? project.name : invoice.projectName),
                    bucketSnapshot: WorkspaceArchiveBucketSnapshot(name: bucketName)
                )
            }
        }

        let lineItems = invoices.flatMap { invoice in
            let sourceInvoice = snapshot.projects
                .flatMap(\.invoices)
                .first(where: { $0.id == invoice.id })
            return (sourceInvoice?.lineItems ?? []).enumerated().map { index, lineItem in
                WorkspaceArchiveInvoiceLineItem(
                    id: lineItem.id,
                    invoiceID: invoice.id,
                    sortOrder: index,
                    description: lineItem.description,
                    quantityLabel: lineItem.quantityLabel,
                    amountMinorUnits: lineItem.amountMinorUnits
                )
            }
        }

        return WorkspaceArchiveEnvelope(
            format: WorkspaceArchiveEnvelope.v1Format,
            version: WorkspaceArchiveEnvelope.v1Version,
            exportedAt: exportedAt,
            generator: generator,
            workspace: WorkspaceArchiveWorkspace(
                businessProfile: WorkspaceArchiveBusinessProfile(
                    id: fallbackBusinessProfileID,
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
                    WorkspaceArchiveClient(
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

    private func latestProfileRecord(in records: [BusinessProfileRecord]) -> BusinessProfileRecord? {
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
