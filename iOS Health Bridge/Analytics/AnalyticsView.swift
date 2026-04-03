import SwiftUI

struct AnalyticsView: View {
    var healthManager: HealthDataManager
    @Environment(MeasurementSettings.self) private var measurementSettings
    @State private var dataService: AnalyticsDataService
    @State private var selectedPeriod: TimePeriod = .week
    @State private var summaries: [MetricSummary] = []
    @State private var isLoading = false
    @State private var selectedMetric: HealthMetricType? = nil
    @State private var showDetailSheet = false

    init(healthManager: HealthDataManager) {
        self.healthManager = healthManager
        _dataService = State(initialValue: AnalyticsDataService(healthStore: healthManager.healthStore))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Period Picker - Sticky
                        VStack {
                            PeriodPicker(selected: $selectedPeriod)
                        }
                        .background(FormaColors.background)
                        .zIndex(1)

                        // Featured Chart
                        featuredChartSection

                        // Summary Cards Grid
                        summaryCardsGrid

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(FormaColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task(id: selectedPeriod) {
                await loadSummaries()
            }
            .sheet(isPresented: $showDetailSheet) {
                if let selectedMetric = selectedMetric,
                   let summary = summaries.first(where: { $0.metricType == selectedMetric }) {
                    MetricDetailSheet(
                        metricType: selectedMetric,
                        period: selectedPeriod,
                        initialSummary: summary,
                        healthManager: healthManager
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var featuredChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overview")
                    .font(.headline)
                    .foregroundColor(FormaColors.textPrimary)

                Spacer()

                Menu {
                    ForEach(HealthMetricType.allCases, id: \.self) { metric in
                        Button(action: { selectedMetric = metric }) {
                            HStack {
                                Image(systemName: metric.sfSymbol)
                                Text(metric.rawValue.capitalized)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Select")
                            .font(.caption)
                    }
                    .foregroundColor(FormaColors.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(FormaColors.card)
                    .cornerRadius(6)
                }
            }

            if let selectedMetric = selectedMetric,
               let summary = summaries.first(where: { $0.metricType == selectedMetric }) {
                MetricChartView(
                    summary: summary,
                    measurementSystem: measurementSettings.measurementSystem,
                    showAxes: true,
                    height: 220
                )
                .onTapGesture {
                    showDetailSheet = true
                }
            } else if isLoading {
                ShimmerView()
                    .frame(height: 220)
            } else {
                MetricChartView(
                    summary: summaries.first(where: { $0.metricType == .steps }) ?? mockSummary,
                    measurementSystem: measurementSettings.measurementSystem,
                    showAxes: true,
                    height: 220
                )
                .onTapGesture {
                    selectedMetric = .steps
                    showDetailSheet = true
                }
            }
        }
        .padding(14)
        .background(FormaColors.card)
        .cornerRadius(12)
    }

    private var summaryCardsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metrics")
                .font(.headline)
                .foregroundColor(FormaColors.textPrimary)
                .padding(.horizontal, 4)

            if isLoading {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        ShimmerView()
                            .frame(height: 140)
                            .cornerRadius(12)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(summaries, id: \.metricType) { summary in
                        MetricSummaryCard(
                            summary: summary,
                            onTap: {
                                selectedMetric = summary.metricType
                                showDetailSheet = true
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadSummaries() async {
        isLoading = true
        defer { isLoading = false }

        let newSummaries = await dataService.fetchAllSummaries(period: selectedPeriod)
        summaries = newSummaries

        if selectedMetric == nil && !newSummaries.isEmpty {
            selectedMetric = .steps
        }
    }

    private var mockSummary: MetricSummary {
        let mockData = [
            AggregatedDataPoint(date: Date().addingTimeInterval(-6 * 24 * 3600), value: 8250),
            AggregatedDataPoint(date: Date().addingTimeInterval(-5 * 24 * 3600), value: 9120),
            AggregatedDataPoint(date: Date().addingTimeInterval(-4 * 24 * 3600), value: 7890),
            AggregatedDataPoint(date: Date().addingTimeInterval(-3 * 24 * 3600), value: 10450),
            AggregatedDataPoint(date: Date().addingTimeInterval(-2 * 24 * 3600), value: 8975),
            AggregatedDataPoint(date: Date().addingTimeInterval(-1 * 24 * 3600), value: 9650),
            AggregatedDataPoint(date: Date(), value: 11200)
        ]

        return MetricSummary(
            metricType: .steps,
            period: selectedPeriod,
            current: 11200,
            average: 9504,
            minimum: 7890,
            maximum: 11200,
            total: 66529,
            dataPoints: mockData,
            percentChange: 12.5,
            trend: .up
        )
    }
}

// MARK: - MetricSummaryCard

struct MetricSummaryCard: View {
    let summary: MetricSummary
    let onTap: () -> Void
    @Environment(MeasurementSettings.self) private var measurementSettings
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Top Row: Icon, Name, Trend
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: summary.metricType.sfSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(summary.metricType.accentColor)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.metricType.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(FormaColors.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    TrendArrow(direction: summary.trend, isPositive: summary.isTrendPositive, percent: summary.percentChange)
                        .frame(width: 20, height: 20)
                }

                // Middle: Large Display Value
                HStack(alignment: .bottom, spacing: 4) {
                    Text(summary.formattedDisplay(measurementSystem: measurementSettings.measurementSystem))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(FormaColors.textPrimary)
                        .lineLimit(1)

                    Text(summary.metricType.displayUnit(for: measurementSettings.measurementSystem))
                        .font(.caption)
                        .foregroundColor(FormaColors.subtext)
                        .padding(.bottom, 2)
                }

                // Bottom: Trend Percentage and Mini Chart
                if let percentChange = summary.percentChange {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 3) {
                                Image(systemName: summary.isTrendPositive ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(String(format: "%.1f%%", abs(percentChange)))
                                    .font(.caption)
                            }
                            .foregroundColor(summary.isTrendPositive ? FormaColors.green : FormaColors.orange)

                            Text("vs last period")
                                .font(.caption2)
                                .foregroundColor(FormaColors.subtext)
                        }

                        Spacer()

                        MetricMiniChart(summary: summary, height: 40)
                    }
                } else {
                    MetricMiniChart(summary: summary, height: 40)
                }

                Spacer()
                    .frame(height: 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(FormaColors.card)
            .cornerRadius(12)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.01, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
    }
}

// MARK: - MetricDetailSheet

struct MetricDetailSheet: View {
    let metricType: HealthMetricType
    let period: TimePeriod
    let healthManager: HealthDataManager

    @Environment(\.dismiss) var dismiss
    @Environment(MeasurementSettings.self) private var measurementSettings
    @State private var dataService: AnalyticsDataService
    @State private var summary: MetricSummary
    @State private var referenceDate = Date()

    init(metricType: HealthMetricType, period: TimePeriod, initialSummary: MetricSummary, healthManager: HealthDataManager) {
        self.metricType = metricType
        self.period = period
        self.healthManager = healthManager
        _summary = State(initialValue: initialSummary)
        _dataService = State(initialValue: AnalyticsDataService(healthStore: healthManager.healthStore))
    }

    var body: some View {
        ZStack {
            FormaColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: metricType.sfSymbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(metricType.accentColor)

                            Text(metricType.rawValue.capitalized)
                                .font(.headline)
                                .foregroundColor(FormaColors.textPrimary)
                        }

                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundColor(FormaColors.subtext)
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(FormaColors.muted)
                    }
                }
                .padding(16)
                .background(FormaColors.surface)

                ScrollView {
                    VStack(spacing: 16) {
                        MetricChartView(
                            summary: summary,
                            measurementSystem: measurementSettings.measurementSystem,
                            showAxes: true,
                            height: 240
                        )
                        .padding(12)
                        .background(FormaColors.card)
                        .cornerRadius(12)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatBox(
                                label: "Average",
                                value: summary.formatted(summary.average, measurementSystem: measurementSettings.measurementSystem),
                                unit: metricType.displayUnit(for: measurementSettings.measurementSystem)
                            )

                            StatBox(
                                label: "Minimum",
                                value: summary.formatted(summary.minimum, measurementSystem: measurementSettings.measurementSystem),
                                unit: metricType.displayUnit(for: measurementSettings.measurementSystem)
                            )

                            StatBox(
                                label: "Maximum",
                                value: summary.formatted(summary.maximum, measurementSystem: measurementSettings.measurementSystem),
                                unit: metricType.displayUnit(for: measurementSettings.measurementSystem)
                            )
                        }

                        if let percentChange = summary.percentChange {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Period Comparison")
                                    .font(.headline)
                                    .foregroundColor(FormaColors.textPrimary)

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Current Average")
                                            .font(.caption)
                                            .foregroundColor(FormaColors.subtext)

                                        HStack(spacing: 6) {
                                            Text(summary.formatted(summary.average, measurementSystem: measurementSettings.measurementSystem))
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(FormaColors.textPrimary)

                                            Text(metricType.displayUnit(for: measurementSettings.measurementSystem))
                                                .font(.caption)
                                                .foregroundColor(FormaColors.subtext)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Change")
                                            .font(.caption)
                                            .foregroundColor(FormaColors.subtext)

                                        HStack(spacing: 4) {
                                            Image(systemName: summary.isTrendPositive ? "arrow.up" : "arrow.down")
                                                .font(.system(size: 12, weight: .semibold))

                                            Text(String(format: "%.1f%%", abs(percentChange)))
                                                .font(.system(size: 18, weight: .semibold))
                                        }
                                        .foregroundColor(summary.isTrendPositive ? FormaColors.green : FormaColors.orange)
                                    }
                                }
                                .padding(12)
                                .background(FormaColors.card)
                                .cornerRadius(10)
                            }
                        }

                        if !summary.dataPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Data Points")
                                    .font(.headline)
                                    .foregroundColor(FormaColors.textPrimary)

                                VStack(spacing: 1) {
                                    ForEach(summary.dataPoints.reversed(), id: \.id) { point in
                                        HStack(spacing: 12) {
                                            Text(dateFormatter.string(from: point.date))
                                                .font(.caption)
                                                .foregroundColor(FormaColors.subtext)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            HStack(spacing: 4) {
                                                Text(summary.formatted(point.value, measurementSystem: measurementSettings.measurementSystem))
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundColor(FormaColors.textPrimary)

                                                Text(metricType.displayUnit(for: measurementSettings.measurementSystem))
                                                    .font(.caption2)
                                                    .foregroundColor(FormaColors.subtext)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(FormaColors.card)

                                        if point.id != summary.dataPoints.last?.id {
                                            Divider()
                                                .background(FormaColors.muted.opacity(0.2))
                                        }
                                    }
                                }
                                .cornerRadius(10)
                                .clipped()
                            }
                        }

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await loadSummary()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { gesture in
                    guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                    if gesture.translation.width < -60 {
                        shiftReferenceDate(by: 1)
                    } else if gesture.translation.width > 60 {
                        shiftReferenceDate(by: -1)
                    }
                }
        )
    }

    private var headerSubtitle: String {
        "\(period.rawValue) • \(intervalFormatter.string(from: summary.dataPoints.first?.date ?? referenceDate, to: summary.dataPoints.last?.date ?? referenceDate))"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var intervalFormatter: DateIntervalFormatter {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private func shiftReferenceDate(by periods: Int) {
        let candidate = period.shiftedEndDate(relativeTo: referenceDate, by: periods)
        referenceDate = min(candidate, Date())

        Task {
            await loadSummary()
        }
    }

    private func loadSummary() async {
        if let updatedSummary = await dataService.fetchSummary(for: metricType, period: period, endingAt: referenceDate) {
            summary = updatedSummary
        }
    }
}

// MARK: - StatBox

struct StatBox: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(FormaColors.subtext)

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(FormaColors.textPrimary)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(FormaColors.subtext)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(FormaColors.card)
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView(healthManager: HealthDataManager())
        .environment(MeasurementSettings())
}
