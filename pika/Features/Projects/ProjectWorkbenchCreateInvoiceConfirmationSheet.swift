import SwiftUI

struct CreateInvoiceConfirmationSheet: View {
    let presentation: InvoiceDraftPresentation
    let onCancel: () -> Void
    let onSave: (InvoiceFinalizationDraft) -> Void
    @State private var draft: InvoiceFinalizationDraft

    init(
        presentation: InvoiceDraftPresentation,
        onCancel: @escaping () -> Void,
        onSave: @escaping (InvoiceFinalizationDraft) -> Void
    ) {
        self.presentation = presentation
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: presentation.draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                    PikaInputSheetSection(title: "Recipient") {
                        InvoiceFinalizationReviewRow("Name", value: draft.recipientName)
                        PikaInputSheetDivider()
                        InvoiceFinalizationReviewRow("Email", value: draft.recipientEmail)
                        PikaInputSheetDivider()
                        InvoiceFinalizationReviewRow("Billing address", value: draft.recipientBillingAddress)
                    }

                    PikaInputSheetSection(title: "Invoice") {
                        InvoiceFinalizationReviewRow("Invoice number", value: draft.invoiceNumber)
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Template") {
                            Picker("Template", selection: $draft.template) {
                                ForEach(InvoiceTemplate.allCases) { template in
                                    Text(template.displayName).tag(template)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Issue date") {
                            DatePicker("", selection: $draft.issueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                                .controlSize(.regular)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Due date") {
                            DatePicker("", selection: $draft.dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                                .controlSize(.regular)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        PikaInputSheetDivider()
                        InvoiceFinalizationReviewRow("Service period", value: draft.servicePeriod)
                        PikaInputSheetDivider()
                        InvoiceFinalizationReviewRow("Currency", value: draft.currencyCode)
                        PikaInputSheetDivider()
                        InvoiceFinalizationReviewRow("Tax / VAT note", value: draft.taxNote)
                    }

                    PikaInputSheetSection(title: "Totals") {
                        ForEach(presentation.lineItems) { item in
                            HStack {
                                Text(item.description)
                                Spacer()
                                Text(item.quantity)
                                    .foregroundStyle(PikaColor.textSecondary)
                                Text(item.amountLabel)
                                    .monospacedDigit()
                                    .frame(width: 120, alignment: .trailing)
                            }
                            .padding(.horizontal, PikaSpacing.md)
                            .padding(.vertical, PikaSpacing.sm)
                        }

                        PikaInputSheetDivider()

                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(presentation.totalLabel)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, PikaSpacing.md)
                        .padding(.vertical, PikaSpacing.sm)
                    }
                }
                .padding(PikaSpacing.md)
            }

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.pikaAction(.destructive))

                Spacer()

                Button {
                    onSave(draft)
                } label: {
                    Label("Save as finalized", systemImage: "checkmark.circle")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(draft.invoiceNumber.isEmpty || draft.recipientName.isEmpty)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620)
        .background(PikaColor.background)
    }
}

private struct InvoiceFinalizationReviewRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        PikaInputSheetFieldRow(label: title, alignment: .top) {
            Text(value.isEmpty ? "Not set" : value)
                .foregroundStyle(value.isEmpty ? PikaColor.textSecondary : PikaColor.textPrimary)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
