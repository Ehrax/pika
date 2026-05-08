import SwiftUI

struct OnboardingClientStep: View {
    @Binding var clientDraft: OnboardingClientDraft
    let workspace: WorkspaceSnapshot
    let errorMessage: String?
    let onSubmit: () -> Void

    var body: some View {
        OnboardingStepForm(
            eyebrow: "STEP 03 · FIRST CLIENT",
            title: "Add your first client",
            subtitle: "A client name creates the record. Email, contact, and billing details can wait until invoice review.",
            previewEyebrow: "CLIENTS",
            previewTitle: "Where your client list will live",
            errorMessage: errorMessage
        ) {
            VStack(alignment: .leading, spacing: BillbiSpacing.xl) {
                OnboardingFormSection("Client profile") {
                    labeledTextField("Client name", text: $clientDraft.name)
                    labeledTextField("VAT no.", text: $clientDraft.vatNumber)
                }

                OnboardingFormSection("Contact") {
                    labeledTextField("Contact email", text: $clientDraft.email)
                    labeledTextField("Contact person", text: $clientDraft.contactPerson)
                    labeledTextField("Phone", text: $clientDraft.phone)
                }

                OnboardingFormSection("Billing") {
                    labeledTextField("Billing address", text: $clientDraft.billingAddress)
                }
            }
        } preview: {
            OnboardingClientListPreview(
                clientDraft: clientDraft,
                workspace: workspace
            )
        }
    }

    private func labeledTextField(_ title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey = "") -> some View {
        OnboardingLabeledTextField(title, text: text, prompt: prompt, onSubmit: onSubmit)
    }
}
