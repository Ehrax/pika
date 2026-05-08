import SwiftUI

struct ProjectCard: View {
    var project: WorkspaceProject
    var currentDate: Date
    var totalAmount: String
    var readyAmount: String

    private var overdueInvoiceCount: Int {
        project.overdueInvoiceCount(on: currentDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(BillbiTypography.subheading)
                        .foregroundStyle(BillbiColor.textPrimary)
                    Text(project.clientName)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                    Text("\(project.bucketCount) buckets")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BillbiColor.textMuted)
                }

                Spacer()

                StatusBadge(project.isArchived ? .neutral : .success, title: project.isArchived ? "Archived" : "Active")
            }

            HStack(spacing: BillbiSpacing.sm) {
                BillbiCountPill(value: project.openBucketCount, label: "Open")
                BillbiCountPill(value: project.readyBucketCount, label: "Ready", tone: .success)
                BillbiCountPill(value: project.finalizedBucketCount, label: "Invoiced", tone: .warning)

                if overdueInvoiceCount > 0 {
                    BillbiCountPill(value: overdueInvoiceCount, label: "Overdue", tone: .danger)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                Text(totalAmount)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                Text("total billed + open")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textMuted)
            }

            cardFooter
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
        .padding(BillbiSpacing.md)
        .billbiSurface()
    }

    @ViewBuilder
    private var cardFooter: some View {
        if project.readyToInvoiceMinorUnits > 0 {
            footerStrip(
                tone: .success,
                title: "Ready",
                detail: "\(project.readyBucketCount) ready · \(readyAmount)"
            )
        } else if overdueInvoiceCount > 0 {
            footerStrip(
                tone: .danger,
                title: "Overdue",
                detail: "\(overdueInvoiceCount) invoice needs attention"
            )
        } else {
            footerStrip(tone: .neutral, title: "", detail: "")
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private func footerStrip(tone: BillbiStatusTone, title: String, detail: String) -> some View {
        HStack(spacing: BillbiSpacing.sm) {
            StatusBadge(tone, title: title)
            Text(detail)
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textPrimary)
            Spacer()
        }
        .padding(BillbiSpacing.sm)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md))
    }
}
