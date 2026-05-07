import SwiftUI

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

enum OnboardingFormLayout {
    static let labelWidth: CGFloat = 180
}
