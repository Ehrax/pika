import SwiftUI

struct OnboardingBusinessInvoiceHeaderPreview: View {
    let businessDraft: OnboardingBusinessDraft

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? String(localized: "Your business"))
                        .font(BillbiTypography.heading)
                    Text(businessDraft.personName)
                        .font(BillbiTypography.small)
                        .foregroundStyle(Color.gray)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Invoice").font(BillbiTypography.heading.weight(.bold))
                    Text(previewInvoiceNumber).font(BillbiTypography.small.monospaced())
                }
            }
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("FROM").font(BillbiTypography.micro).foregroundStyle(Color.gray)
                    Text(businessDraft.businessName.nilIfTrimmedEmpty ?? String(localized: "Your business"))
                    Text(businessDraft.address)
                    Text(businessDraft.taxIdentifier)
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

    private var previewInvoiceNumber: String {
        let prefix = businessDraft.invoicePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPrefix = prefix.isEmpty ? "PREVIEW" : prefix.uppercased()
        return "\(normalizedPrefix)-001"
    }
}

struct OnboardingClientListPreview: View {
    let clientDraft: OnboardingClientDraft
    let workspace: WorkspaceSnapshot

    var body: some View {
        OnboardingMiniAppFrame {
            HStack(spacing: 0) {
                OnboardingMiniPrimarySidebar(
                    selection: .clients,
                    projectName: nil
                )
                .frame(width: 118)

                Divider()

                clientListColumn
                    .frame(width: 186)

                Divider()

                clientDetailSurface
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var previewClient: WorkspaceClient {
        WorkspaceClient(
            id: PreviewFixture.sampleClientID,
            name: clientDraft.name.nilIfTrimmedEmpty ?? String(localized: "Your first client"),
            email: clientDraft.email.nilIfTrimmedEmpty ?? String(localized: "billing details later"),
            billingAddress: clientDraft.billingAddress,
            defaultTermsDays: workspace.businessProfile.defaultTermsDays,
            isArchived: false
        )
    }

    private var clientListColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: BillbiSpacing.sm) {
                Text("Clients")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: BillbiSpacing.xs)

                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BillbiColor.brand)
                    .frame(width: 22, height: 22)
                    .background(BillbiColor.brandMuted, in: Circle())
            }
            .padding(BillbiSpacing.md)

            Divider()

            VStack(spacing: BillbiSpacing.xs) {
                selectedClientRow
                mutedClientRow(
                    name: String(localized: "Project client"),
                    detail: String(localized: "billing details later"),
                    terms: "30d"
                )
                mutedClientRow(
                    name: String(localized: "Later client"),
                    detail: String(localized: "billing details later"),
                    terms: "14d"
                )
            }
            .padding(BillbiSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BillbiColor.surfaceAlt)
    }

    private var selectedClientRow: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: "building.2")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(BillbiColor.textSecondary)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(previewClient.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(previewClient.email)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(previewClient.defaultTermsDays)d")
                .font(.system(size: 8).monospacedDigit())
                .foregroundStyle(BillbiColor.textMuted)
        }
        .padding(.horizontal, BillbiSpacing.sm)
        .frame(height: 34)
        .background(BillbiColor.brandMuted)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(BillbiColor.brand)
                .frame(width: 3)
                .padding(.vertical, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous))
    }

    private func mutedClientRow(name: String, detail: String, terms: String) -> some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: "building.2")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(terms)
                .font(.system(size: 8).monospacedDigit())
                .foregroundStyle(BillbiColor.textMuted)
        }
        .frame(height: 28)
        .opacity(0.54)
    }

    private var clientDetailSurface: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                    Text(previewClient.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BillbiColor.textPrimary)
                        .lineLimit(1)
                    Text(previewClient.email)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(BillbiColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: BillbiSpacing.sm)

                OnboardingMiniStatusBadge(.success, title: String(localized: "Active"))
            }

            clientSummaryCard
            clientInvoicePreview
        }
        .padding(BillbiSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BillbiColor.background)
    }

    private var clientSummaryCard: some View {
        HStack(spacing: BillbiSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Billing address")
                    .font(.system(size: 8, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(BillbiColor.textSecondary)
                Text(clientDraft.billingAddress.nilIfTrimmedEmpty ?? String(localized: "billing details later"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: BillbiSpacing.sm)

            VStack(alignment: .trailing, spacing: 3) {
                Text("Terms")
                    .font(.system(size: 8, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(BillbiColor.textSecondary)
                Text("\(previewClient.defaultTermsDays)d")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(BillbiColor.textPrimary)
            }
        }
        .padding(BillbiSpacing.md)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: BillbiRadius.lg, style: .continuous))
    }

    private var clientInvoicePreview: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            Label("Invoice", systemImage: "doc.text")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(BillbiColor.brand)

            VStack(spacing: 0) {
                HStack {
                    Text(previewClient.name)
                        .font(.system(size: 10, weight: .bold))
                    Spacer()
                    Text("PREVIEW-001")
                        .font(.system(size: 8, weight: .semibold).monospaced())
                        .foregroundStyle(BillbiColor.textMuted)
                }
                .padding(BillbiSpacing.sm)

                Divider()

                VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                    OnboardingMiniSkeleton(width: 92)
                    OnboardingMiniSkeleton(width: 128)
                    OnboardingMiniSkeleton(width: 74)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BillbiSpacing.sm)

                Divider()

                HStack {
                    OnboardingMiniSkeleton(width: 116)
                    Spacer()
                    OnboardingMiniSkeleton(width: 48)
                }
                .padding(BillbiSpacing.sm)
                .background(BillbiColor.brandMuted.opacity(0.52))
            }
            .foregroundStyle(BillbiColor.textPrimary)
            .background(BillbiColor.surfaceAlt, in: RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous)
                    .stroke(BillbiColor.border)
            }
        }
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
        OnboardingMiniAppFrame {
            HStack(spacing: 0) {
                OnboardingMiniPrimarySidebar(
                    selection: .project,
                    projectName: projectName
                )
                .frame(width: 118)

                Divider()

                bucketSidebar
                    .frame(width: 168)

                Divider()

                detailSurface
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var projectPreviewTotalAmount: String {
        let currencyCode = projectDraft.currencyCode.nilIfTrimmedEmpty
            ?? workspace.businessProfile.currencyCode
        let totalMinorUnits = max(projectDraft.hourlyRateMinorUnits, 0) * 10
        guard currencyCode == "EUR" else {
            return moneyLabel(currencyCode: currencyCode, minorUnits: totalMinorUnits)
        }
        return MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
            .string(fromMinorUnits: totalMinorUnits)
    }

    private var projectName: String {
        projectDraft.name.nilIfTrimmedEmpty ?? String(localized: "First project")
    }

    private var bucketName: String {
        projectDraft.firstBucketName.nilIfTrimmedEmpty ?? String(localized: "General")
    }

    private var bucketSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: BillbiSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(projectName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BillbiColor.textPrimary)
                        .lineLimit(1)
                    Text(selectedClientName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(BillbiColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: BillbiSpacing.xs)

                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BillbiColor.brand)
                    .frame(width: 22, height: 22)
                    .background(BillbiColor.brandMuted, in: Circle())
            }
            .padding(BillbiSpacing.md)

            Divider()

            VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                miniMutedBucketRow(name: String(localized: "General"), meta: String(localized: "0.0 h · \(projectPreviewTotalAmount)"))
                selectedBucketRow
            }
            .padding(BillbiSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BillbiColor.surfaceAlt)
    }

    private var selectedBucketRow: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: "diamond")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(BillbiColor.textSecondary)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(bucketName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(String(localized: "10h · \(projectPreviewTotalAmount)"))
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            OnboardingMiniStatusBadge(.success, title: String(localized: "Ready"))
        }
        .padding(.horizontal, BillbiSpacing.sm)
        .frame(height: 34)
        .background(BillbiColor.brandMuted)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(BillbiColor.brand)
                .frame(width: 3)
                .padding(.vertical, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous))
    }

    private func miniMutedBucketRow(name: String, meta: String) -> some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: "diamond")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(meta)
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .opacity(0.62)
    }

    private var detailSurface: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                    Text(bucketName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BillbiColor.textPrimary)
                        .lineLimit(1)
                    Text("\(projectName)  ·  \(selectedClientName)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(BillbiColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: BillbiSpacing.sm)

                Text(projectPreviewTotalAmount)
                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            miniInvoiceSummary
            miniEntriesTable
        }
        .padding(BillbiSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BillbiColor.background)
    }

    private var miniInvoiceSummary: some View {
        HStack(alignment: .center, spacing: BillbiSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Ready to invoice")
                    .font(.system(size: 8, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(BillbiColor.textSecondary)
                Text(projectPreviewTotalAmount)
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(BillbiColor.textPrimary)
                Text(String(localized: "10h · \(projectPreviewTotalAmount)"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(BillbiColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)

            Label("Create Invoice", systemImage: "doc.badge.plus")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(BillbiColor.brand)
                .padding(.horizontal, BillbiSpacing.sm)
                .frame(height: 28)
                .background(BillbiColor.brandMuted)
                .overlay {
                    RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous)
                        .stroke(BillbiColor.brandBorder)
                }
                .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous))
        }
        .padding(BillbiSpacing.md)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: BillbiRadius.lg, style: .continuous))
    }

    private var miniEntriesTable: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            Label("Fixed Charge", systemImage: "plus.square")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(BillbiColor.brand)

            VStack(spacing: 0) {
                HStack {
                    miniTableHeader("Date", width: 42)
                    miniTableHeader("Time", width: 54)
                    miniTableHeader("Description")
                    miniTableHeader("Hrs", width: 32, alignment: .trailing)
                    miniTableHeader("Amount", width: 58, alignment: .trailing)
                }
                .padding(.horizontal, BillbiSpacing.sm)
                .frame(height: 22)
                .background(BillbiColor.surfaceAlt)

                ForEach(0..<4, id: \.self) { index in
                    miniTableSkeletonRow(index: index)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous)
                    .stroke(BillbiColor.border)
            }
        }
    }

    private func miniTableHeader(
        _ title: LocalizedStringKey,
        width: CGFloat? = nil,
        alignment: Alignment = .leading
    ) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(BillbiColor.textMuted)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }

    private func miniTableSkeletonRow(index: Int) -> some View {
        HStack {
            OnboardingMiniSkeleton(width: 30 + CGFloat(index % 2) * 6)
                .frame(width: 42, alignment: .leading)
            OnboardingMiniSkeleton(width: 42)
                .frame(width: 54, alignment: .leading)
            OnboardingMiniSkeleton(width: 82 + CGFloat(index % 3) * 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            OnboardingMiniSkeleton(width: 18)
                .frame(width: 32, alignment: .trailing)
            OnboardingMiniSkeleton(width: 46)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, BillbiSpacing.sm)
        .frame(height: 23)
        .background(index == 3 ? BillbiColor.brandMuted.opacity(0.72) : Color.clear)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BillbiColor.border)
                .frame(height: 1)
        }
    }

    private func moneyLabel(currencyCode: String, minorUnits: Int) -> String {
        let amount = Double(minorUnits) / 100
        return "\(currencyCode) \(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), amount))"
    }
}

private struct OnboardingMiniAppFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 292, maxHeight: 330, alignment: .topLeading)
            .background(BillbiColor.background)
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.xl, style: .continuous)
                    .stroke(BillbiColor.borderStrong)
            }
            .accessibilityElement(children: .combine)
    }
}

private enum OnboardingMiniPrimarySelection {
    case project
    case clients
}

private struct OnboardingMiniPrimarySidebar: View {
    let selection: OnboardingMiniPrimarySelection
    let projectName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Circle().fill(Color.yellow).frame(width: 7, height: 7)
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Spacer()
                Image(systemName: "sidebar.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BillbiColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                Text("Workspace")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(BillbiColor.textMuted)

                navigationRow("Dashboard", systemImage: "gauge")
                projectsDisclosureRow

                if let projectName {
                    projectRow(projectName)
                }

                navigationRow("Invoices", systemImage: "doc.text")
                navigationRow("Clients", systemImage: "person.2", isSelected: selection == .clients)
                navigationRow("Settings", systemImage: "gearshape")
            }
        }
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.top, BillbiSpacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BillbiColor.surface)
    }

    private var projectsDisclosureRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.down")
                .font(.system(size: 6, weight: .bold))
                .frame(width: 8)
            Image(systemName: "folder")
                .font(.system(size: 9, weight: .medium))
                .frame(width: 11)
            Text("Projects")
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(BillbiColor.textPrimary)
        .frame(height: 18)
    }

    private func projectRow(_ title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BillbiColor.projectDotPalette.first ?? BillbiColor.brand)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(BillbiColor.textPrimary)
        .padding(.horizontal, BillbiSpacing.sm)
        .frame(height: 25)
        .background(selection == .project ? BillbiColor.primarySidebarSelection.opacity(0.72) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous))
    }

    private func navigationRow(
        _ title: LocalizedStringKey,
        systemImage: String,
        isSelected: Bool = false
    ) -> some View {
        Label {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .medium))
                .frame(width: 13)
        }
        .foregroundStyle(BillbiColor.textPrimary)
        .padding(.horizontal, isSelected ? BillbiSpacing.sm : 0)
        .frame(height: isSelected ? 25 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? BillbiColor.primarySidebarSelection.opacity(0.72) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md, style: .continuous))
    }
}

private struct OnboardingMiniStatusBadge: View {
    let tone: BillbiStatusTone
    let title: String

    init(_ tone: BillbiStatusTone, title: String) {
        self.tone = tone
        self.title = title
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tone.color)
                .frame(width: 4, height: 4)
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
    }
}

private struct OnboardingMiniSkeleton: View {
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(BillbiColor.textMuted.opacity(0.28))
            .frame(width: width, height: 6)
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
