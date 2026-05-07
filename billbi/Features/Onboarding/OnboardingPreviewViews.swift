import SwiftUI

struct OnboardingBusinessInvoiceHeaderPreview: View {
    let businessDraft: OnboardingBusinessDraft

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? "Your business")
                        .font(BillbiTypography.heading)
                    Text(businessDraft.personName)
                        .font(BillbiTypography.small)
                        .foregroundStyle(Color.gray)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Invoice").font(BillbiTypography.heading.weight(.bold))
                    Text("PREVIEW-001").font(BillbiTypography.small.monospaced())
                }
            }
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("FROM").font(BillbiTypography.micro).foregroundStyle(Color.gray)
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? "Your business")
                    Text(businessDraft.address)
                    Text(businessDraft.taxIdentifier)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("TERMS").font(BillbiTypography.micro).foregroundStyle(Color.gray)
                    Text("Net \(businessDraft.defaultTermsDays)")
                    Text("\(businessDraft.currencyCode) \(businessDraft.defaultHourlyRateMinorUnits / 100)/h")
                }
            }
            Text("line items appear after time is logged...")
                .foregroundStyle(Color.gray)
        }
        .padding(BillbiSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .foregroundStyle(Color.black)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: BillbiRadius.lg)
                .stroke(Color.black.opacity(0.12))
        }
    }
}

struct OnboardingClientListPreview: View {
    let clientDraft: OnboardingClientDraft
    let workspace: WorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clients").font(BillbiTypography.heading)
                Spacer()
                Text(clientDraft.name.nilIfTrimmedEmpty == nil ? "0 clients" : "1 client")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
            .padding(BillbiSpacing.md)
            Divider()

            ClientRow(client: previewClient, isSelected: false)
                .padding(.horizontal, BillbiSpacing.sm)
                .padding(.vertical, BillbiSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(BillbiColor.surface, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }

    private var previewClient: WorkspaceClient {
        WorkspaceClient(
            id: PreviewFixture.sampleClientID,
            name: clientDraft.name.nilIfTrimmedEmpty ?? "Your first client",
            email: clientDraft.email.nilIfTrimmedEmpty ?? "billing details later",
            billingAddress: clientDraft.billingAddress,
            defaultTermsDays: workspace.businessProfile.defaultTermsDays,
            isArchived: false
        )
    }
}

struct OnboardingWelcomeInvoicePreview: View {
    let currentDate: Date
#if os(macOS)
    @StateObject private var previewState = InvoiceHTMLPreviewState()
#endif

    var body: some View {
#if os(macOS)
        let row = sampleInvoiceRow
        if let rendered = try? InvoicePDFService.placeholder().renderInvoiceHTML(profile: sampleInvoiceProfile, row: row) {
            MacInvoiceHTMLDocumentView(
                rendered: rendered,
                invoiceID: row.id,
                state: previewState
            )
            .frame(maxWidth: .infinity, minHeight: 680, maxHeight: .infinity, alignment: .top)
            .background(Color.white, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.lg)
                    .stroke(BillbiColor.border)
            }
        } else {
            ContentUnavailableView(
                "Preview unavailable",
                systemImage: "doc.richtext",
                description: Text("The sample invoice could not be rendered.")
            )
        }
#else
        OnboardingBusinessInvoiceHeaderPreview(businessDraft: .init())
#endif
    }

    private var sampleInvoiceProfile: BusinessProfileProjection {
        BusinessProfileProjection(
            businessName: "Billbi Studio",
            personName: "Alex Morgan",
            email: "hello@billbi.example",
            phone: "+41 31 555 01 80",
            address: "Aarstrasse 18\n3005 Bern\nSwitzerland",
            taxIdentifier: "CHE-123.456.789 MWST",
            invoicePrefix: "PREVIEW",
            nextInvoiceNumber: 1,
            currencyCode: "EUR",
            paymentDetails: "IBAN CH93 0076 2011 6238 5295 7",
            taxNote: "Reverse charge may apply where required.",
            defaultTermsDays: 14
        )
    }

    private var sampleInvoiceRow: WorkspaceInvoiceRowProjection {
        let invoice = WorkspaceInvoice(
            id: PreviewFixture.sampleInvoiceID,
            number: "PREVIEW-001",
            businessSnapshot: sampleInvoiceProfile,
            clientSnapshot: WorkspaceClient(
                id: PreviewFixture.sampleClientID,
                name: "Northwind Labs",
                email: "billing@northwind.example",
                billingAddress: "42 Harbor Road\nDublin 2\nIreland",
                defaultTermsDays: 14
            ),
            clientID: PreviewFixture.sampleClientID,
            clientName: "Northwind Labs",
            projectID: PreviewFixture.sampleProjectID,
            projectName: "Website retainer",
            bucketID: PreviewFixture.sampleBucketID,
            bucketName: "Design sprint",
            issueDate: Date.billbiDate(year: 2026, month: 5, day: 7),
            dueDate: Date.billbiDate(year: 2026, month: 5, day: 21),
            servicePeriod: "May 2026",
            status: .finalized,
            totalMinorUnits: 218_000,
            lineItems: [
                WorkspaceInvoiceLineItemSnapshot(
                    id: PreviewFixture.sampleLineItemAID,
                    description: "Discovery workshop and scope refinement",
                    quantityLabel: "6.0 h",
                    amountMinorUnits: 48_000
                ),
                WorkspaceInvoiceLineItemSnapshot(
                    id: PreviewFixture.sampleLineItemBID,
                    description: "Interface design sprint",
                    quantityLabel: "18.5 h",
                    amountMinorUnits: 148_000
                ),
                WorkspaceInvoiceLineItemSnapshot(
                    id: PreviewFixture.sampleLineItemCID,
                    description: "Prototype review package",
                    quantityLabel: "1 item",
                    amountMinorUnits: 22_000
                ),
            ],
            currencyCode: "EUR",
            note: "Thank you for the continued collaboration."
        )

        return WorkspaceInvoiceRowProjection(
            invoice: invoice,
            projectName: "Website retainer",
            billingAddress: "42 Harbor Road\nDublin 2\nIreland",
            on: currentDate,
            formatter: MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        )
    }
}

struct OnboardingProjectPreview: View {
    let projectDraft: OnboardingProjectDraft
    let selectedClientName: String
    let workspace: WorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(projectDraft.name.nilIfTrimmedEmpty ?? "First project")
                        .font(BillbiTypography.subheading)
                        .foregroundStyle(BillbiColor.textPrimary)
                    Text(selectedClientName)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                    Text("1 bucket")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BillbiColor.textMuted)
                }

                Spacer()

                StatusBadge(.success, title: "Active")
            }

            HStack(spacing: BillbiSpacing.sm) {
                projectCountPill(value: 1, label: "Open")
                projectCountPill(value: 0, label: "Ready", tone: .success)
                projectCountPill(value: 0, label: "Invoiced", tone: .warning)
            }

            Divider()

            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                Text(projectPreviewTotalAmount)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                Text("total billed + open")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textMuted)
            }

            bucketRow
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
        .padding(BillbiSpacing.md)
        .billbiSurface()
    }

    private var projectPreviewTotalAmount: String {
        let currencyCode = projectDraft.currencyCode.nilIfTrimmedEmpty
            ?? workspace.businessProfile.currencyCode
        guard currencyCode == "EUR" else {
            return "\(currencyCode) 0.00"
        }
        return MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
            .string(fromMinorUnits: 0)
    }

    private var bucketRow: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: "diamond")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(projectDraft.firstBucketName.nilIfTrimmedEmpty ?? "General")
                    .font(BillbiTypography.body)
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text("0.0 h · \(projectPreviewTotalAmount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)

            StatusBadge(.neutral, title: "Open")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: false)
    }

    private func projectCountPill(
        value: Int,
        label: String,
        tone: BillbiStatusTone = .neutral
    ) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(BillbiTypography.small)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, BillbiSpacing.xs)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
    }
}

private enum PreviewFixture {
    static let sampleInvoiceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let sampleClientID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let sampleProjectID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let sampleBucketID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let sampleLineItemAID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let sampleLineItemBID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    static let sampleLineItemCID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
}
