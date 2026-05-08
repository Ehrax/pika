import SwiftUI

struct OnboardingBusinessStep: View {
    @Binding var businessDraft: OnboardingBusinessDraft
    let errorMessage: String?
    let onSubmit: () -> Void

    var body: some View {
        OnboardingStepForm(
            eyebrow: "STEP 02 · BUSINESS",
            title: "Set your business identity",
            subtitle: "A business name is enough for now. These details become the default sender on future invoices.",
            previewEyebrow: "LIVE PREVIEW",
            previewTitle: "How your invoice header will look",
            errorMessage: errorMessage
        ) {
            VStack(alignment: .leading, spacing: BillbiSpacing.xl) {
                OnboardingFormSection("Business profile") {
                    labeledTextField("Business name", text: $businessDraft.businessName)
                    labeledTextField("Legal name", text: $businessDraft.personName)
                    labeledTextField("Address", text: $businessDraft.address)
                    labeledTextField("Email on invoices", text: $businessDraft.email)
                    labeledTextField("Phone", text: $businessDraft.phone)
                }

                OnboardingFormSection("Invoice defaults") {
                    labeledTextField("Tax ID / VAT no.", text: $businessDraft.taxIdentifier)
                    labeledTextField("Invoice prefix", text: $businessDraft.invoicePrefix, prompt: "PREVIEW")
                    labeledIntegerField("Payment terms", value: $businessDraft.defaultTermsDays, prompt: "14")
                }

                OnboardingFormSection("Bank account") {
                    labeledTextField("Account name", text: paymentAccountNameBinding)
                    labeledTextField("IBAN", text: paymentIBANBinding)
                    labeledTextField("BIC", text: paymentBICBinding)
                }
            }
        } preview: {
            OnboardingBusinessInvoiceHeaderPreview(businessDraft: businessDraft)
        }
    }

    private var paymentAccountNameBinding: Binding<String> {
        paymentDetailsBinding(
            get: \.accountName,
            set: { components, value in components.accountName = value }
        )
    }

    private var paymentIBANBinding: Binding<String> {
        paymentDetailsBinding(
            get: \.iban,
            set: { components, value in components.iban = value }
        )
    }

    private var paymentBICBinding: Binding<String> {
        paymentDetailsBinding(
            get: \.bic,
            set: { components, value in components.bic = value }
        )
    }

    private func paymentDetailsBinding(
        get: @escaping (PaymentDetailsComponents) -> String,
        set: @escaping (inout PaymentDetailsComponents, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: {
                get(PaymentDetailsComponents(rawValue: businessDraft.paymentDetails))
            },
            set: { newValue in
                var components = PaymentDetailsComponents(rawValue: businessDraft.paymentDetails)
                set(&components, newValue)
                businessDraft.paymentDetails = components.rawValue
            }
        )
    }

    private func labeledTextField(_ title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey = "") -> some View {
        OnboardingLabeledTextField(title, text: text, prompt: prompt, onSubmit: onSubmit)
    }

    private func labeledIntegerField(_ title: LocalizedStringKey, value: Binding<Int>, prompt: String? = nil) -> some View {
        OnboardingLabeledIntegerField(title, value: value, prompt: prompt, onSubmit: onSubmit)
    }
}
