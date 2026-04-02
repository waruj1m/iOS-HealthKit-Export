import Foundation
import Testing
@testable import iOS_Health_Bridge

struct iOS_Health_BridgeTests {
    @Test func timePeriodDayStartsAtBeginningOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        let midday = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: 2026,
            month: 4,
            day: 2,
            hour: 14,
            minute: 37
        ))!

        let start = TimePeriod.day.startDate(relativeTo: midday)
        let expected = calendar.startOfDay(for: midday)

        #expect(start == expected)
    }

    @Test func timePeriodWeekAnchorsToStartOfDayBeforeSubtractingWeek() {
        let calendar = Calendar(identifier: .gregorian)
        let midday = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: 2026,
            month: 4,
            day: 2,
            hour: 14,
            minute: 37
        ))!

        let start = TimePeriod.week.startDate(relativeTo: midday)
        let expected = calendar.date(byAdding: .weekOfYear, value: -1, to: calendar.startOfDay(for: midday))!

        #expect(start == expected)
    }

    @Test func oxygenSaturationFormattingUsesWholePercentDisplay() {
        let summary = makeSummary(
            metric: .oxygenSaturation,
            points: [0.97, 0.98, 0.99],
            average: 0.98,
            total: nil
        )

        #expect(summary.formattedDisplay == "98")
    }

    @Test func trendEngineDetectsActiveStepStreak() {
        let engine = TrendEngine()
        let steps = makeSummary(
            metric: .steps,
            points: [6200, 7000, 8100, 9000],
            average: 7575,
            total: 30300
        )

        let insights = engine.generateInsights(from: [steps], period: .week)

        #expect(insights.contains(where: { $0.title.contains("activity streak") }))
    }

    @Test func trendEngineFlagsChronicSleepDebt() {
        let engine = TrendEngine()
        let sleep = makeSummary(
            metric: .sleepDuration,
            points: [5.4, 5.8, 5.6],
            average: 5.6,
            total: nil
        )

        let insights = engine.generateInsights(from: [sleep], period: .week)

        #expect(insights.contains(where: { $0.title == "Chronic sleep debt detected" }))
    }

    @Test func trendEngineDetectsTrainingAndRecoveryAlignment() {
        let engine = TrendEngine()
        let workouts = makeSummary(
            metric: .workoutCount,
            points: [0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
            average: 0.71,
            total: 10
        )
        let sleep = makeSummary(
            metric: .sleepDuration,
            points: [7.2, 7.4, 7.1, 7.3, 7.5, 7.0, 7.4],
            average: 7.27,
            total: nil
        )

        let insights = engine.generateInsights(from: [workouts, sleep], period: .week)

        #expect(insights.contains(where: { $0.title == "Training and recovery in sync" }))
    }

    @Test func trendEngineReturnsUniqueInsightTitles() {
        let engine = TrendEngine()
        let steps = makeSummary(
            metric: .steps,
            points: [8000, 8100, 8200, 8300],
            average: 8150,
            total: 32600
        )
        let sleep = makeSummary(
            metric: .sleepDuration,
            points: [8.0, 8.1, 8.2, 8.0],
            average: 8.08,
            total: nil
        )
        let bodyMass = makeSummary(
            metric: .bodyMass,
            points: [80.0, 79.7, 79.4, 79.1, 78.8],
            average: 79.4,
            total: nil
        )

        let insights = engine.generateInsights(from: [steps, sleep, bodyMass], period: .month)
        let titles = insights.map(\.title)

        #expect(Set(titles).count == titles.count)
    }

    private func makeSummary(
        metric: HealthMetricType,
        points: [Double],
        average: Double,
        total: Double?
    ) -> MetricSummary {
        let dataPoints = points.enumerated().map { index, value in
            AggregatedDataPoint(
                date: Calendar(identifier: .gregorian).date(from: DateComponents(
                    timeZone: .gmt,
                    year: 2026,
                    month: 4,
                    day: index + 1
                ))!,
                value: value
            )
        }

        return MetricSummary(
            metricType: metric,
            period: .week,
            current: dataPoints.last?.value,
            average: average,
            minimum: dataPoints.map(\.value).min() ?? 0,
            maximum: dataPoints.map(\.value).max() ?? 0,
            total: total,
            dataPoints: dataPoints,
            percentChange: nil,
            trend: .flat
        )
    }
}
