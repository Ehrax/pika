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

struct OnboardingSetupRow: View {
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

struct OnboardingLabeledTextField: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var text: String
    let onSubmit: () -> Void

    init(_ title: LocalizedStringKey, text: Binding<String>, prompt: LocalizedStringKey = "", onSubmit: @escaping () -> Void) {
        self.title = title
        self.prompt = prompt
        _text = text
        self.onSubmit = onSubmit
    }

    var body: some View {
        OnboardingFieldRow(title) {
            TextField(prompt, text: $text)
                .textFieldStyle(.billbiInput)
                .onSubmit { onSubmit() }
        }
    }
}

struct OnboardingLabeledNumberField: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let onSubmit: () -> Void

    var body: some View {
        OnboardingFieldRow(title) {
            TextField(title, value: Binding(
                get: { max(value / 100, 0) },
                set: { value = max($0, 0) * 100 }
            ), format: .number)
            .textFieldStyle(.billbiInput)
            .onSubmit { onSubmit() }
        }
    }
}

struct OnboardingLabeledIntegerField: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let suffix: String?
    let onSubmit: () -> Void

    init(_ title: LocalizedStringKey, value: Binding<Int>, suffix: String? = nil, onSubmit: @escaping () -> Void) {
        self.title = title
        _value = value
        self.suffix = suffix
        self.onSubmit = onSubmit
    }

    var body: some View {
        OnboardingFieldRow(title) {
            HStack(spacing: BillbiSpacing.sm) {
                TextField(title, value: Binding(
                    get: { max(value, 0) },
                    set: { value = max($0, 0) }
                ), format: .number)
                .textFieldStyle(.billbiInput)
                .onSubmit { onSubmit() }

                if let suffix {
                    Text(suffix)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                }
            }
        }
    }
}

struct OnboardingFieldRow<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: BillbiSpacing.lg) {
            Text(title)
                .font(BillbiTypography.small.weight(.medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: OnboardingFormLayout.labelWidth, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, BillbiSpacing.xs)
    }
}

struct OnboardingFormSection<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            Text(title)
                .font(BillbiTypography.heading)
                .foregroundStyle(BillbiColor.textPrimary)
            VStack(alignment: .leading, spacing: BillbiSpacing.md) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BillbiSpacing.lg)
            .padding(.vertical, BillbiSpacing.md)
            .background(BillbiColor.surfaceAlt, in: RoundedRectangle(cornerRadius: BillbiRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.lg, style: .continuous)
                    .stroke(BillbiColor.borderStrong, lineWidth: 1)
            }
        }
    }
}

struct OnboardingFixedSplit<Leading: View, Preview: View>: View {
    private static var leadingRatio: CGFloat { 0.42 }

    let leadingMinimumWidth: CGFloat
    let leading: Leading
    let preview: Preview

    init(
        leadingMinimumWidth: CGFloat,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder preview: () -> Preview
    ) {
        self.leadingMinimumWidth = leadingMinimumWidth
        self.leading = leading()
        self.preview = preview()
    }

    var body: some View {
        GeometryReader { proxy in
            let leadingWidth = fixedLeadingWidth(for: proxy.size.width)

            HStack(spacing: 0) {
                leading
                    .frame(width: leadingWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                Divider()

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private func fixedLeadingWidth(for totalWidth: CGFloat) -> CGFloat {
        guard totalWidth > 0 else { return leadingMinimumWidth }

        let centeredWidth = totalWidth * Self.leadingRatio
        let maximumWidth = max(leadingMinimumWidth, totalWidth - 480)
        return min(max(centeredWidth, leadingMinimumWidth), maximumWidth)
    }
}

enum OnboardingFormLayout {
    static let labelWidth: CGFloat = 180
}
