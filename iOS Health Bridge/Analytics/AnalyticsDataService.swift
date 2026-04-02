import Foundation
import HealthKit
import Observation

@Observable final class AnalyticsDataService {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Main API

    func fetchSummary(for metric: HealthMetricType, period: TimePeriod) async -> MetricSummary? {
        let endDate = Date()
        let startDate = period.startDate(relativeTo: endDate)

        let dataPoints = await aggregateHealthData(
            for: metric,
            from: startDate,
            to: endDate,
            bucketComponent: period.bucketComponent
        )

        guard !dataPoints.isEmpty else {
            return nil
        }

        let average = calculateAverage(dataPoints)
        let minimum = dataPoints.map { $0.value }.min() ?? 0
        let maximum = dataPoints.map { $0.value }.max() ?? 0
        let total = metric.aggregationMethod == .sum
            ? dataPoints.map { $0.value }.reduce(0, +)
            : nil

        // Fetch prior period for trend calculation
        let priorEndDate = startDate
        let priorStartDate = period.startDate(relativeTo: priorEndDate)

        let priorDataPoints = await aggregateHealthData(
            for: metric,
            from: priorStartDate,
            to: priorEndDate,
            bucketComponent: period.bucketComponent
        )

        let priorAverage = calculateAverage(priorDataPoints)
        let percentChange = priorAverage > 0
            ? ((average - priorAverage) / priorAverage) * 100
            : nil

        let trend = determineTrend(from: dataPoints, metric: metric)

        return MetricSummary(
            metricType: metric,
            period: period,
            current: dataPoints.last?.value,
            average: average,
            minimum: minimum,
            maximum: maximum,
            total: total,
            dataPoints: dataPoints,
            percentChange: percentChange,
            trend: trend
        )
    }

    func fetchAllSummaries(period: TimePeriod) async -> [MetricSummary] {
        var summaries: [MetricSummary] = []
        summaries.reserveCapacity(HealthMetricType.allCases.count)

        await withTaskGroup(of: MetricSummary?.self) { group in
            for metric in HealthMetricType.allCases {
                group.addTask { [weak self] in
                    await self?.fetchSummary(for: metric, period: period)
                }
            }

            for await summary in group {
                if let summary = summary {
                    summaries.append(summary)
                }
            }
        }

        return summaries
    }

    // MARK: - Private Helpers

    private func aggregateHealthData(
        for metric: HealthMetricType,
        from startDate: Date,
        to endDate: Date,
        bucketComponent: Calendar.Component
    ) async -> [AggregatedDataPoint] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        switch metric {
        case .sleepDuration:
            return await fetchSleepData(from: startDate, to: endDate, bucketComponent: bucketComponent)
        case .workoutCount:
            return await fetchWorkoutData(from: startDate, to: endDate, bucketComponent: bucketComponent)
        default:
            guard let quantityType = sampleType(for: metric) else { return [] }
            return await fetchStatisticsData(
                quantityType: quantityType,
                predicate: predicate,
                bucketComponent: bucketComponent,
                aggregationMethod: metric.aggregationMethod,
                metric: metric
            )
        }
    }

    private func fetchStatisticsData(
        quantityType: HKQuantityType,
        predicate: NSPredicate,
        bucketComponent: Calendar.Component,
        aggregationMethod: HealthMetricType.AggregationMethod,
        metric: HealthMetricType
    ) async -> [AggregatedDataPoint] {
        return await withCheckedContinuation { continuation in
            let interval = dateInterval(for: bucketComponent)

            let options: HKStatisticsOptions = aggregationMethod == .sum
                ? .cumulativeSum
                : .discreteAverage

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: Date(),
                intervalComponents: interval
            )

            query.initialResultsHandler = { query, results, error in
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }

                var dataPoints: [AggregatedDataPoint] = []
                results.enumerateStatistics(from: Date().addingTimeInterval(-30 * 24 * 3600), to: Date()) { stats, _ in
                    guard let sum = stats.sumQuantity() ?? stats.averageQuantity() else {
                        return
                    }

                    var value = sum.doubleValue(for: metric.hkUnit)

                    // Unit conversions
                    if metric == .distance {
                        value /= 1000 // meters to km
                    } else if metric == .oxygenSaturation {
                        value *= 100 // 0-1 to percentage
                    }

                    dataPoints.append(AggregatedDataPoint(date: stats.endDate, value: value))
                }

                continuation.resume(returning: dataPoints)
            }

            healthStore.execute(query)
        }
    }

    private func fetchSleepData(
        from startDate: Date,
        to endDate: Date,
        bucketComponent: Calendar.Component
    ) async -> [AggregatedDataPoint] {
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                continuation.resume(returning: [])
                return
            }

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                var sleepByDate: [DateComponents: TimeInterval] = [:]
                let calendar = Calendar.current

                for sample in samples {
                    // Values: 0=inBed, 1=asleep, 2=awake, 3=core, 4=deep, 5=rem
                    let isAsleep = [1, 3, 4, 5].contains(sample.value)
                    guard isAsleep else { continue }

                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    let dateComponents = calendar.dateComponents([.year, .month, .day], from: sample.startDate)

                    sleepByDate[dateComponents, default: 0] += duration
                }

                var dataPoints: [AggregatedDataPoint] = []
                for (dateComponents, duration) in sleepByDate.sorted(by: {
                    (calendar.date(from: $0.key) ?? .distantPast) < (calendar.date(from: $1.key) ?? .distantPast)
                }) {
                    if let date = calendar.date(from: dateComponents) {
                        let hours = duration / 3600
                        dataPoints.append(AggregatedDataPoint(date: date, value: hours))
                    }
                }

                continuation.resume(returning: dataPoints)
            }

            healthStore.execute(query)
        }
    }

    private func fetchWorkoutData(
        from startDate: Date,
        to endDate: Date,
        bucketComponent: Calendar.Component
    ) async -> [AggregatedDataPoint] {
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            let workoutType = HKObjectType.workoutType()

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                var countByDate: [DateComponents: Int] = [:]
                let calendar = Calendar.current

                for workout in workouts {
                    let dateComponents = calendar.dateComponents([.year, .month, .day], from: workout.startDate)
                    countByDate[dateComponents, default: 0] += 1
                }

                var dataPoints: [AggregatedDataPoint] = []
                for (dateComponents, count) in countByDate.sorted(by: {
                    (calendar.date(from: $0.key) ?? .distantPast) < (calendar.date(from: $1.key) ?? .distantPast)
                }) {
                    if let date = calendar.date(from: dateComponents) {
                        dataPoints.append(AggregatedDataPoint(date: date, value: Double(count)))
                    }
                }

                continuation.resume(returning: dataPoints)
            }

            healthStore.execute(query)
        }
    }

    private func sampleType(for metric: HealthMetricType) -> HKQuantityType? {
        let typeIdentifier: HKQuantityTypeIdentifier

        switch metric {
        case .steps:
            typeIdentifier = .stepCount
        case .distance:
            typeIdentifier = .distanceWalkingRunning
        case .activeEnergy:
            typeIdentifier = .activeEnergyBurned
        case .heartRate:
            typeIdentifier = .heartRate
        case .restingHeartRate:
            typeIdentifier = .restingHeartRate
        case .bodyMass:
            typeIdentifier = .bodyMass
        case .oxygenSaturation:
            typeIdentifier = .oxygenSaturation
        case .respiratoryRate:
            typeIdentifier = .respiratoryRate
        case .sleepDuration, .workoutCount:
            return nil
        }

        return HKObjectType.quantityType(forIdentifier: typeIdentifier)
    }

    private func calculateAverage(_ dataPoints: [AggregatedDataPoint]) -> Double {
        guard !dataPoints.isEmpty else { return 0 }
        let sum = dataPoints.map { $0.value }.reduce(0, +)
        return sum / Double(dataPoints.count)
    }

    private func determineTrend(from dataPoints: [AggregatedDataPoint], metric: HealthMetricType) -> MetricSummary.TrendDirection {
        guard dataPoints.count >= 3 else {
            return .insufficient
        }

        let lastThree = Array(dataPoints.suffix(3))
        let isIncreasing = lastThree[0].value <= lastThree[1].value && lastThree[1].value <= lastThree[2].value
        let isDecreasing = lastThree[0].value >= lastThree[1].value && lastThree[1].value >= lastThree[2].value

        if isIncreasing {
            return metric.higherIsBetter ? .up : .down
        } else if isDecreasing {
            return metric.higherIsBetter ? .down : .up
        }

        return .flat
    }

    private func dateInterval(for component: Calendar.Component) -> DateComponents {
        switch component {
        case .hour:
            return DateComponents(hour: 1)
        case .day:
            return DateComponents(day: 1)
        case .month:
            return DateComponents(day: 1)
        default:
            return DateComponents(month: 1)
        }
    }
}
