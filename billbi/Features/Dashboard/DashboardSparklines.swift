import SwiftUI

struct RevenueSparkline: View {
    let points: [RevenuePoint]

    var body: some View {
        GeometryReader { proxy in
            let samples = normalizedPoints(in: proxy.size)
            ZStack {
                SparklineArea(points: samples)
                    .fill(
                        LinearGradient(
                            colors: [BillbiColor.brand.opacity(0.28), BillbiColor.brand.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                SparklineLine(points: samples)
                    .stroke(BillbiColor.brand, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = samples.last {
                    Circle()
                        .fill(BillbiColor.brand)
                        .frame(width: 7, height: 7)
                        .position(last)
                }
            }
        }
        .accessibilityLabel("Twelve month revenue sparkline")
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard points.count > 1, let maxAmount = points.map(\.amountMinorUnits).max(), maxAmount > 0 else {
            return []
        }

        let padding: CGFloat = 4
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)
        let step = availableWidth / CGFloat(points.count - 1)

        return points.enumerated().map { index, point in
            let x = padding + CGFloat(index) * step
            let y = padding + (1 - CGFloat(point.amountMinorUnits) / CGFloat(maxAmount)) * availableHeight
            return CGPoint(x: x, y: y)
        }
    }
}

struct ProjectRevenueSparkline: View {
    let points: [ProjectRevenueHistoryPoint]

    var body: some View {
        GeometryReader { proxy in
            let samples = normalizedPoints(in: proxy.size)

            ZStack {
                if samples.isEmpty {
                    Text("No unbilled revenue yet")
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    SparklineArea(points: samples.map(\.point))
                        .fill(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.28), primaryColor.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    SparklineLine(points: samples.map(\.point))
                        .stroke(primaryColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    ForEach(samples) { sample in
                        Circle()
                            .fill(sample.color)
                            .frame(width: 7, height: 7)
                            .position(sample.point)
                    }
                }
            }
        }
        .accessibilityLabel("Unbilled revenue sparkline by project")
    }

    private var primaryColor: Color {
        points.first.map(color(for:)) ?? BillbiColor.brand
    }

    private func normalizedPoints(in size: CGSize) -> [ProjectSparklineSample] {
        guard !points.isEmpty, let maxAmount = points.map(\.amountMinorUnits).max(), maxAmount > 0 else {
            return []
        }

        let padding: CGFloat = 4
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)
        let step = points.count > 1 ? availableWidth / CGFloat(points.count - 1) : availableWidth
        let orderedPoints = points.count > 1 ? points : [
            points[0],
            points[0],
        ]

        return orderedPoints.enumerated().map { index, point in
            let x = points.count > 1 ? padding + CGFloat(index) * step : padding + CGFloat(index) * step
            let y = padding + (1 - CGFloat(point.amountMinorUnits) / CGFloat(maxAmount)) * availableHeight
            return ProjectSparklineSample(id: "\(point.id)-\(index)", point: CGPoint(x: x, y: y), color: color(for: point))
        }
    }

    private func color(for point: ProjectRevenueHistoryPoint) -> Color {
        BillbiColor.projectDotPalette[point.colorIndex % BillbiColor.projectDotPalette.count]
    }
}

private struct ProjectSparklineSample: Identifiable {
    let id: String
    let point: CGPoint
    let color: Color
}

private struct SparklineLine: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct SparklineArea: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = SparklineLine(points: points).path(in: rect)
        guard let first = points.first, let last = points.last else { return path }

        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
