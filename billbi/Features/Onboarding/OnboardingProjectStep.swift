import SwiftUI

struct OnboardingProjectStep: View {
    @Binding var projectDraft: OnboardingProjectDraft
    let selectedClientName: String
    let workspace: WorkspaceSnapshot
    let errorMessage: String?
    let onSubmit: () -> Void

    var body: some View {
        OnboardingStepForm(
            eyebrow: "STEP 04 · FIRST PROJECT",
            title: "Create the first place for work",
            subtitle: "Projects belong to clients. Buckets group the time or costs you will eventually invoice.",
            previewEyebrow: "PREVIEW",
            previewTitle: "What your project will look like",
            errorMessage: errorMessage
        ) {
            VStack(alignment: .leading, spacing: BillbiSpacing.xl) {
                OnboardingFormSection("Project") {
                    selectedClientContext
                    labeledTextField("Project name", text: $projectDraft.name)
                    labeledNumberField("Project rate", value: $projectDraft.hourlyRateMinorUnits)
                }

                OnboardingFormSection("First bucket") {
                    labeledTextField("Bucket name", text: $projectDraft.firstBucketName, prompt: "General")
                    Text("Leave it blank and Billbi will create a General bucket.")
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                }
            }
        } preview: {
            OnboardingProjectPreview(
                projectDraft: projectDraft,
                selectedClientName: selectedClientName,
                workspace: workspace
            )
        }
    }

    private func labeledTextField(_ title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey = "") -> some View {
        OnboardingLabeledTextField(title, text: text, prompt: prompt, onSubmit: onSubmit)
    }

    private func labeledNumberField(_ title: LocalizedStringKey, value: Binding<Int>) -> some View {
        OnboardingLabeledNumberField(title: title, value: value, onSubmit: onSubmit)
    }

    private var selectedClientContext: some View {
        OnboardingFieldRow("Client") {
            Text(selectedClientName)
                .font(BillbiTypography.body)
                .foregroundStyle(BillbiColor.textPrimary)
                .lineLimit(1)
        }
    }
}
