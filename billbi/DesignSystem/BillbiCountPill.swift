import SwiftUI

struct BillbiCountPill: View {
    var value: Int
    var label: String
    var tone: BillbiStatusTone

    init(
        value: Int,
        label: String,
        tone: BillbiStatusTone = .neutral
    ) {
        self.value = value
        self.label = label
        self.tone = tone
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(BillbiTypography.small)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, BillbiSpacing.xs)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
    }
}
