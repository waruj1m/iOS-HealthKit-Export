import Foundation
import HealthKit

struct AICoachContextBuilder {
    let healthStore: HKHealthStore
    let trendEngine: TrendEngine

    init(
        healthStore: HKHealthStore,
        trendEngine: TrendEngine = TrendEngine()
    ) {
        self.healthStore = healthStore
        self.trendEngine = trendEngine
    }

    func build(measurementSystem: MeasurementSystem) async -> AICoachContextSnapshot {
        let dataService = AnalyticsDataService(healthStore: healthStore)
        let weeklySummaries = await dataService.fetchAllSummaries(period: .week)
        let monthlySummaries = await dataService.fetchAllSummaries(period: .month)
        let weeklyInsights = trendEngine.generateInsights(from: weeklySummaries, period: .week)
        let monthlyInsights = trendEngine.generateInsights(from: monthlySummaries, period: .month)

        return AICoachContextSnapshot.make(
            measurementSystem: measurementSystem,
            weeklySummaries: weeklySummaries,
            monthlySummaries: monthlySummaries,
            weeklyInsights: Array(weeklyInsights.prefix(5)),
            monthlyInsights: Array(monthlyInsights.prefix(5))
        )
    }
}
