import SwiftUI

struct InvoiceListColumn: View {
    let rows: [WorkspaceInvoiceRowProjection]
    let summary: InvoiceListSummary
    @Binding var filter: InvoiceListFilter
    let selectedInvoiceID: WorkspaceInvoice.ID?
    let onSelect: (WorkspaceInvoice.ID) -> Void

    var body: some View {
        BillbiSecondarySidebarColumn(
            title: "Invoices",
            subtitle: summary.displayText,
            sectionTitle: filter.sectionTitle,
            wrapsContentInScrollView: false
        ) {
            EmptyView()
        } controls: {
            FlowingInvoiceFilters(filter: $filter)
        } content: {
            VStack(spacing: 0) {
                Divider()
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No Invoices",
                        systemImage: "doc.text",
                        description: Text("No invoices match this status.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .foregroundStyle(BillbiColor.textSecondary)
                    .padding(.top, BillbiSpacing.md)
                } else {
                    invoiceList
                        .padding(.top, BillbiSpacing.md)
                }
            }
        }
    }

    private var invoiceList: some View {
        List {
            ForEach(rows) { row in
                Button {
                    onSelect(row.id)
                } label: {
                    InvoiceRow(row: row, isSelected: row.id == selectedInvoiceID)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: BillbiSpacing.sm, bottom: 1, trailing: BillbiSpacing.sm))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BillbiColor.surface)
    }
}

private struct FlowingInvoiceFilters: View {
    @Binding var filter: InvoiceListFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(InvoiceListFilter.allCases) { option in
                    BillbiFilterChip(
                        title: option.displayTitle,
                        isSelected: filter == option,
                        action: { filter = option }
                    )
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InvoiceRow: View {
    let row: WorkspaceInvoiceRowProjection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: row.statusIconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.number)
                    .font(BillbiTypography.body.monospacedDigit().weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(row.clientName)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
                    .lineLimit(1)
                Text(row.bucketName)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)

            VStack(alignment: .trailing, spacing: 5) {
                Text(row.totalLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                StatusBadge(row.statusTone, title: row.statusTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: isSelected)
    }
}

private extension WorkspaceInvoiceRowProjection {
    var statusTone: BillbiStatusTone {
        InvoiceWorkflowPolicy.statusTone(status: status, isOverdue: isOverdue)
    }

    var statusIconName: String {
        InvoiceWorkflowPolicy.statusIconName(status: status, isOverdue: isOverdue)
    }
}
