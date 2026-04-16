import Foundation
import HealthKit
import Observation

enum AnalyticsComputation {
    static func average(for dataPoints: [AggregatedDataPoint]) -> Double {
        guard !dataPoints.isEmpty else { return 0 }
        let sum = dataPoints.map { $0.value }.reduce(0, +)
        return sum / Double(dataPoints.count)
    }

    static func trend(
        from dataPoints: [AggregatedDataPoint],
        metric: HealthMetricType
    ) -> MetricSummary.TrendDirection {
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

    static func dateInterval(for component: Calendar.Component) -> DateComponents {
        switch component {
        case .hour:
            return DateComponents(hour: 1)
        case .day:
            return DateComponents(day: 1)
        case .month:
            return DateComponents(month: 1)
        default:
            return DateComponents(month: 1)
        }
    }

    static func goalValue(
        from dataPoints: [AggregatedDataPoint],
        metric: HealthMetricType
    ) -> Double {
        guard !dataPoints.isEmpty else {
            return 0
        }

        switch metric.aggregationMethod {
        case .sum:
            if metric == .workoutCount {
                return Double(dataPoints.filter { $0.value > 0 }.count)
            }
            return dataPoints.map(\.value).reduce(0, +)
        case .average:
            return dataPoints.last?.value ?? 0
        }
    }

    static func mergedDuration(
        for intervals: [DateInterval]
    ) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }

        let sortedIntervals = intervals.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.end < rhs.end
            }
            return lhs.start < rhs.start
        }

        var merged: [DateInterval] = []
        merged.reserveCapacity(sortedIntervals.count)

        for interval in sortedIntervals {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }

            if interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            } else {
                merged.append(interval)
            }
        }

        return merged.reduce(0) { partialResult, interval in
            partialResult + interval.duration
        }
    }
}

@Observable final class AnalyticsDataService {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Main API

    func fetchSummary(
        for metric: HealthMetricType,
        period: TimePeriod,
        bucketComponentOverride: Calendar.Component? = nil,
        endingAt endDate: Date = Date()
    ) async -> MetricSummary? {
        let startDate = period.startDate(relativeTo: endDate)
        let bucketComponent = bucketComponentOverride ?? period.bucketComponent

        let dataPoints = await aggregateHealthData(
            for: metric,
            from: startDate,
            to: endDate,
            bucketComponent: bucketComponent
        )

        guard !dataPoints.isEmpty else {
            return nil
        }

        let average = AnalyticsComputation.average(for: dataPoints)
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
            bucketComponent: bucketComponent
        )

        let priorAverage = AnalyticsComputation.average(for: priorDataPoints)
        let percentChange = priorAverage > 0
            ? ((average - priorAverage) / priorAverage) * 100
            : nil

        let trend = AnalyticsComputation.trend(from: dataPoints, metric: metric)

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

    func fetchAllSummaries(
        period: TimePeriod,
        bucketComponentOverride: Calendar.Component? = nil,
        endingAt endDate: Date = Date()
    ) async -> [MetricSummary] {
        var summaries: [MetricSummary] = []
        summaries.reserveCapacity(HealthMetricType.allCases.count)

        await withTaskGroup(of: MetricSummary?.self) { group in
            for metric in HealthMetricType.allCases {
                group.addTask { [weak self] in
                    await self?.fetchSummary(
                        for: metric,
                        period: period,
                        bucketComponentOverride: bucketComponentOverride,
                        endingAt: endDate
                    )
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

    func fetchGoalValue(
        for metric: HealthMetricType,
        period: HealthGoal.GoalPeriod,
        relativeTo referenceDate: Date = Date()
    ) async -> Double {
        if metric.recordStrategy == .latestValue {
            return await fetchLatestValue(for: metric, before: referenceDate)
        }

        let interval = period.interval(containing: referenceDate)
        let bucketComponent: Calendar.Component
        if metric == .workoutCount {
            bucketComponent = .day
        } else {
            bucketComponent = period == .daily ? .hour : .day
        }

        let dataPoints = await aggregateHealthData(
            for: metric,
            from: interval.start,
            to: interval.end,
            bucketComponent: bucketComponent
        )

        return AnalyticsComputation.goalValue(from: dataPoints, metric: metric)
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
                startDate: startDate,
                endDate: endDate,
                bucketComponent: bucketComponent,
                aggregationMethod: metric.aggregationMethod,
                metric: metric
            )
        }
    }

    private func fetchStatisticsData(
        quantityType: HKQuantityType,
        predicate: NSPredicate,
        startDate: Date,
        endDate: Date,
        bucketComponent: Calendar.Component,
        aggregationMethod: HealthMetricType.AggregationMethod,
        metric: HealthMetricType
    ) async -> [AggregatedDataPoint] {
        return await withCheckedContinuation { continuation in
            let interval = AnalyticsComputation.dateInterval(for: bucketComponent)
            let calendar = Calendar.current
            let anchorDate = calendar.dateInterval(of: bucketComponent, for: endDate)?.start
                ?? calendar.startOfDay(for: endDate)

            let options: HKStatisticsOptions = aggregationMethod == .sum
                ? .cumulativeSum
                : .discreteAverage

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }

                var dataPoints: [AggregatedDataPoint] = []
                results.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    guard let sum = stats.sumQuantity() ?? stats.averageQuantity() else {
                        return
                    }

                    var value = sum.doubleValue(for: metric.hkUnit)

                    // Unit conversions
                    if metric == .distance {
                        value /= 1000 // meters to km
                    }

                    dataPoints.append(AggregatedDataPoint(date: stats.startDate, value: value))
                }

                continuation.resume(returning: dataPoints)
            }

            healthStore.execute(query)
        }
    }

    private func fetchLatestValue(
        for metric: HealthMetricType,
        before endDate: Date
    ) async -> Double {
        if metric == .sleepDuration || metric == .workoutCount {
            return 0
        }

        guard let quantityType = sampleType(for: metric) else {
            return 0
        }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: nil,
                end: endDate,
                options: .strictEndDate
            )

            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                guard let sample = (samples as? [HKQuantitySample])?.first else {
                    continuation.resume(returning: 0)
                    return
                }

                var value = sample.quantity.doubleValue(for: metric.hkUnit)
                if metric == .distance {
                    value /= 1000
                }

                continuation.resume(returning: value)
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

                var sleepByDate: [DateComponents: [DateInterval]] = [:]
                let calendar = Calendar.current

                for sample in samples {
                    // Values: 0=inBed, 1=asleep, 2=awake, 3=core, 4=deep, 5=rem
                    let isAsleep = [1, 3, 4, 5].contains(sample.value)
                    guard isAsleep else { continue }

                    let bucketDate = self.sleepBucketDate(for: sample.endDate, component: bucketComponent, calendar: calendar)
                    let dateComponents = calendar.dateComponents(self.bucketComponents(for: bucketComponent), from: bucketDate)
                    let interval = DateInterval(start: sample.startDate, end: sample.endDate)
                    sleepByDate[dateComponents, default: []].append(interval)
                }

                var dataPoints: [AggregatedDataPoint] = []
                for (dateComponents, intervals) in sleepByDate.sorted(by: {
                    (calendar.date(from: $0.key) ?? .distantPast) < (calendar.date(from: $1.key) ?? .distantPast)
                }) {
                    if let date = calendar.date(from: dateComponents) {
                        let hours = AnalyticsComputation.mergedDuration(for: intervals) / 3600
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

                let deduplicatedWorkouts = self.deduplicate(workouts: workouts)
                var countByDate: [DateComponents: Int] = [:]
                let calendar = Calendar.current

                for workout in deduplicatedWorkouts {
                    let bucketDate = self.bucketStartDate(for: workout.startDate, component: bucketComponent, calendar: calendar)
                    let dateComponents = calendar.dateComponents(self.bucketComponents(for: bucketComponent), from: bucketDate)
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

    private func bucketStartDate(
        for date: Date,
        component: Calendar.Component,
        calendar: Calendar
    ) -> Date {
        switch component {
        case .hour:
            return calendar.dateInterval(of: .hour, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .day:
            fallthrough
        default:
            return calendar.startOfDay(for: date)
        }
    }

    private func bucketComponents(for component: Calendar.Component) -> Set<Calendar.Component> {
        switch component {
        case .hour:
            return [.year, .month, .day, .hour]
        case .month:
            return [.year, .month]
        case .day:
            fallthrough
        default:
            return [.year, .month, .day]
        }
    }

    private func deduplicate(workouts: [HKWorkout]) -> [HKWorkout] {
        let sorted = workouts.sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.endDate < rhs.endDate
            }
            return lhs.startDate < rhs.startDate
        }

        var result: [HKWorkout] = []
        result.reserveCapacity(sorted.count)

        for workout in sorted {
            if let last = result.last, workoutsRepresentSameSession(last, workout) {
                continue
            }

            result.append(workout)
        }

        return result
    }

    private func workoutsRepresentSameSession(_ lhs: HKWorkout, _ rhs: HKWorkout) -> Bool {
        guard lhs.workoutActivityType == rhs.workoutActivityType else {
            return false
        }

        let startDelta = abs(lhs.startDate.timeIntervalSince(rhs.startDate))
        let endDelta = abs(lhs.endDate.timeIntervalSince(rhs.endDate))
        let overlapStart = max(lhs.startDate, rhs.startDate)
        let overlapEnd = min(lhs.endDate, rhs.endDate)
        let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))
        let shortestDuration = min(lhs.duration, rhs.duration)

        let heavilyOverlapping = shortestDuration > 0 && overlap / shortestDuration > 0.8
        let nearIdenticalWindow = startDelta < 600 && endDelta < 600

        return heavilyOverlapping || nearIdenticalWindow
    }

    private func sleepBucketDate(
        for date: Date,
        component: Calendar.Component,
        calendar: Calendar
    ) -> Date {
        switch component {
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .hour:
            return calendar.dateInterval(of: .hour, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .day:
            fallthrough
        default:
            return calendar.startOfDay(for: date)
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
}
