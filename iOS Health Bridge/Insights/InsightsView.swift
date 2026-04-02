//
//  InsightsView.swift
//  Forma
//

import SwiftUI

struct InsightsView: View {
    var healthManager: HealthDataManager

    @State private var dataService   : AnalyticsDataService
    @State private var insights      : [HealthInsight] = []
    @State private var summaries     : [MetricSummary] = []
    @State private var selectedPeriod: TimePeriod = .week
    @State private var isLoading     = false

    @AppStorage("insightsAIDismissed") private var disclaimerDismissed = false

    private let trendEngine = TrendEngine()

    init(healthManager: HealthDataManager) {
        self.healthManager = healthManager
        _dataService = State(initialValue: AnalyticsDataService(healthStore: healthManager.healthStore))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    PeriodPicker(selected: $selectedPeriod)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(FormaColors.surface)

                    if isLoading {
                        loadingState
                    } else if insights.isEmpty {
                        emptyState
                    } else {
                        insightsList
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(FormaColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task(id: selectedPeriod) { await loadInsights() }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    ShimmerView().frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(FormaColors.teal)
            Text("No insights yet")
                .font(.headline.bold())
                .foregroundStyle(FormaColors.textPrimary)
            Text("Keep tracking your metrics and insights will appear here.")
                .font(FormaType.caption())
                .foregroundStyle(FormaColors.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var insightsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Dismissible AI disclaimer
                if !disclaimerDismissed {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(FormaColors.background)
                        Text("Insights are generated from your data patterns and are not medical advice.")
                            .font(FormaType.caption())
                            .foregroundStyle(FormaColors.background)
                        Spacer()
                        Button { disclaimerDismissed = true } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FormaColors.background)
                        }
                    }
                    .padding(12)
                    .background(FormaColors.amber)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Category sections
                ForEach(HealthInsight.Category.allCases, id: \.rawValue) { category in
                    let categoryInsights = insights.filter { $0.category == category }
                    if !categoryInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            FormaSectionHeader(title: category.rawValue.uppercased())
                            ForEach(categoryInsights) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Load

    private func loadInsights() async {
        isLoading = true
        defer { isLoading = false }
        summaries = await dataService.fetchAllSummaries(period: selectedPeriod)
        insights  = trendEngine.generateInsights(from: summaries, period: selectedPeriod)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: HealthInsight
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 12) {
                // Left border accent
                RoundedRectangle(cornerRadius: 2)
                    .fill(insight.severity.color)
                    .frame(width: 3)

                // Severity icon
                ZStack {
                    Circle()
                        .fill(insight.severity.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: insight.severity.sfSymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(insight.severity.color)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title)
                        .font(FormaType.cardTitle())
                        .foregroundStyle(FormaColors.textPrimary)
                        .lineLimit(1)
                    Text(insight.body)
                        .font(FormaType.caption())
                        .foregroundStyle(FormaColors.subtext)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                // Right: category badge + metric icons
                VStack(alignment: .trailing, spacing: 6) {
                    MetricBadge(text: insight.category.rawValue,
                                color: categoryColor(insight.category))
                    HStack(spacing: 4) {
                        ForEach(insight.relatedMetrics.prefix(3), id: \.self) { metric in
                            Image(systemName: metric.sfSymbol)
                                .font(.system(size: 11))
                                .foregroundStyle(metric.accentColor)
                        }
                    }
                }
            }
            .padding(12)
            .background(FormaColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            InsightDetailSheet(insight: insight)
                .presentationDetents([.medium, .large])
        }
    }

    private func categoryColor(_ cat: HealthInsight.Category) -> Color {
        switch cat {
        case .activity:    return FormaColors.orange
        case .recovery:    return FormaColors.teal
        case .trend:       return Color(hex: "0A84FF")
        case .streak:      return FormaColors.green
        case .correlation: return FormaColors.purple
        case .milestone:   return FormaColors.amber
        }
    }
}

// MARK: - Insight Detail Sheet

struct InsightDetailSheet: View {
    let insight: HealthInsight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Severity pill
                        HStack(spacing: 8) {
                            Image(systemName: insight.severity.sfSymbol)
                            Text(insight.severity.label)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(insight.severity.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(insight.severity.color.opacity(0.12))
                        .clipShape(Capsule())

                        // Body
                        Text(insight.body)
                            .font(.body)
                            .foregroundStyle(FormaColors.textPrimary)
                            .lineSpacing(4)

                        // Related metrics
                        if !insight.relatedMetrics.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                FormaSectionHeader(title: "RELATED METRICS")
                                HStack(spacing: 8) {
                                    ForEach(insight.relatedMetrics, id: \.self) { m in
                                        MetricBadge(text: m.rawValue, color: m.accentColor)
                                    }
                                }
                            }
                        }

                        // Timestamp
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text("\(insight.generatedAt, style: .relative) ago")
                        }
                        .font(FormaType.caption())
                        .foregroundStyle(FormaColors.muted)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(insight.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(FormaColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FormaColors.teal)
                }
            }
        }
    }
}

// MARK: - Severity label helper

private extension HealthInsight.Severity {
    var label: String {
        switch self {
        case .positive: return "Positive"
        case .info:     return "Info"
        case .warning:  return "Warning"
        case .negative: return "Negative"
        }
    }
}
