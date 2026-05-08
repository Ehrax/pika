import SwiftUI

struct OnboardingStepForm<Content: View, Preview: View>: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let previewEyebrow: LocalizedStringKey
    let previewTitle: LocalizedStringKey
    let errorMessage: String?
    let content: Content
    let preview: Preview

    init(
        eyebrow: LocalizedStringKey,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        previewEyebrow: LocalizedStringKey,
        previewTitle: LocalizedStringKey,
        errorMessage: String?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder preview: () -> Preview
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.previewEyebrow = previewEyebrow
        self.previewTitle = previewTitle
        self.errorMessage = errorMessage
        self.content = content()
        self.preview = preview()
    }

    var body: some View {
        OnboardingFixedSplit(leadingMinimumWidth: 560) {
            ScrollView {
                VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                    Text(eyebrow)
                        .font(BillbiTypography.micro)
                        .foregroundStyle(BillbiColor.brand)
                    Text(title)
                        .font(BillbiTypography.display)
                        .foregroundStyle(BillbiColor.textPrimary)
                    Text(subtitle)
                        .font(BillbiTypography.body)
                        .foregroundStyle(BillbiColor.textSecondary)
                    content
                    if let errorMessage {
                        Text(errorMessage)
                            .font(BillbiTypography.small)
                            .foregroundStyle(BillbiColor.danger)
                    }
                }
                .padding(BillbiSpacing.xl)
            }
            .frame(minWidth: 560)
        } preview: {
            OnboardingPreviewPanel(eyebrow: previewEyebrow, title: previewTitle) {
                preview
            }
        }
    }
}

struct OnboardingPreviewPanel<Content: View>: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let content: Content

    init(
        eyebrow: LocalizedStringKey,
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            Text(eyebrow)
                .font(BillbiTypography.micro)
                .foregroundStyle(BillbiColor.textSecondary)
            Text(title)
                .font(BillbiTypography.heading)
                .foregroundStyle(BillbiColor.textPrimary)

            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(BillbiSpacing.xl)
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BillbiColor.surfaceAlt)
    }
}
