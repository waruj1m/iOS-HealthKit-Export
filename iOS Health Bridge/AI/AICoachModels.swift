import Foundation

enum AIChatMessageRole: String, Codable {
    case user
    case assistant
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: AIChatMessageRole
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: AIChatMessageRole,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct AICoachPromptSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let prompt: String

    static let defaults: [AICoachPromptSuggestion] = [
        .init(
            title: "Recovery check",
            prompt: "Based on my recent data, how does my recovery look and what should I watch today?"
        ),
        .init(
            title: "Training load",
            prompt: "How has my training load looked this week and what would be a sensible next session?"
        ),
        .init(
            title: "Sleep review",
            prompt: "Summarize my sleep trend and tell me the most practical change to improve recovery."
        ),
        .init(
            title: "Habit focus",
            prompt: "What is the single highest-impact habit I should focus on next based on my current patterns?"
        )
    ]
}

struct AICoachMetricSnapshot: Codable, Equatable {
    let metric: String
    let unit: String
    let headline: String
    let average: String
    let range: String
    let trend: String
    let percentChange: String?
}

struct AICoachInsightSnapshot: Codable, Equatable {
    let title: String
    let body: String
    let severity: String
    let category: String
}

struct AICoachContextSnapshot: Codable, Equatable {
    let generatedAt: Date
    let measurementSystem: String
    let disclaimer: String
    let weeklyMetrics: [AICoachMetricSnapshot]
    let monthlyMetrics: [AICoachMetricSnapshot]
    let weeklyInsights: [AICoachInsightSnapshot]
    let monthlyInsights: [AICoachInsightSnapshot]

    static func make(
        measurementSystem: MeasurementSystem,
        weeklySummaries: [MetricSummary],
        monthlySummaries: [MetricSummary],
        weeklyInsights: [HealthInsight],
        monthlyInsights: [HealthInsight]
    ) -> AICoachContextSnapshot {
        AICoachContextSnapshot(
            generatedAt: .now,
            measurementSystem: measurementSystem.rawValue,
            disclaimer: "Health coaching only. Never diagnose, prescribe, or present medical advice.",
            weeklyMetrics: weeklySummaries.map {
                AICoachMetricSnapshot(summary: $0, measurementSystem: measurementSystem)
            },
            monthlyMetrics: monthlySummaries.map {
                AICoachMetricSnapshot(summary: $0, measurementSystem: measurementSystem)
            },
            weeklyInsights: weeklyInsights.map(AICoachInsightSnapshot.init),
            monthlyInsights: monthlyInsights.map(AICoachInsightSnapshot.init)
        )
    }
}

extension AICoachMetricSnapshot {
    nonisolated init(summary: MetricSummary, measurementSystem: MeasurementSystem) {
        self.metric = summary.metricType.rawValue
        self.unit = summary.metricType.displayUnit(for: measurementSystem)
        self.headline = summary.formattedDisplay(measurementSystem: measurementSystem)
        self.average = summary.formatted(summary.average, measurementSystem: measurementSystem)
        self.range = "\(summary.formatted(summary.minimum, measurementSystem: measurementSystem))-\(summary.formatted(summary.maximum, measurementSystem: measurementSystem))"
        self.trend = {
            switch summary.trend {
            case .up: return "up"
            case .down: return "down"
            case .flat: return "flat"
            case .insufficient: return "insufficient"
            }
        }()
        self.percentChange = summary.percentChange.map { String(format: "%.0f%%", $0) }
    }
}

extension AICoachInsightSnapshot {
    nonisolated init(insight: HealthInsight) {
        self.title = insight.title
        self.body = insight.body
        self.severity = {
            switch insight.severity {
            case .positive: return "positive"
            case .info: return "info"
            case .warning: return "warning"
            case .negative: return "negative"
            }
        }()
        self.category = insight.category.rawValue
    }
}
