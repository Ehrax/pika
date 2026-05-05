import SwiftUI

struct CreateInvoiceConfirmationSheet: View {
    let presentation: InvoiceDraftPresentation
    let onCancel: () -> Void
    let onSave: (InvoiceFinalizationDraft) -> Bool
    @State private var draft: InvoiceFinalizationDraft
    @State private var isSaving = false

    init(
        presentation: InvoiceDraftPresentation,
        onCancel: @escaping () -> Void,
        onSave: @escaping (InvoiceFinalizationDraft) -> Bool
    ) {
        self.presentation = presentation
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: presentation.draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                    BillbiInputSheetSection(title: "Recipient") {
                        InvoiceFinalizationReviewRow("Name", value: draft.recipientName)
                        BillbiInputSheetDivider()
                        InvoiceFinalizationReviewRow("Email", value: draft.recipientEmail)
                        BillbiInputSheetDivider()
                        InvoiceFinalizationReviewRow("Billing address", value: draft.recipientBillingAddress)
                    }

                    BillbiInputSheetSection(title: "Invoice") {
                        InvoiceFinalizationReviewRow("Invoice number", value: draft.invoiceNumber)
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Template") {
                            Picker("Template", selection: $draft.template) {
                                ForEach(InvoiceTemplate.allCases) { template in
                                    Text(template.displayName).tag(template)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Issue date") {
                            DatePicker("", selection: $draft.issueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                                .controlSize(.regular)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Due date") {
                            DatePicker("", selection: $draft.dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                                .controlSize(.regular)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        BillbiInputSheetDivider()
                        InvoiceFinalizationReviewRow("Service period", value: draft.servicePeriod)
                        BillbiInputSheetDivider()
                        InvoiceFinalizationReviewRow("Currency", value: draft.currencyCode)
                        BillbiInputSheetDivider()
                        InvoiceFinalizationReviewRow("Tax / VAT note", value: draft.taxNote)
                    }

                    BillbiInputSheetSection(title: "Totals") {
                        ForEach(presentation.lineItems) { item in
                            HStack {
                                Text(item.description)
                                Spacer()
                                Text(item.quantity)
                                    .foregroundStyle(BillbiColor.textSecondary)
                                Text(item.amountLabel)
                                    .monospacedDigit()
                                    .frame(width: 120, alignment: .trailing)
                            }
                            .padding(.horizontal, BillbiSpacing.md)
                            .padding(.vertical, BillbiSpacing.sm)
                        }

                        BillbiInputSheetDivider()

                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(presentation.totalLabel)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, BillbiSpacing.md)
                        .padding(.vertical, BillbiSpacing.sm)
                    }
                }
                .padding(BillbiSpacing.md)
            }

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.billbiAction(.destructive))

                Spacer()

                Button {
                    save()
                } label: {
                    Label("Save as finalized", systemImage: "checkmark.circle")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.billbiAction(.primary))
                .disabled(isSaving || draft.invoiceNumber.isEmpty || draft.recipientName.isEmpty)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620)
        .background(BillbiColor.background)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        if !onSave(draft) {
            isSaving = false
        }
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
        BillbiInputSheetFieldRow(label: title, alignment: .top) {
            Text(value.isEmpty ? "Not set" : value)
                .foregroundStyle(value.isEmpty ? BillbiColor.textSecondary : BillbiColor.textPrimary)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
