import SwiftUI
import Charts

struct MetricChartView: View {
    let summary: MetricSummary
    var showAxes: Bool = true
    var height: CGFloat = 140

    var body: some View {
        Chart(summary.dataPoints, id: \.id) { point in
            if summary.metricType.aggregationMethod == .sum {
                BarMark(
                    x: .value("Date", point.date, unit: summary.period.bucketComponent),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(summary.metricType.accentColor)
            } else {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(summary.metricType.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: summary.metricType.accentColor.opacity(0.3), location: 0),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(showAxes ? .visible : .hidden)
        .chartYAxis(showAxes ? .visible : .hidden)
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(dateLabel(date, period: summary.period))
                            .font(.caption2)
                            .foregroundColor(FormaColors.subtext)
                    }
                }
                AxisTick(stroke: StrokeStyle(lineWidth: 0))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(FormaColors.muted.opacity(0.2))

                if let doubleValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatAxisValue(doubleValue, metric: summary.metricType))
                            .font(.caption2)
                            .foregroundColor(FormaColors.subtext)
                    }
                }
            }
        }
        .chartBackground { chartBackground in
            ZStack {
                Color(uiColor: .clear)
                    .background(FormaColors.card)

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FormaColors.muted.opacity(0.1))
                        .frame(height: 0.5)
                }
            }
        }
        .frame(height: height)
        .padding(.horizontal, 12)
        .animation(.easeInOut(duration: 0.3), value: summary.dataPoints)
    }

    private func dateLabel(_ date: Date, period: TimePeriod) -> String {
        let formatter = DateFormatter()

        switch period {
        case .day:
            formatter.dateFormat = "h a"
        case .week:
            formatter.dateFormat = "EEE"
        case .month:
            formatter.dateFormat = "d"
        case .year:
            formatter.dateFormat = "MMM"
        case .allTime:
            formatter.dateFormat = "MMM yyyy"
        }

        return formatter.string(from: date)
    }

    private func formatAxisValue(_ value: Double, metric: HealthMetricType) -> String {
        let rounded = Double(Int(value))

        switch metric {
        case .heartRate, .restingHeartRate, .respiratoryRate:
            return "\(Int(rounded))"
        case .sleepDuration:
            return String(format: "%.1fh", value)
        case .distance:
            return String(format: "%.1f km", value)
        case .activeEnergy:
            return String(format: "%.0f kcal", value)
        case .oxygenSaturation:
            return String(format: "%.0f%%", value)
        default:
            return "\(Int(rounded))"
        }
    }
}

struct MetricMiniChart: View {
    let summary: MetricSummary
    var height: CGFloat = 50

    var body: some View {
        Chart(summary.dataPoints, id: \.id) { point in
            if summary.metricType.aggregationMethod == .sum {
                BarMark(
                    x: .value("Date", point.date, unit: summary.period.bucketComponent),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(summary.metricType.accentColor)
            } else {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(summary.metricType.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: summary.metricType.accentColor.opacity(0.2), location: 0),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: height)
        .animation(.easeInOut(duration: 0.3), value: summary.dataPoints)
    }
}

#Preview {
    let mockDataPoints = [
        AggregatedDataPoint(date: Date().addingTimeInterval(-6 * 24 * 3600), value: 8250),
        AggregatedDataPoint(date: Date().addingTimeInterval(-5 * 24 * 3600), value: 9120),
        AggregatedDataPoint(date: Date().addingTimeInterval(-4 * 24 * 3600), value: 7890),
        AggregatedDataPoint(date: Date().addingTimeInterval(-3 * 24 * 3600), value: 10450),
        AggregatedDataPoint(date: Date().addingTimeInterval(-2 * 24 * 3600), value: 8975),
        AggregatedDataPoint(date: Date().addingTimeInterval(-1 * 24 * 3600), value: 9650),
        AggregatedDataPoint(date: Date(), value: 11200)
    ]

    let mockSummary = MetricSummary(
        metricType: .steps,
        period: .week,
        current: 11200,
        average: 9504,
        minimum: 7890,
        maximum: 11200,
        total: 66529,
        dataPoints: mockDataPoints,
        percentChange: 12.5,
        trend: .up
    )

    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Chart")
                .font(.headline)
                .foregroundColor(FormaColors.textPrimary)

            MetricChartView(summary: mockSummary, showAxes: true, height: 200)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Mini Chart")
                .font(.headline)
                .foregroundColor(FormaColors.textPrimary)

            MetricMiniChart(summary: mockSummary, height: 50)
        }
    }
    .padding()
    .background(FormaColors.background)
}
