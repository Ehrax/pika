import SwiftUI

struct OnboardingHeaderView: View {
    let step: OnboardingStep
    let progressAnimation: Animation?

    var body: some View {
        ZStack {
            progressIndicator

            HStack {
                BillbiWordmark()

                Spacer()

                Text(String(format: "%02d / 05", step.displayIndex))
                    .font(BillbiTypography.small.monospacedDigit())
                    .foregroundStyle(BillbiColor.textSecondary)
            }
        }
        .padding(.horizontal, BillbiSpacing.xl)
        .padding(.vertical, BillbiSpacing.md)
        .background(BillbiColor.surface)
    }

    private var progressIndicator: some View {
        HStack(spacing: BillbiSpacing.xs) {
            ForEach(OnboardingStep.allCases, id: \.self) { candidate in
                Capsule()
                    .fill(candidate == step ? BillbiColor.brand : BillbiColor.surfaceAlt2)
                    .frame(width: candidate == step ? 26 : 7, height: 7)
                    .animation(progressAnimation, value: step)
            }
        }
    }
}

struct OnboardingStepSlideTransitionModifier: ViewModifier {
    let opacity: Double
    let xOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(x: xOffset)
    }
}

private struct BillbiWordmark: View {
    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image("BillbiLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: Layout.iconCornerRadius, style: .continuous))
                .accessibilityHidden(true)

            Text("Billbi")
                .font(BillbiTypography.heading)
                .foregroundStyle(BillbiColor.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Billbi")
    }

    private enum Layout {
        static let iconSize: CGFloat = 36
        static let iconCornerRadius: CGFloat = 12
    }
}
