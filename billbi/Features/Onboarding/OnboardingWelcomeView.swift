import SwiftUI

struct OnboardingWelcomeView<Preview: View>: View {
    let onStart: () -> Void
    let onSkip: () -> Void
    let preview: Preview

    init(
        onStart: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview
    ) {
        self.onStart = onStart
        self.onSkip = onSkip
        self.preview = preview()
    }

    var body: some View {
        OnboardingFixedSplit(leadingMinimumWidth: 520) {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                Text("Welcome to Billbi")
                    .font(BillbiTypography.subheading)
                    .foregroundStyle(BillbiColor.brand)
                Text("Start with the parts every invoice needs.")
                    .font(BillbiTypography.display)
                    .foregroundStyle(BillbiColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Add your business, one client, and a starter project. Billbi keeps the setup light, and you can fill the rest in later.")
                    .font(BillbiTypography.body)
                    .foregroundStyle(BillbiColor.textSecondary)
                    .lineSpacing(3)

                VStack(spacing: BillbiSpacing.sm) {
                    OnboardingSetupRow("01", title: "Business basics", detail: "name, currency, default rate")
                    OnboardingSetupRow("02", title: "First client", detail: "a real client, with details optional")
                    OnboardingSetupRow("03", title: "Starter project", detail: "one bucket so work has a place")
                }

                Text("About five minutes. Skip any detail you do not have yet.")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)

                Spacer()

                HStack(spacing: BillbiSpacing.lg) {
                    Spacer(minLength: BillbiSpacing.xl)

                    Button {
                        onSkip()
                    } label: {
                        Text("Skip setup")
                    }
                    .buttonStyle(.plain)
                    .font(BillbiTypography.subheading.weight(.semibold))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .accessibilityIdentifier("Skip setup")

                    Button {
                        onStart()
                    } label: {
                        Label("Start setup", systemImage: "arrow.right")
                    }
                    .buttonStyle(.billbiAction(.primary, size: .large))
                    .accessibilityIdentifier("Continue")
                }
            }
            .padding(BillbiSpacing.xl)
            .frame(minWidth: 520)
        } preview: {
            OnboardingPreviewPanel(
                eyebrow: "PREVIEW",
                title: "A workspace for time, projects, and invoices"
            ) {
                preview
            }
        }
    }
}

private struct OnboardingSetupRow: View {
    let number: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    init(_ number: String, title: LocalizedStringKey, detail: LocalizedStringKey) {
        self.number = number
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: BillbiSpacing.md) {
            Text(number)
                .font(BillbiTypography.body.monospacedDigit())
                .foregroundStyle(BillbiColor.textSecondary)
            VStack(alignment: .leading) {
                Text(title)
                    .font(BillbiTypography.subheading)
                    .foregroundStyle(BillbiColor.textPrimary)
                Text(detail)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
            Spacer()
        }
        .padding(BillbiSpacing.md)
        .background(BillbiColor.surface, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }
}
