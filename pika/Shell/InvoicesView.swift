import SwiftUI

struct InvoicesView: View {
    let workspace: WorkspaceSnapshot
    let currentDate: Date
    @State private var selectedInvoiceID: WorkspaceInvoice.ID?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
    private let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)

    private var projection: WorkspaceInvoicePreviewProjection? {
        workspace.invoicePreviewProjection(
            selectedInvoiceID: selectedInvoiceID,
            on: currentDate,
            formatter: formatter
        )
    }

    var body: some View {
        Group {
            if let projection {
                HStack(spacing: 0) {
                    InvoiceMetadataColumn(
                        projection: projection,
                        selectedInvoiceID: selectedInvoiceID ?? projection.selectedInvoice.id,
                        dateStyle: dateStyle,
                        onSelect: { selectedInvoiceID = $0 }
                    )

                    PDFPreviewPlaceholder(
                        profile: workspace.businessProfile,
                        invoice: projection.selectedInvoice,
                        totalLabel: formatter.string(fromMinorUnits: projection.selectedInvoice.totalMinorUnits),
                        dateStyle: dateStyle
                    )
                }
                .onAppear {
                    selectedInvoiceID = selectedInvoiceID ?? projection.selectedInvoice.id
                    AppTelemetry.invoicesLoaded(invoiceCount: projection.rows.count)
                }
            } else {
                ContentUnavailableView(
                    "No Invoices",
                    systemImage: "doc.text",
                    description: Text("Finalize a ready bucket to preview invoices here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PikaColor.background)
        .navigationTitle("Invoices")
        .toolbar {
            Button {
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(true)
            .help("Sharing lands with generated PDFs")

            Button {
            } label: {
                Label("PDF", systemImage: "arrow.down.doc")
            }
            .disabled(true)
            .help("PDF export lands in the invoice workflow")

            Button {
            } label: {
                Label("Mark Sent", systemImage: "paperplane")
            }
            .disabled(true)
            .help("Invoice status actions land in the invoice workflow")
        }
        .accessibilityIdentifier("InvoicesView")
    }
}

private struct InvoiceMetadataColumn: View {
    let projection: WorkspaceInvoicePreviewProjection
    let selectedInvoiceID: WorkspaceInvoice.ID
    let dateStyle: Date.FormatStyle
    let onSelect: (WorkspaceInvoice.ID) -> Void

    private var selectedRow: WorkspaceInvoiceRowProjection {
        projection.rows.first { $0.id == selectedInvoiceID } ?? projection.rows[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    Text("Invoices")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)

                    VStack(spacing: 2) {
                        ForEach(projection.rows) { row in
                            Button {
                                onSelect(row.id)
                            } label: {
                                InvoiceRow(row: row, isSelected: row.id == selectedInvoiceID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()
                    .overlay(PikaColor.border)

                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    Text("Total")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)
                    Text(selectedRow.totalLabel)
                        .font(.system(size: 30, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PikaColor.textPrimary)
                    Text("Due \(selectedRow.dueDate.formatted(dateStyle))")
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textSecondary)
                }

                MetadataList(rows: [
                    ("Number", selectedRow.number),
                    ("Issue date", selectedRow.issueDate.formatted(dateStyle)),
                    ("Due date", selectedRow.dueDate.formatted(dateStyle)),
                    ("Currency", "EUR"),
                    ("Status", selectedRow.statusTitle),
                ])

                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    Text("Recipient")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)
                    Text(selectedRow.clientName)
                        .font(PikaTypography.body.weight(.medium))
                        .foregroundStyle(PikaColor.textPrimary)
                    Text("Billing address snapshot will appear here once invoice finalization writes PDF-ready records.")
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    Text("Activity")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)
                    InvoiceActivityRow(text: "\(selectedRow.statusTitle.lowercased()) invoice selected", detail: "PDF render pending")
                    InvoiceActivityRow(text: "Invoice metadata loaded", detail: selectedRow.number)
                }
            }
            .padding(PikaSpacing.lg)
        }
        .frame(width: 380)
        .frame(maxHeight: .infinity)
        .background(PikaColor.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PikaColor.border)
                .frame(width: 1)
        }
    }
}

private struct InvoiceRow: View {
    let row: WorkspaceInvoiceRowProjection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.number)
                    .font(.body.monospacedDigit().weight(.medium))
                    .foregroundStyle(PikaColor.textPrimary)
                Text(row.clientName)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(row.totalLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(PikaColor.textPrimary)
                StatusBadge(row.isOverdue ? .danger : .neutral, title: row.statusTitle)
            }
        }
        .padding(PikaSpacing.sm)
        .background(isSelected ? PikaColor.surfaceAlt : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? PikaColor.accent : Color.clear)
                .frame(width: 2)
        }
    }
}

private struct MetadataList: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(spacing: PikaSpacing.sm) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .foregroundStyle(PikaColor.textMuted)
                    Spacer()
                    Text(row.1)
                        .foregroundStyle(PikaColor.textPrimary)
                        .monospacedDigit()
                }
                .font(PikaTypography.small)
            }
        }
        .padding(PikaSpacing.md)
        .pikaSurface()
    }
}

private struct InvoiceActivityRow: View {
    let text: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: PikaSpacing.sm) {
            Circle()
                .fill(PikaColor.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textPrimary)
                Text(detail)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textMuted)
            }
        }
    }
}

private struct PDFPreviewPlaceholder: View {
    let profile: BusinessProfileProjection
    let invoice: WorkspaceInvoice
    let totalLabel: String
    let dateStyle: Date.FormatStyle

    var body: some View {
        ScrollView {
            VStack {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: PikaSpacing.md) {
                            HStack(spacing: PikaSpacing.sm) {
                                Text("p")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: PikaRadius.sm))
                                Text(profile.businessName)
                                    .font(.headline.weight(.semibold))
                            }

                            Text("\(profile.address)\n\(profile.email)")
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.35))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: PikaSpacing.xs) {
                            Text("Invoice")
                                .font(.title2.weight(.semibold))
                            Text(invoice.number)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color(white: 0.35))
                        }
                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                            Text("Bill to")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(white: 0.35))
                            Text(invoice.clientName)
                                .font(.body.weight(.medium))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: PikaSpacing.xs) {
                            Text("Issue \(invoice.issueDate.formatted(dateStyle))")
                            Text("Due \(invoice.dueDate.formatted(dateStyle))")
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(white: 0.35))
                    }

                    VStack(spacing: 0) {
                        PDFLine(description: "Invoice line preview", amount: totalLabel)
                        PDFLine(description: "PDF renderer pending", amount: "Included")
                    }

                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: PikaSpacing.xs) {
                            Text("Total")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(white: 0.35))
                            Text(totalLabel)
                                .font(.title2.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .foregroundStyle(Color.black)
                .padding(48)
                .frame(width: 540, alignment: .topLeading)
                .frame(minHeight: 760, alignment: .topLeading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .shadow(color: .black.opacity(0.32), radius: 24, y: 10)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PikaColor.background)
    }
}

private struct PDFLine: View {
    let description: String
    let amount: String

    var body: some View {
        HStack {
            Text(description)
            Spacer()
            Text(amount)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.9))
                .frame(height: 1)
        }
    }
}
