import SwiftUI

struct MetricTile: View {
    var title: String
    var value: String
    var tone: BillbiStatusTone

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            HStack {
                Text(title)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
                Spacer()
                Circle()
                    .fill(tone.color)
                    .frame(width: 7, height: 7)
            }

            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(BillbiColor.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(BillbiSpacing.md)
        .billbiSurface()
    }
}
